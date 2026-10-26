import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../database/app_database.dart';
import '../sources/music_source.dart';

class MusicAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final MusicSource _musicSource;
  final AppDatabase _database;

  // Queue state tracking
  int _currentIndex = -1;
  final List<TrackInfo> _trackQueue = [];

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

    mediaItem.add(track.toMediaItem());

    try {
      // 1. Check if track is available offline locally
      if (track.localFilePath != null && track.localFilePath!.isNotEmpty) {
        final localFile = File(track.localFilePath!);
        if (await localFile.exists()) {
          await _player.setAudioSource(AudioSource.file(localFile.path));
          await _player.play();
          return;
        }
      }

      // Check DB for completed download if not in track model
      final downloadEntry = await _database.getDownload(track.id);
      if (downloadEntry != null &&
          downloadEntry.status == 'completed' &&
          downloadEntry.localFilePath.isNotEmpty) {
        final file = File(downloadEntry.localFilePath);
        if (await file.exists()) {
          await _player.setAudioSource(AudioSource.file(file.path));
          await _player.play();
          return;
        }
      }

      // 2. Stream online via MusicSource (resolves fresh stream URL)
      final streamInfo = await _musicSource.getStreamUrl(track.id);
      await _player.setAudioSource(
        AudioSource.uri(
          streamInfo.url,
          tag: track.toMediaItem(),
        ),
      );
      await _player.play();
    } catch (e) {
      if (!isRetry) {
        // Stream URLs can expire or get throttled; retry once with a refreshed URL
        await Future.delayed(const Duration(milliseconds: 500));
        return _prepareAndPlayTrack(track, isRetry: true);
      }
      rethrow;
    }
  }

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
      // Loop or stop
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
