import 'dart:convert';
import 'package:dio/dio.dart';
import '../../core/constants/app_constants.dart';
import '../../core/database/app_database.dart';
import '../../core/utils/lrc_parser.dart';

class LyricsData {
  final String videoId;
  final String? plainLyrics;
  final String? syncedLyrics;
  final List<LrcLine> parsedSyncedLyrics;
  final int offsetMs;
  final bool isSynced;
  final bool isEmpty;

  const LyricsData({
    required this.videoId,
    this.plainLyrics,
    this.syncedLyrics,
    required this.parsedSyncedLyrics,
    this.offsetMs = 0,
    required this.isSynced,
    required this.isEmpty,
  });

  LyricsData copyWith({
    int? offsetMs,
  }) {
    return LyricsData(
      videoId: videoId,
      plainLyrics: plainLyrics,
      syncedLyrics: syncedLyrics,
      parsedSyncedLyrics: parsedSyncedLyrics,
      offsetMs: offsetMs ?? this.offsetMs,
      isSynced: isSynced,
      isEmpty: isEmpty,
    );
  }
}

class LrclibService {
  final Dio _dio;
  final AppDatabase _database;

  LrclibService({
    required AppDatabase database,
    Dio? dio,
  })  : _database = database,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConstants.lrclibBaseUrl,
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 8),
                headers: {
                  'User-Agent': 'MusicApl/1.0.0 (https://github.com/example/music-apl)',
                },
              ),
            );

  Future<LyricsData> getLyrics({
    required String videoId,
    required String title,
    required String artist,
    required Duration duration,
  }) async {
    // 1. Check local cache first
    try {
      final cached = await _database.getLyrics(videoId);
      if (cached != null) {
        final parsed = LrcParser.parse(cached.syncedLyrics);
        return LyricsData(
          videoId: videoId,
          plainLyrics: cached.plainLyrics,
          syncedLyrics: cached.syncedLyrics,
          parsedSyncedLyrics: parsed,
          offsetMs: cached.offsetMs,
          isSynced: parsed.isNotEmpty,
          isEmpty: (cached.plainLyrics == null || cached.plainLyrics!.trim().isEmpty) &&
              parsed.isEmpty,
        );
      }
    } catch (_) {}

    // Clean artist and track title for better lookup matches
    final cleanTitle = _cleanSongTitle(title);
    final cleanArtist = _cleanArtistName(artist);

    String? syncedLyrics;
    String? plainLyrics;

    // 2. Fetch from LRCLIB /api/get
    try {
      final response = await _dio.get(
        '/get',
        queryParameters: {
          'artist_name': cleanArtist,
          'track_name': cleanTitle,
          'duration': duration.inSeconds,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is Map ? response.data : jsonDecode(response.data.toString());
        syncedLyrics = data['syncedLyrics'] as String?;
        plainLyrics = data['plainLyrics'] as String?;
      }
    } catch (e) {
      // /api/get failed or 404, proceed to fallback search
    }

    // 3. Fallback to LRCLIB /api/search
    if (syncedLyrics == null && plainLyrics == null) {
      try {
        final searchResponse = await _dio.get(
          '/search',
          queryParameters: {
            'q': '$cleanArtist $cleanTitle',
          },
        );

        if (searchResponse.statusCode == 200 && searchResponse.data != null) {
          final list = searchResponse.data as List;
          if (list.isNotEmpty) {
            // Prefer items with synced lyrics
            final match = list.firstWhere(
              (item) => item['syncedLyrics'] != null,
              orElse: () => list.first,
            );
            syncedLyrics = match['syncedLyrics'] as String?;
            plainLyrics = match['plainLyrics'] as String?;
          }
        }
      } catch (_) {}
    }

    // 4. Cache in Drift Database
    await _database.cacheLyrics(
      videoId: videoId,
      plainLyrics: plainLyrics,
      syncedLyrics: syncedLyrics,
      offsetMs: 0,
    );

    final parsed = LrcParser.parse(syncedLyrics);
    return LyricsData(
      videoId: videoId,
      plainLyrics: plainLyrics,
      syncedLyrics: syncedLyrics,
      parsedSyncedLyrics: parsed,
      offsetMs: 0,
      isSynced: parsed.isNotEmpty,
      isEmpty: (plainLyrics == null || plainLyrics.trim().isEmpty) && parsed.isEmpty,
    );
  }

  Future<void> updateOffset(String videoId, int offsetMs) async {
    await _database.updateLyricsOffset(videoId, offsetMs);
  }

  String _cleanSongTitle(String title) {
    return title
        .replaceAll(RegExp(r'\((feat\.|ft\.|with).*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[(feat\.|ft\.|with).*?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(.*?video.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[.*?video.*?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(official.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[official.*?\]', caseSensitive: false), '')
        .trim();
  }

  String _cleanArtistName(String artist) {
    return artist
        .replaceAll(' - Topic', '')
        .replaceAll('VEVO', '')
        .trim();
  }
}
