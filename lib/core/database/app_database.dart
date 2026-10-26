import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import '../sources/music_source.dart';

part 'app_database.g.dart';

class PlayHistories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get videoId => text()();
  TextColumn get title => text()();
  TextColumn get artist => text()();
  TextColumn get genreOrTags => text().withDefault(const Constant(''))();
  DateTimeColumn get playedAt => dateTime()();
  RealColumn get completionRatio => real().withDefault(const Constant(0.0))();
  IntColumn get durationSeconds => integer().withDefault(const Constant(0))();
}

class Downloads extends Table {
  TextColumn get videoId => text()();
  TextColumn get title => text()();
  TextColumn get artist => text()();
  IntColumn get durationSeconds => integer().withDefault(const Constant(0))();
  TextColumn get thumbnailUrl => text().withDefault(const Constant(''))();
  TextColumn get localFilePath => text().withDefault(const Constant(''))();
  IntColumn get fileSizeBytes => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending, downloading, completed, failed
  RealColumn get downloadProgress => real().withDefault(const Constant(0.0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {videoId};
}

class LyricsCaches extends Table {
  TextColumn get videoId => text()();
  TextColumn get plainLyrics => text().nullable()();
  TextColumn get syncedLyrics => text().nullable()();
  IntColumn get offsetMs => integer().withDefault(const Constant(0))();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {videoId};
}

class ArtistScore {
  final String artist;
  final double score;

  const ArtistScore({required this.artist, required this.score});
}

class GenreScore {
  final String genre;
  final double score;

  const GenreScore({required this.genre, required this.score});
}

@DriftDatabase(tables: [PlayHistories, Downloads, LyricsCaches])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'music_apl_db');
  }

  // ==================== Play History Methods ====================

  Future<int> logPlay({
    required String videoId,
    required String title,
    required String artist,
    required List<String> tags,
    required double completionRatio,
    required Duration duration,
  }) {
    return into(playHistories).insert(
      PlayHistoriesCompanion(
        videoId: Value(videoId),
        title: Value(title),
        artist: Value(artist),
        genreOrTags: Value(tags.join(',')),
        playedAt: Value(DateTime.now()),
        completionRatio: Value(completionRatio.clamp(0.0, 1.0)),
        durationSeconds: Value(duration.inSeconds),
      ),
    );
  }

  Stream<List<PlayHistory>> watchRecentlyPlayed({int limit = 30}) {
    final query = select(playHistories)
      ..orderBy([(t) => OrderingTerm.desc(t.playedAt)])
      ..limit(limit);
    return query.watch();
  }

  /// Calculates top artists from play history weighted by recency and completion ratio.
  Future<List<ArtistScore>> getTopArtists({int limit = 5}) async {
    final history = await (select(playHistories)
      ..orderBy([(t) => OrderingTerm.desc(t.playedAt)])
      ..limit(100)).get();

    final now = DateTime.now();
    final scores = <String, double>{};

    for (final entry in history) {
      if (entry.artist.trim().isEmpty) continue;

      // Recency weighting
      final daysAgo = now.difference(entry.playedAt).inDays;
      double recencyWeight = 1.0;
      if (daysAgo <= 7) {
        recencyWeight = 3.0;
      } else if (daysAgo <= 30) {
        recencyWeight = 1.8;
      }

      // Completion bonus: songs played > 70% get a strong boost
      double completionBonus = entry.completionRatio >= 0.7 ? 2.0 : (entry.completionRatio >= 0.3 ? 1.0 : 0.5);

      final playScore = recencyWeight * completionBonus;
      scores[entry.artist] = (scores[entry.artist] ?? 0.0) + playScore;
    }

    final sorted = scores.entries
        .map((e) => ArtistScore(artist: e.key, score: e.value))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return sorted.take(limit).toList();
  }

  /// Calculates top genres/tags from play history.
  Future<List<GenreScore>> getTopGenres({int limit = 5}) async {
    final history = await (select(playHistories)
      ..orderBy([(t) => OrderingTerm.desc(t.playedAt)])
      ..limit(100)).get();

    final now = DateTime.now();
    final scores = <String, double>{};

    for (final entry in history) {
      final tags = entry.genreOrTags
          .split(',')
          .map((t) => t.trim().toLowerCase())
          .where((t) => t.isNotEmpty && t.length > 2);

      final daysAgo = now.difference(entry.playedAt).inDays;
      final recencyWeight = daysAgo <= 7 ? 3.0 : (daysAgo <= 30 ? 1.8 : 1.0);
      final playScore = recencyWeight * (entry.completionRatio >= 0.7 ? 2.0 : 1.0);

      for (final tag in tags) {
        // Filter out generic youtube tags
        if (tag.contains('video') || tag.contains('official') || tag.contains('channel')) {
          continue;
        }
        scores[tag] = (scores[tag] ?? 0.0) + playScore;
      }
    }

    final sorted = scores.entries
        .map((e) => GenreScore(genre: e.key, score: e.value))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return sorted.take(limit).toList();
  }

  // ==================== Lyrics Cache Methods ====================

  Future<LyricsCache?> getLyrics(String videoId) {
    return (select(lyricsCaches)..where((t) => t.videoId.equals(videoId)))
        .getSingleOrNull();
  }

  Future<void> cacheLyrics({
    required String videoId,
    String? plainLyrics,
    String? syncedLyrics,
    int offsetMs = 0,
  }) {
    return into(lyricsCaches).insertOnConflictUpdate(
      LyricsCachesCompanion(
        videoId: Value(videoId),
        plainLyrics: Value(plainLyrics),
        syncedLyrics: Value(syncedLyrics),
        offsetMs: Value(offsetMs),
        cachedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updateLyricsOffset(String videoId, int offsetMs) {
    return (update(lyricsCaches)..where((t) => t.videoId.equals(videoId)))
        .write(LyricsCachesCompanion(offsetMs: Value(offsetMs)));
  }

  // ==================== Downloads Methods ====================

  Stream<List<Download>> watchAllDownloads() {
    return (select(downloads)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Stream<List<Download>> watchCompletedDownloads() {
    return (select(downloads)
          ..where((t) => t.status.equals('completed'))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<Download?> getDownload(String videoId) {
    return (select(downloads)..where((t) => t.videoId.equals(videoId)))
        .getSingleOrNull();
  }

  Stream<Download?> watchDownload(String videoId) {
    return (select(downloads)..where((t) => t.videoId.equals(videoId)))
        .watchSingleOrNull();
  }

  Future<List<Download>> getIncompleteDownloads() {
    return (select(downloads)
          ..where((t) => t.status.isIn(['pending', 'downloading'])))
        .get();
  }

  Future<void> saveDownloadEntry({
    required TrackInfo track,
    required String localFilePath,
    required String status,
    double progress = 0.0,
    int fileSizeBytes = 0,
  }) {
    return into(downloads).insertOnConflictUpdate(
      DownloadsCompanion(
        videoId: Value(track.id),
        title: Value(track.title),
        artist: Value(track.artist),
        durationSeconds: Value(track.duration.inSeconds),
        thumbnailUrl: Value(track.thumbnailUrl),
        localFilePath: Value(localFilePath),
        status: Value(status),
        downloadProgress: Value(progress),
        fileSizeBytes: Value(fileSizeBytes),
        createdAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updateDownloadStatus({
    required String videoId,
    required String status,
    double? progress,
    int? fileSizeBytes,
    String? localFilePath,
  }) {
    return (update(downloads)..where((t) => t.videoId.equals(videoId))).write(
      DownloadsCompanion(
        status: Value(status),
        downloadProgress: progress != null ? Value(progress) : const Value.absent(),
        fileSizeBytes: fileSizeBytes != null ? Value(fileSizeBytes) : const Value.absent(),
        localFilePath: localFilePath != null ? Value(localFilePath) : const Value.absent(),
      ),
    );
  }

  Future<int> deleteDownloadEntry(String videoId) {
    return (delete(downloads)..where((t) => t.videoId.equals(videoId))).go();
  }
}
