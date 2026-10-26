import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/audio/audio_service_provider.dart';
import '../../core/database/app_database.dart';
import 'download_manager.dart';

final downloadManagerProvider = Provider<DownloadManager>((ref) {
  final db = ref.watch(databaseProvider);
  final source = ref.watch(musicSourceProvider);
  final manager = DownloadManager(database: db, musicSource: source);
  manager.initialize();
  ref.onDispose(() => manager.dispose());
  return manager;
});

final downloadProgressMapStreamProvider = StreamProvider<Map<String, double>>((ref) {
  final manager = ref.watch(downloadManagerProvider);
  return manager.progressStream;
});

class TrackDownloadState {
  final bool isDownloaded;
  final bool isDownloading;
  final bool isPending;
  final bool isFailed;
  final double progress;
  final String? localFilePath;

  const TrackDownloadState({
    required this.isDownloaded,
    required this.isDownloading,
    required this.isPending,
    required this.isFailed,
    required this.progress,
    this.localFilePath,
  });

  factory TrackDownloadState.idle() => const TrackDownloadState(
        isDownloaded: false,
        isDownloading: false,
        isPending: false,
        isFailed: false,
        progress: 0.0,
      );
}

final trackDownloadStatusProvider =
    StreamProvider.family<TrackDownloadState, String>((ref, videoId) {
  final db = ref.watch(databaseProvider);
  final inMemoryProgress = ref.watch(downloadProgressMapStreamProvider).value ?? {};

  return db.watchDownload(videoId).map((entry) {
    if (entry == null) {
      return TrackDownloadState.idle();
    }

    final memProgress = inMemoryProgress[videoId];
    final progress = memProgress ?? entry.downloadProgress;

    return TrackDownloadState(
      isDownloaded: entry.status == 'completed',
      isDownloading: entry.status == 'downloading',
      isPending: entry.status == 'pending',
      isFailed: entry.status == 'failed',
      progress: progress,
      localFilePath: entry.localFilePath.isNotEmpty ? entry.localFilePath : null,
    );
  });
});
