import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/audio/audio_service_provider.dart';
import '../../core/sources/music_source.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<List<TrackInfo>>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.isEmpty) {
    return const [];
  }

  final source = ref.watch(musicSourceProvider);
  return source.search(query);
});

final searchSuggestionsProvider = Provider<List<String>>((ref) => const [
  'Chill Lo-Fi Beats',
  'Top Global Hits',
  'Electronic Dance',
  'Acoustic Pop',
  'Hip Hop Workout',
  'Deep House Relax',
  'Rock Classics',
  'Indie Folk',
]);
