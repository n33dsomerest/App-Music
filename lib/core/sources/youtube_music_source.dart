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

  Future<StreamManifest> _getStreamManifest(String videoId) async {
    // 1. Android VR client alone
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(
        videoId,
        ytClients: [YoutubeApiClient.androidVr],
      );
      AppLogger.info('MusicSource', 'Resolved stream manifest for $videoId using [androidVr]');
      return manifest;
    } catch (e1) {
      AppLogger.warn('MusicSource', 'Client [androidVr] failed for $videoId: $e1, trying [androidVr, tv]');
    }

    // 2. Android VR + TV
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(
        videoId,
        ytClients: [YoutubeApiClient.androidVr, YoutubeApiClient.tv],
      );
      AppLogger.info('MusicSource', 'Resolved stream manifest for $videoId using [androidVr, tv]');
      return manifest;
    } catch (e2) {
      AppLogger.warn('MusicSource', 'Client [androidVr, tv] failed for $videoId: $e2, trying [ios]');
    }

    // 3. iOS client
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(
        videoId,
        ytClients: [YoutubeApiClient.ios],
      );
      AppLogger.info('MusicSource', 'Resolved stream manifest for $videoId using [ios]');
      return manifest;
    } catch (e3) {
      AppLogger.warn('MusicSource', 'Client [ios] failed for $videoId: $e3, trying [android]');
    }

    // 4. Android client
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(
        videoId,
        ytClients: [YoutubeApiClient.android],
      );
      AppLogger.info('MusicSource', 'Resolved stream manifest for $videoId using [android]');
      return manifest;
    } catch (e4) {
      AppLogger.warn('MusicSource', 'Client [android] failed for $videoId: $e4, trying default client');
    }

    // 5. Default client
    final manifest = await _yt.videos.streamsClient.getManifest(videoId);
    AppLogger.info('MusicSource', 'Resolved stream manifest for $videoId using [default]');
    return manifest;
  }

  @override
  Future<AudioStreamInfoResult> getStreamUrl(String videoId) async {
    AppLogger.info('MusicSource', 'Fetching stream manifest for: $videoId');
    try {
      final manifest = await _getStreamManifest(videoId);

      final allAudio = manifest.audioOnly.isNotEmpty
          ? manifest.audioOnly.toList()
          : manifest.muxed.toList();
      if (allAudio.isEmpty) {
        throw MusicSourceException('No audio streams available for track $videoId');
      }

      // Prioritize M4A (AAC) streams for native Android ExoPlayer & iOS AVPlayer compatibility
      allAudio.sort((a, b) {
        final aIsM4a = a.container.name.toLowerCase() == 'm4a' ||
            a.container.name.toLowerCase() == 'mp4';
        final bIsM4a = b.container.name.toLowerCase() == 'm4a' ||
            b.container.name.toLowerCase() == 'mp4';
        if (aIsM4a && !bIsM4a) return -1;
        if (!aIsM4a && bIsM4a) return 1;
        return b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond);
      });

      final bestAudio = allAudio.first;
      final fallbackUrls = allAudio.skip(1).take(4).map((s) => s.url).toList();

      AppLogger.info('MusicSource', 'Resolved best audio stream: ${bestAudio.container.name}, ${bestAudio.bitrate.bitsPerSecond} bps, ${bestAudio.size.totalMegaBytes.toStringAsFixed(2)} MB (${fallbackUrls.length} fallbacks)');
      return AudioStreamInfoResult(
        url: bestAudio.url,
        bitrate: bestAudio.bitrate.bitsPerSecond,
        container: bestAudio.container.name,
        sizeBytes: bestAudio.size.totalBytes,
        fallbackUrls: fallbackUrls,
      );
    } catch (e, st) {
      AppLogger.error('MusicSource', 'Failed to get stream URL for $videoId', e, st);
      throw MusicSourceException('Failed to get audio stream URL for $videoId: $e', e);
    }
  }

  @override
  Future<AudioStreamData> getAudioStreamData(
    String videoId, {
    int attemptIndex = 0,
    Set<String>? excludeUrls,
  }) async {
    AppLogger.info('MusicSource', 'Fetching audio stream data for: $videoId (attempt: $attemptIndex)');
    try {
      final manifest = await _getStreamManifest(videoId);
      var allAudio = manifest.audioOnly.isNotEmpty
          ? manifest.audioOnly.toList()
          : manifest.muxed.toList();
      if (allAudio.isEmpty) {
        throw MusicSourceException('No audio streams available for track $videoId');
      }

      allAudio.sort((a, b) {
        final aIsM4a = a.container.name.toLowerCase() == 'm4a' ||
            a.container.name.toLowerCase() == 'mp4';
        final bIsM4a = b.container.name.toLowerCase() == 'm4a' ||
            b.container.name.toLowerCase() == 'mp4';
        if (aIsM4a && !bIsM4a) return -1;
        if (!aIsM4a && bIsM4a) return 1;
        return b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond);
      });

      // Filter out excluded / previously failed URLs
      if (excludeUrls != null && excludeUrls.isNotEmpty) {
        final filtered = allAudio.where((s) => !excludeUrls.contains(s.url.toString())).toList();
        if (filtered.isNotEmpty) {
          allAudio = filtered;
        }
      }

      final chosenIndex = attemptIndex.clamp(0, allAudio.length - 1);
      final selectedAudio = allAudio[chosenIndex];
      AppLogger.info('MusicSource',
          'Selected stream #${chosenIndex + 1}/${allAudio.length} for $videoId: ${selectedAudio.container.name}, ${selectedAudio.bitrate.bitsPerSecond} bps, ${(selectedAudio.size.totalBytes / (1024 * 1024)).toStringAsFixed(2)} MB');

      final stream = _yt.videos.streamsClient.get(selectedAudio);
      return AudioStreamData(
        stream: stream,
        sizeBytes: selectedAudio.size.totalBytes,
        container: selectedAudio.container.name,
        bitrate: selectedAudio.bitrate.bitsPerSecond,
        url: selectedAudio.url,
        totalAvailableStreams: allAudio.length,
      );
    } catch (e, st) {
      AppLogger.error('MusicSource', 'Failed to get audio stream data for $videoId', e, st);
      throw MusicSourceException('Failed to get audio stream data for $videoId: $e', e);
    }
  }

  @override
  Future<Stream<List<int>>> getAudioStream(String videoId) async {
    try {
      final data = await getAudioStreamData(videoId);
      return data.stream;
    } catch (e, st) {
      AppLogger.error('MusicSource', 'Failed to open audio byte stream for $videoId', e, st);
      throw MusicSourceException('Failed to open audio stream for $videoId: $e', e);
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
