import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../sources/music_source.dart';
import '../sources/youtube_music_source.dart';
import 'audio_handler.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final musicSourceProvider = Provider<MusicSource>((ref) {
  final source = YoutubeMusicSource();
  ref.onDispose(() => source.dispose());
  return source;
});

final audioHandlerProvider = Provider<MusicAudioHandler>((ref) {
  throw UnimplementedError('audioHandlerProvider must be overridden in ProviderScope');
});

final playbackStateStreamProvider = StreamProvider<PlaybackState>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.playbackState;
});

final currentMediaItemStreamProvider = StreamProvider<MediaItem?>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.mediaItem;
});

final playerPositionStreamProvider = StreamProvider<Duration>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.player.positionStream;
});

final playerBufferedPositionStreamProvider = StreamProvider<Duration>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.player.bufferedPositionStream;
});

final playerDurationStreamProvider = StreamProvider<Duration?>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.player.durationStream;
});

class CurrentPositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;

  const CurrentPositionData({
    required this.position,
    required this.bufferedPosition,
    required this.duration,
  });
}

final positionDataProvider = Provider<CurrentPositionData>((ref) {
  final pos = ref.watch(playerPositionStreamProvider).value ?? Duration.zero;
  final buf = ref.watch(playerBufferedPositionStreamProvider).value ?? Duration.zero;
  final dur = ref.watch(playerDurationStreamProvider).value ?? Duration.zero;

  return CurrentPositionData(
    position: pos,
    bufferedPosition: buf,
    duration: dur,
  );
});
