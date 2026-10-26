import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/database/app_database.dart';
import '../../core/sources/music_source.dart';
import '../../core/utils/app_logger.dart';

enum DownloadStatus { pending, downloading, completed, failed }

class DownloadProgressItem {
  final String videoId;
  final double progress;
  final DownloadStatus status;
  final String? errorMessage;

  const DownloadProgressItem({
    required this.videoId,
    required this.progress,
    required this.status,
    this.errorMessage,
  });
}

class DownloadManager {
  final Dio _dio;
  final AppDatabase _database;
  final MusicSource _musicSource;

  // Active in-memory download tasks and progress controller
  final Map<String, CancelToken> _cancelTokens = {};
  final StreamController<Map<String, double>> _progressController =
      StreamController<Map<String, double>>.broadcast();
  final Map<String, double> _activeProgress = {};

  bool _isProcessingQueue = false;
  final List<TrackInfo> _downloadQueue = [];

  DownloadManager({
    required AppDatabase database,
    required MusicSource musicSource,
    Dio? dio,
  })  : _database = database,
        _musicSource = musicSource,
        _dio = dio ?? Dio();

  Stream<Map<String, double>> get progressStream => _progressController.stream;

  /// Call on app startup to resume incomplete downloads
  Future<void> initialize() async {
    try {
      final incomplete = await _database.getIncompleteDownloads();
      for (final item in incomplete) {
        final track = TrackInfo(
          id: item.videoId,
          title: item.title,
          artist: item.artist,
          duration: Duration(seconds: item.durationSeconds),
          thumbnailUrl: item.thumbnailUrl,
        );
        enqueueDownload(track);
      }
    } catch (_) {}
  }

  Future<void> enqueueDownload(TrackInfo track) async {
    // Check if already downloaded
    final existing = await _database.getDownload(track.id);
    if (existing != null && existing.status == 'completed') {
      final file = File(existing.localFilePath);
      if (await file.exists()) {
        return; // Already exists
      }
    }

    // Save pending entry to DB
    await _database.saveDownloadEntry(
      track: track,
      localFilePath: '',
      status: 'pending',
      progress: 0.0,
    );

    _downloadQueue.add(track);
    _processQueue();
  }

  Future<void> _processQueue() async {
    if (_isProcessingQueue || _downloadQueue.isEmpty) return;
    _isProcessingQueue = true;

    while (_downloadQueue.isNotEmpty) {
      final track = _downloadQueue.removeAt(0);
      await _downloadTrack(track);
    }

    _isProcessingQueue = false;
  }

  Future<void> _downloadTrack(TrackInfo track) async {
    final cancelToken = CancelToken();
    _cancelTokens[track.id] = cancelToken;
    AppLogger.info('DownloadManager', 'Starting download for: "${track.title}" (${track.id})');

    try {
      // 1. Mark as downloading
      await _database.updateDownloadStatus(
        videoId: track.id,
        status: 'downloading',
        progress: 0.0,
      );
      _activeProgress[track.id] = 0.0;
      _progressController.add(Map.unmodifiable(_activeProgress));

      // 2. Fetch fresh stream data (audio stream + metadata in 1 call)
      final streamData = await _musicSource.getAudioStreamData(track.id);

      // 3. Prepare target file path in app documents directory
      final docsDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory(p.join(docsDir.path, AppConstants.downloadsDirectoryName));
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      final extension = streamData.container.isNotEmpty ? streamData.container : 'm4a';
      final sanitizedTitle = track.id.replaceAll(RegExp(r'[^\w\.-]'), '_');
      final targetFilePath = p.join(downloadsDir.path, '$sanitizedTitle.$extension');
      final tempFilePath = '$targetFilePath.part';

      DateTime lastDbUpdate = DateTime.now();

      // 4. Download stream bytes directly via MusicSource to bypass 403 Forbidden
      try {
        final byteStream = streamData.stream;
        final tempFile = File(tempFilePath);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
        final sink = tempFile.openWrite();

        final totalBytes = streamData.sizeBytes;
        int downloadedBytes = 0;

        await for (final chunk in byteStream) {
          if (cancelToken.isCancelled) {
            await sink.close();
            if (await tempFile.exists()) {
              await tempFile.delete();
            }
            return;
          }

          sink.add(chunk);
          downloadedBytes += chunk.length;

          if (totalBytes > 0) {
            final progress = (downloadedBytes / totalBytes).clamp(0.0, 1.0);
            _activeProgress[track.id] = progress;
            _progressController.add(Map.unmodifiable(_activeProgress));

            final now = DateTime.now();
            if (now.difference(lastDbUpdate).inMilliseconds > 600) {
              lastDbUpdate = now;
              _database.updateDownloadStatus(
                videoId: track.id,
                status: 'downloading',
                progress: progress,
              );
            }
          }
        }

        await sink.flush();
        await sink.close();
      } catch (streamErr) {
        AppLogger.warn('DownloadManager', 'Byte stream failed, falling back to Dio with headers: $streamErr');
        // Fallback to Dio with YouTube headers
        final fallbackStreamUrl = streamData.url?.toString() ??
            (await _musicSource.getStreamUrl(track.id)).url.toString();
        await _dio.download(
          fallbackStreamUrl,
          tempFilePath,
          cancelToken: cancelToken,
          options: Options(
            headers: const {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
              'Referer': 'https://www.youtube.com/',
              'Origin': 'https://www.youtube.com',
            },
          ),
          onReceiveProgress: (received, total) {
            if (total > 0) {
              final progress = (received / total).clamp(0.0, 1.0);
              _activeProgress[track.id] = progress;
              _progressController.add(Map.unmodifiable(_activeProgress));

              final now = DateTime.now();
              if (now.difference(lastDbUpdate).inMilliseconds > 600) {
                lastDbUpdate = now;
                _database.updateDownloadStatus(
                  videoId: track.id,
                  status: 'downloading',
                  progress: progress,
                );
              }
            }
          },
        );
      }

      // 5. Rename temporary file to target file
      final tempFile = File(tempFilePath);
      if (await tempFile.exists()) {
        final targetFile = await tempFile.rename(targetFilePath);
        final fileSize = await targetFile.length();

        // 6. Mark completed in DB
        await _database.updateDownloadStatus(
          videoId: track.id,
          status: 'completed',
          progress: 1.0,
          localFilePath: targetFile.path,
          fileSizeBytes: fileSize,
        );

        _activeProgress[track.id] = 1.0;
        _progressController.add(Map.unmodifiable(_activeProgress));
        AppLogger.info('DownloadManager', 'Download complete: "${track.title}" (${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB)');
      } else {
        throw Exception('Downloaded file not found at $tempFilePath');
      }
    } catch (e, st) {
      if (!cancelToken.isCancelled) {
        AppLogger.error('DownloadManager', 'Download failed for "${track.title}" (${track.id})', e, st);
        await _database.updateDownloadStatus(
          videoId: track.id,
          status: 'failed',
          progress: 0.0,
        );
        _activeProgress.remove(track.id);
        _progressController.add(Map.unmodifiable(_activeProgress));
      }
    } finally {
      _cancelTokens.remove(track.id);
      _activeProgress.remove(track.id);
    }
  }

  Future<void> cancelDownload(String videoId) async {
    _cancelTokens[videoId]?.cancel();
    _cancelTokens.remove(videoId);
    _downloadQueue.removeWhere((t) => t.id == videoId);
    _activeProgress.remove(videoId);
    _progressController.add(Map.unmodifiable(_activeProgress));
    await _database.deleteDownloadEntry(videoId);
  }

  Future<void> deleteDownload(String videoId) async {
    final entry = await _database.getDownload(videoId);
    if (entry != null && entry.localFilePath.isNotEmpty) {
      final file = File(entry.localFilePath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
    await _database.deleteDownloadEntry(videoId);
  }

  void dispose() {
    for (final token in _cancelTokens.values) {
      token.cancel();
    }
    _cancelTokens.clear();
    _progressController.close();
  }
}
