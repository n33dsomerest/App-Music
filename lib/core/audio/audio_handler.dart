import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../database/app_database.dart';
import '../sources/music_source.dart';
import '../utils/app_logger.dart';

class MusicAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  // No custom userAgent, no useProxyForRequestHeaders needed —
  // we never send raw googlevideo.com URLs to ExoPlayer.
  // All online audio is first downloaded to a local file by youtube_explode_dart,
  // then played via AudioSource.file() which is 100% local.
  final AudioPlayer _player = AudioPlayer();
  final MusicSource _musicSource;
  final AppDatabase _database;

  // Queue state tracking
  int _currentIndex = -1;
  final List<TrackInfo> _trackQueue = [];
  String? _loadingTrackId;

  // Play logging tracking
  Duration _maxPositionReached = Duration.zero;

  MusicAudioHandler({
    required MusicSource musicSource,
    required AppDatabase database,
  })  : _musicSource = musicSource,
        _database = database {
    _initAudioPlayer();
  }

  void _initAudioPlayer() {
    // Broadcast player state changes (playing, buffering, completed, etc.)
    _player.playbackEventStream.listen(_broadcastState);

    // Track position to calculate completion ratio
    _player.positionStream.listen((pos) {
      if (pos > _maxPositionReached) {
        _maxPositionReached = pos;
      }
    });

    // Handle track completion -> auto play next
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _logCurrentTrackPlay(isCompleted: true);
        skipToNext();
      }
    });
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    final queueIndex = _currentIndex;

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.setShuffleMode,
          MediaAction.setRepeatMode,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: queueIndex >= 0 && queueIndex < _trackQueue.length ? queueIndex : null,
      ),
    );
  }

  Future<void> playTrack(TrackInfo track, {List<TrackInfo>? queue}) async {
    _logCurrentTrackPlay();

    if (queue != null && queue.isNotEmpty) {
      _trackQueue.clear();
      _trackQueue.addAll(queue);
      _currentIndex = _trackQueue.indexWhere((t) => t.id == track.id);
      if (_currentIndex == -1) {
        _trackQueue.insert(0, track);
        _currentIndex = 0;
      }
    } else {
      _trackQueue.clear();
      _trackQueue.add(track);
      _currentIndex = 0;
    }

    this.queue.add(_trackQueue.map((t) => t.toMediaItem()).toList());
    await _prepareAndPlayTrack(track);
  }

  Future<void> _prepareAndPlayTrack(TrackInfo track, {bool isRetry = false}) async {
    _maxPositionReached = Duration.zero;
    _loadingTrackId = track.id;
    AppLogger.info('AudioHandler', 'Preparing track: "${track.title}" (${track.id}) ${isRetry ? "[RETRY]" : ""}');

    mediaItem.add(track.toMediaItem());

    // Emit a loading/buffering state so the UI shows a spinner
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.loading,
    ));

    try {
      // ── Step 1: Try playing from an existing local file ──

      // 1a. Track model has a local path (e.g. from a download tile)
      if (track.localFilePath != null && track.localFilePath!.isNotEmpty) {
        final localFile = File(track.localFilePath!);
        if (await localFile.exists()) {
          AppLogger.info('AudioHandler', 'Playing from local file: ${localFile.path}');
          await _setSourceAndPlay(localFile.path, track);
          return;
        }
      }

      // 1b. A completed download exists in the DB
      final downloadEntry = await _database.getDownload(track.id);
      if (downloadEntry != null &&
          downloadEntry.status == 'completed' &&
          downloadEntry.localFilePath.isNotEmpty) {
        final file = File(downloadEntry.localFilePath);
        if (await file.exists()) {
          AppLogger.info('AudioHandler', 'Playing from offline DB download: ${file.path}');
          await _setSourceAndPlay(file.path, track);
          return;
        }
      }

      // 1c. A previous stream-cache file exists on disk
      final existingCache = await _findCacheFile(track.id);
      if (existingCache != null && await existingCache.length() > 4096) {
        AppLogger.info('AudioHandler', 'Playing from cached stream file: ${existingCache.path}');
        await _setSourceAndPlay(existingCache.path, track);
        return;
      }

      // ── Step 2: Download the audio stream to a temp file, then play ──
      //
      // youtube_explode_dart's streamsClient.get() performs the HTTP request
      // using its own YoutubeHttpClient with the correct User-Agent, cookies,
      // cipher/signature tokens etc.  The bytes arrive as a plain Dart
      // Stream<List<int>>.  We write them to disk and hand the *local* file
      // path to just_audio — ExoPlayer never touches googlevideo.com.

      AppLogger.info('AudioHandler', 'Downloading audio via youtube_explode for ${track.id}…');
      final streamData = await _musicSource.getAudioStreamData(track.id);
      final ext = (streamData.container.isNotEmpty) ? streamData.container : 'm4a';
      final cacheFile = await _makeCacheFile(track.id, ext);
      final tempFile  = File('${cacheFile.path}.part');

      // Delete stale partial download if it exists
      if (await tempFile.exists()) await tempFile.delete();

      final sink = tempFile.openWrite();
      int bytesWritten = 0;
      final totalBytes = streamData.sizeBytes;
      final sw = Stopwatch()..start();

      await for (final chunk in streamData.stream) {
        sink.add(chunk);
        bytesWritten += chunk.length;

        // Log progress every ~2 s so the user can see something in Settings
        if (sw.elapsedMilliseconds > 2000) {
          final pct = totalBytes > 0
              ? ((bytesWritten / totalBytes) * 100).toStringAsFixed(0)
              : '?';
          AppLogger.info('AudioHandler',
              'Buffering ${track.id}: $bytesWritten / $totalBytes bytes ($pct %)');
          sw.reset();
        }
      }

      await sink.flush();
      await sink.close();

      // Atomic rename: .part → final name
      if (await cacheFile.exists()) await cacheFile.delete();
      await tempFile.rename(cacheFile.path);

      AppLogger.info('AudioHandler',
          'Download complete: $bytesWritten bytes → ${cacheFile.path}');

      if (_loadingTrackId != track.id) {
        AppLogger.info('AudioHandler', 'Track changed during download of ${track.id}, skipping auto-play');
        return;
      }

      await _setSourceAndPlay(cacheFile.path, track);
      return;
    } catch (e, st) {
      if (!isRetry) {
        AppLogger.warn('AudioHandler',
            'Playback/download failed, retrying once… Error: $e');
        await Future.delayed(const Duration(milliseconds: 800));
        return _prepareAndPlayTrack(track, isRetry: true);
      }
      AppLogger.error('AudioHandler',
          'Failed to play track "${track.title}" (${track.id})', e, st);
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
      ));
    }
  }

  /// Helper: sets the audio source from a local file path and starts playback.
  Future<void> _setSourceAndPlay(String filePath, TrackInfo track) async {
    await _player.setAudioSource(
      AudioSource.file(filePath, tag: track.toMediaItem()),
    );
    await _player.play();
    AppLogger.info('AudioHandler',
        'Playback started for "${track.title}" from $filePath');
  }

  // ─── Cache helpers ───────────────────────────────────────────────────

  Future<File> _makeCacheFile(String trackId, [String extension = 'm4a']) async {
    final dir = await _cacheDir();
    final sanitized = trackId.replaceAll(RegExp(r'[^\w\.-]'), '_');
    final ext = extension.isNotEmpty ? extension : 'm4a';
    return File(p.join(dir.path, '$sanitized.$ext'));
  }

  /// Looks for any cached file for [trackId], regardless of extension.
  Future<File?> _findCacheFile(String trackId) async {
    final dir = await _cacheDir();
    final sanitized = trackId.replaceAll(RegExp(r'[^\w\.-]'), '_');
    if (!await dir.exists()) return null;
    try {
      final entries = dir.listSync();
      for (final entry in entries) {
        if (entry is File &&
            !entry.path.endsWith('.part') &&
            p.basenameWithoutExtension(entry.path) == sanitized &&
            entry.lengthSync() > 10000) {
          return entry;
        }
      }
    } catch (_) {}
    return null;
  }

  Directory? _cacheDirCached;
  Future<Directory> _cacheDir() async {
    if (_cacheDirCached != null) return _cacheDirCached!;
    final tmp = await getTemporaryDirectory();
    final dir = Directory(p.join(tmp.path, 'music_apl_cache'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cacheDirCached = dir;
    return dir;
  }

  // ─── Play-history logging ────────────────────────────────────────────

  void _logCurrentTrackPlay({bool isCompleted = false}) {
    if (_currentIndex < 0 || _currentIndex >= _trackQueue.length) return;
    final track = _trackQueue[_currentIndex];

    final duration = track.duration;
    double completionRatio = 0.0;
    if (isCompleted) {
      completionRatio = 1.0;
    } else if (duration.inSeconds > 0) {
      completionRatio = (_maxPositionReached.inSeconds / duration.inSeconds).clamp(0.0, 1.0);
    }

    // Only log if listened for at least 5 seconds
    if (_maxPositionReached.inSeconds >= 5) {
      _database.logPlay(
        videoId: track.id,
        title: track.title,
        artist: track.artist,
        tags: track.tags,
        completionRatio: completionRatio,
        duration: duration,
      );
    }
  }

  // ─── Standard BaseAudioHandler overrides ─────────────────────────────

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    _logCurrentTrackPlay();
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_trackQueue.isEmpty) return;
    if (_currentIndex + 1 < _trackQueue.length) {
      _currentIndex++;
      await _prepareAndPlayTrack(_trackQueue[_currentIndex]);
    } else {
      // End of queue
      await _player.seek(Duration.zero);
      await _player.pause();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_trackQueue.isEmpty) return;
    // If more than 3 seconds in, seek to beginning of current song
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }

    if (_currentIndex - 1 >= 0) {
      _currentIndex--;
      await _prepareAndPlayTrack(_trackQueue[_currentIndex]);
    } else {
      await _player.seek(Duration.zero);
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        await _player.setLoopMode(LoopMode.off);
        break;
      case AudioServiceRepeatMode.one:
        await _player.setLoopMode(LoopMode.one);
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        await _player.setLoopMode(LoopMode.all);
        break;
    }
    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode == AudioServiceShuffleMode.all ||
        shuffleMode == AudioServiceShuffleMode.group;
    await _player.setShuffleModeEnabled(enabled);
    playbackState.add(playbackState.value.copyWith(shuffleMode: shuffleMode));
  }

  // ─── Public getters ──────────────────────────────────────────────────

  AudioPlayer get player => _player;
  List<TrackInfo> get currentQueue => List.unmodifiable(_trackQueue);
  TrackInfo? get currentTrack =>
      _currentIndex >= 0 && _currentIndex < _trackQueue.length
          ? _trackQueue[_currentIndex]
          : null;

  Future<void> disposeHandler() async {
    _logCurrentTrackPlay();
    await _player.dispose();
  }
}
