import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/audio/audio_service_provider.dart';
import '../../core/database/app_database.dart';
import '../../core/sources/music_source.dart';

class HomeSection {
  final String title;
  final String? subtitle;
  final List<TrackInfo> tracks;

  const HomeSection({
    required this.title,
    this.subtitle,
    required this.tracks,
  });
}

class HomeData {
  final bool isColdStart;
  final List<TrackInfo> recentlyPlayed;
  final List<HomeSection> sections;

  const HomeData({
    required this.isColdStart,
    required this.recentlyPlayed,
    required this.sections,
  });
}

final recentlyPlayedStreamProvider = StreamProvider<List<TrackInfo>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchRecentlyPlayed(limit: 25).map((historyList) {
    final seen = <String>{};
    final tracks = <TrackInfo>[];

    for (final h in historyList) {
      if (!seen.contains(h.videoId)) {
        seen.add(h.videoId);
        tracks.add(
          TrackInfo(
            id: h.videoId,
            title: h.title,
            artist: h.artist,
            duration: Duration(seconds: h.durationSeconds),
            thumbnailUrl: 'https://i.ytimg.com/vi/${h.videoId}/hqdefault.jpg',
            tags: h.genreOrTags.split(',').where((t) => t.isNotEmpty).toList(),
          ),
        );
      }
    }
    return tracks;
  });
});

final homeDataProvider = FutureProvider<HomeData>((ref) async {
  final db = ref.watch(databaseProvider);
  final source = ref.watch(musicSourceProvider);

  final recentTracks = await ref.watch(recentlyPlayedStreamProvider.future);

  // 1. Cold Start: No history yet
  if (recentTracks.isEmpty) {
    final trending = await source.getTrending();
    final half = (trending.length / 2).ceil();

    return HomeData(
      isColdStart: true,
      recentlyPlayed: const [],
      sections: [
        HomeSection(
          title: 'Trending Now',
          subtitle: 'Top charts and viral songs',
          tracks: trending.take(half).toList(),
        ),
        HomeSection(
          title: 'Popular Hits',
          subtitle: 'Fresh recommendations to get started',
          tracks: trending.skip(half).toList(),
        ),
      ],
    );
  }

  // 2. Personalized Suggestions based on play history & completion ratios
  final topArtists = await db.getTopArtists(limit: 2);
  final topGenres = await db.getTopGenres(limit: 2);

  final justPlayedIds = recentTracks.take(10).map((t) => t.id).toSet();
  final recommendedIds = <String>{...justPlayedIds};
  final sections = <HomeSection>[];

  // A. "Because you listened to <Artist>"
  if (topArtists.isNotEmpty) {
    final topArtist = topArtists.first.artist;
    try {
      final artistTracks = await source.search('$topArtist music hits');
      final filtered = artistTracks.where((t) => !recommendedIds.contains(t.id)).take(12).toList();
      if (filtered.isNotEmpty) {
        recommendedIds.addAll(filtered.map((t) => t.id));
        sections.add(
          HomeSection(
            title: 'Because you listened to $topArtist',
            subtitle: 'Recommended artist tracks',
            tracks: filtered,
          ),
        );
      }
    } catch (_) {}
  }

  // B. "More like <Genre>"
  if (topGenres.isNotEmpty) {
    final topGenre = topGenres.first.genre;
    try {
      final genreTracks = await source.search('$topGenre songs');
      final filtered = genreTracks.where((t) => !recommendedIds.contains(t.id)).take(12).toList();
      if (filtered.isNotEmpty) {
        recommendedIds.addAll(filtered.map((t) => t.id));
        sections.add(
          HomeSection(
            title: 'More like ${topGenre.toUpperCase()}',
            subtitle: 'Curated genre playlist',
            tracks: filtered,
          ),
        );
      }
    } catch (_) {}
  }

  // C. Second artist recommendation if available
  if (topArtists.length > 1) {
    final secondArtist = topArtists[1].artist;
    try {
      final tracks = await source.search('$secondArtist best songs');
      final filtered = tracks.where((t) => !recommendedIds.contains(t.id)).take(12).toList();
      if (filtered.isNotEmpty) {
        recommendedIds.addAll(filtered.map((t) => t.id));
        sections.add(
          HomeSection(
            title: 'Spotlight: $secondArtist',
            subtitle: 'Popular tracks from this artist',
            tracks: filtered,
          ),
        );
      }
    } catch (_) {}
  }

  // D. Fallback discovery section: Trending Today
  try {
    final trending = await source.getTrending();
    final freshTrending = trending.where((t) => !recommendedIds.contains(t.id)).take(10).toList();
    if (freshTrending.isNotEmpty) {
      sections.add(
        HomeSection(
          title: 'Trending Today',
          subtitle: 'What everyone is listening to',
          tracks: freshTrending,
        ),
      );
    }
  } catch (_) {}

  return HomeData(
    isColdStart: false,
    recentlyPlayed: recentTracks,
    sections: sections,
  );
});
