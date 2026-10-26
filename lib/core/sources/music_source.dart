import 'package:audio_service/audio_service.dart';

class TrackInfo {
  final String id;
  final String title;
  final String artist;
  final Duration duration;
  final String thumbnailUrl;
  final List<String> tags;
  final String? localFilePath;
  final bool isDownloaded;

  const TrackInfo({
    required this.id,
    required this.title,
    required this.artist,
    required this.duration,
    required this.thumbnailUrl,
    this.tags = const [],
    this.localFilePath,
    this.isDownloaded = false,
  });

  TrackInfo copyWith({
    String? id,
    String? title,
    String? artist,
    Duration? duration,
    String? thumbnailUrl,
    List<String>? tags,
    String? localFilePath,
    bool? isDownloaded,
  }) {
    return TrackInfo(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      duration: duration ?? this.duration,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      tags: tags ?? this.tags,
      localFilePath: localFilePath ?? this.localFilePath,
      isDownloaded: isDownloaded ?? this.isDownloaded,
    );
  }

  MediaItem toMediaItem() {
    return MediaItem(
      id: id,
      title: title,
      artist: artist,
      duration: duration,
      artUri: Uri.tryParse(thumbnailUrl),
      extras: {
        'tags': tags,
        'localFilePath': localFilePath,
        'isDownloaded': isDownloaded,
      },
    );
  }

  factory TrackInfo.fromMediaItem(MediaItem item) {
    return TrackInfo(
      id: item.id,
      title: item.title,
      artist: item.artist ?? 'Unknown Artist',
      duration: item.duration ?? Duration.zero,
      thumbnailUrl: item.artUri?.toString() ?? '',
      tags: List<String>.from(item.extras?['tags'] ?? []),
      localFilePath: item.extras?['localFilePath'] as String?,
      isDownloaded: item.extras?['isDownloaded'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'durationMs': duration.inMilliseconds,
      'thumbnailUrl': thumbnailUrl,
      'tags': tags,
      'localFilePath': localFilePath,
      'isDownloaded': isDownloaded,
    };
  }

  factory TrackInfo.fromJson(Map<String, dynamic> json) {
    return TrackInfo(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      tags: List<String>.from(json['tags'] ?? []),
      localFilePath: json['localFilePath'] as String?,
      isDownloaded: json['isDownloaded'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackInfo && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class AudioStreamInfoResult {
  final Uri url;
  final int bitrate;
  final String container;
  final int sizeBytes;
  final List<Uri> fallbackUrls;
  final Map<String, String> headers;

  const AudioStreamInfoResult({
    required this.url,
    required this.bitrate,
    required this.container,
    required this.sizeBytes,
    this.fallbackUrls = const [],
    this.headers = const {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
      'Referer': 'https://www.youtube.com/',
      'Origin': 'https://www.youtube.com',
    },
  });
}

class AudioStreamData {
  final Stream<List<int>> stream;
  final int sizeBytes;
  final String container;
  final int bitrate;
  final Uri? url;
  final int totalAvailableStreams;

  const AudioStreamData({
    required this.stream,
    required this.sizeBytes,
    required this.container,
    required this.bitrate,
    this.url,
    this.totalAvailableStreams = 1,
  });
}

abstract class MusicSource {
  Future<List<TrackInfo>> search(String query);
  Future<List<TrackInfo>> getTrending();
  Future<List<TrackInfo>> getRelatedTracks(String videoId, {int limit = 10});
  Future<AudioStreamInfoResult> getStreamUrl(String videoId);
  Future<Stream<List<int>>> getAudioStream(String videoId);
  Future<AudioStreamData> getAudioStreamData(String videoId, {int attemptIndex = 0, Set<String>? excludeUrls});
  Future<TrackInfo> getTrackDetails(String videoId);
  void dispose();
}
