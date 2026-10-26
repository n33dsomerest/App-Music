import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../utils/app_logger.dart';
import 'music_source.dart';

class MusicSourceException implements Exception {
  final String message;
  final dynamic cause;

  MusicSourceException(this.message, [this.cause]);

  @override
  String toString() => 'MusicSourceException: $message';
}

class YoutubeMusicSource implements MusicSource {
  final YoutubeExplode _yt;

  YoutubeMusicSource({YoutubeExplode? yt}) : _yt = yt ?? YoutubeExplode();

  @override
  Future<List<TrackInfo>> search(String query) async {
    AppLogger.info('MusicSource', 'Searching YouTube for: "$query"');
    try {
      final searchResults = await _yt.search.getVideos(query);
      final list = searchResults.map((video) => _mapVideoToTrack(video)).toList();
      AppLogger.info('MusicSource', 'Found ${list.length} results for "$query"');
      return list;
    } catch (e, st) {
      AppLogger.error('MusicSource', 'YouTube search failed for "$query"', e, st);
      throw MusicSourceException('Failed to search tracks for "$query": $e', e);
    }
  }

  @override
  Future<List<TrackInfo>> getTrending() async {
    try {
      // Query popular & trending music queries
      final queries = [
        'Top Music Hits 2024',
        'Trending Global Songs',
        'Billboard Hot 100 Music',
      ];
      final query = queries[DateTime.now().minute % queries.length];
      final videos = await _yt.search.getVideos(query);
      return videos.take(25).map((v) => _mapVideoToTrack(v)).toList();
    } catch (e) {
      throw MusicSourceException('Failed to load trending tracks: $e', e);
    }
  }

  @override
  Future<List<TrackInfo>> getRelatedTracks(String videoId, {int limit = 10}) async {
    try {
      final video = await _yt.videos.get(videoId);
      final searchQueries = [
        '${video.author} songs',
        '${video.title} similar music',
      ];

      final results = <TrackInfo>[];
      final seenIds = <String>{videoId};

      for (final q in searchQueries) {
        if (results.length >= limit) break;
        final vids = await _yt.search.getVideos(q);
        for (final v in vids) {
          if (!seenIds.contains(v.id.value)) {
            seenIds.add(v.id.value);
            results.add(_mapVideoToTrack(v));
            if (results.length >= limit) break;
          }
        }
      }

      return results;
    } catch (e) {
      // Return empty list on failure rather than crashing recommendations
      return [];
    }
  }

  @override
  Future<AudioStreamInfoResult> getStreamUrl(String videoId) async {
    AppLogger.info('MusicSource', 'Fetching stream manifest for: $videoId');
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      final audioStreams = manifest.audioOnly;
      if (audioStreams.isEmpty) {
        throw MusicSourceException('No audio streams available for track $videoId');
      }

      final bestAudio = audioStreams.withHighestBitrate();
      AppLogger.info('MusicSource', 'Resolved best audio stream: ${bestAudio.container.name}, ${bestAudio.bitrate.bitsPerSecond} bps, ${bestAudio.size.totalMegaBytes.toStringAsFixed(2)} MB');
      return AudioStreamInfoResult(
        url: bestAudio.url,
        bitrate: bestAudio.bitrate.bitsPerSecond,
        container: bestAudio.container.name,
        sizeBytes: bestAudio.size.totalBytes,
      );
    } catch (e, st) {
      AppLogger.error('MusicSource', 'Failed to get stream URL for $videoId', e, st);
      throw MusicSourceException('Failed to get audio stream URL for $videoId: $e', e);
    }
  }

  @override
  Future<TrackInfo> getTrackDetails(String videoId) async {
    try {
      final video = await _yt.videos.get(videoId);
      return _mapVideoToTrack(video);
    } catch (e) {
      throw MusicSourceException('Failed to get track details for $videoId: $e', e);
    }
  }

  TrackInfo _mapVideoToTrack(Video video) {
    final title = _cleanTitle(video.title);
    final artist = video.author;
    final thumbnailUrl = video.thumbnails.highResUrl.isNotEmpty
        ? video.thumbnails.highResUrl
        : (video.thumbnails.standardResUrl.isNotEmpty
            ? video.thumbnails.standardResUrl
            : video.thumbnails.lowResUrl);

    final tags = <String>[];
    for (final keyword in video.keywords) {
      if (keyword.isNotEmpty && tags.length < 5) {
        tags.add(keyword.toLowerCase());
      }
    }

    return TrackInfo(
      id: video.id.value,
      title: title,
      artist: artist,
      duration: video.duration ?? Duration.zero,
      thumbnailUrl: thumbnailUrl,
      tags: tags,
    );
  }

  String _cleanTitle(String rawTitle) {
    // Remove typical noise like (Official Music Video), [Official Audio], etc.
    return rawTitle
        .replaceAll(RegExp(r'\((Official\s*(Music\s*)?Video|Official\s*Audio|Lyric\s*Video|Audio)\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[(Official\s*(Music\s*)?Video|Official\s*Audio|Lyric\s*Video|Audio)\]', caseSensitive: false), '')
        .trim();
  }

  @override
  void dispose() {
    _yt.close();
  }
}
