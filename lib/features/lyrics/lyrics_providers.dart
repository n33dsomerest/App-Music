import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/audio/audio_service_provider.dart';
import '../../core/sources/music_source.dart';
import 'lrclib_service.dart';

final lrclibServiceProvider = Provider<LrclibService>((ref) {
  final db = ref.watch(databaseProvider);
  return LrclibService(database: db);
});

class LyricsStateNotifier extends StateNotifier<AsyncValue<LyricsData?>> {
  final LrclibService _service;
  TrackInfo? _currentTrack;

  LyricsStateNotifier(this._service) : super(const AsyncValue.data(null));

  Future<void> loadLyricsForTrack(TrackInfo? track, {bool forceRefresh = false}) async {
    if (track == null) {
      state = const AsyncValue.data(null);
      _currentTrack = null;
      return;
    }

    if (!forceRefresh && _currentTrack?.id == track.id && state.hasValue) {
      return; // Already loaded
    }

    _currentTrack = track;
    state = const AsyncValue.loading();

    try {
      final lyrics = await _service.getLyrics(
        videoId: track.id,
        title: track.title,
        artist: track.artist,
        duration: track.duration,
      );
      state = AsyncValue.data(lyrics);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> adjustOffset(int deltaMs) async {
    final current = state.value;
    if (current == null) return;

    final newOffset = current.offsetMs + deltaMs;
    final updated = current.copyWith(offsetMs: newOffset);
    state = AsyncValue.data(updated);

    await _service.updateOffset(current.videoId, newOffset);
  }
}

final lyricsNotifierProvider =
    StateNotifierProvider<LyricsStateNotifier, AsyncValue<LyricsData?>>((ref) {
  final service = ref.watch(lrclibServiceProvider);
  final notifier = LyricsStateNotifier(service);

  // Auto-listen to current media item and load lyrics when track changes
  ref.listen(currentMediaItemStreamProvider, (prev, next) {
    final mediaItem = next.value;
    if (mediaItem != null) {
      final track = TrackInfo.fromMediaItem(mediaItem);
      notifier.loadLyricsForTrack(track);
    } else {
      notifier.loadLyricsForTrack(null);
    }
  });

  return notifier;
});
