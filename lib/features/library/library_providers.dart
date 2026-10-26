import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/audio/audio_service_provider.dart';
import '../../core/database/app_database.dart';
import '../../core/sources/music_source.dart';

final downloadedTracksStreamProvider = StreamProvider<List<TrackInfo>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchCompletedDownloads().map((list) {
    return list.map((d) {
      return TrackInfo(
        id: d.videoId,
        title: d.title,
        artist: d.artist,
        duration: Duration(seconds: d.durationSeconds),
        thumbnailUrl: d.thumbnailUrl,
        localFilePath: d.localFilePath,
        isDownloaded: true,
      );
    }).toList();
  });
});

final activeDownloadsStreamProvider = StreamProvider<List<Download>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllDownloads().map((list) {
    return list.where((d) => d.status == 'downloading' || d.status == 'pending').toList();
  });
});
