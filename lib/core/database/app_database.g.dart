// ignore_for_file: type=lint
part of 'app_database.dart';

class PlayHistory extends DataClass implements Insertable<PlayHistory> {
  final int id;
  final String videoId;
  final String title;
  final String artist;
  final String genreOrTags;
  final DateTime playedAt;
  final double completionRatio;
  final int durationSeconds;

  const PlayHistory({
    required this.id,
    required this.videoId,
    required this.title,
    required this.artist,
    required this.genreOrTags,
    required this.playedAt,
    required this.completionRatio,
    required this.durationSeconds,
  });

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['video_id'] = Variable<String>(videoId);
    map['title'] = Variable<String>(title);
    map['artist'] = Variable<String>(artist);
    map['genre_or_tags'] = Variable<String>(genreOrTags);
    map['played_at'] = Variable<DateTime>(playedAt);
    map['completion_ratio'] = Variable<double>(completionRatio);
    map['duration_seconds'] = Variable<int>(durationSeconds);
    return map;
  }

  PlayHistoriesCompanion toCompanion(bool nullToAbsent) {
    return PlayHistoriesCompanion(
      id: Value(id),
      videoId: Value(videoId),
      title: Value(title),
      artist: Value(artist),
      genreOrTags: Value(genreOrTags),
      playedAt: Value(playedAt),
      completionRatio: Value(completionRatio),
      durationSeconds: Value(durationSeconds),
    );
  }

  factory PlayHistory.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlayHistory(
      id: serializer.fromJson<int>(json['id']),
      videoId: serializer.fromJson<String>(json['videoId']),
      title: serializer.fromJson<String>(json['title']),
      artist: serializer.fromJson<String>(json['artist']),
      genreOrTags: serializer.fromJson<String>(json['genreOrTags']),
      playedAt: serializer.fromJson<DateTime>(json['playedAt']),
      completionRatio: serializer.fromJson<double>(json['completionRatio']),
      durationSeconds: serializer.fromJson<int>(json['durationSeconds']),
    );
  }

  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'videoId': serializer.toJson<String>(videoId),
      'title': serializer.toJson<String>(title),
      'artist': serializer.toJson<String>(artist),
      'genreOrTags': serializer.toJson<String>(genreOrTags),
      'playedAt': serializer.toJson<DateTime>(playedAt),
      'completionRatio': serializer.toJson<double>(completionRatio),
      'durationSeconds': serializer.toJson<int>(durationSeconds),
    };
  }

  PlayHistory copyWith({
    int? id,
    String? videoId,
    String? title,
    String? artist,
    String? genreOrTags,
    DateTime? playedAt,
    double? completionRatio,
    int? durationSeconds,
  }) =>
      PlayHistory(
        id: id ?? this.id,
        videoId: videoId ?? this.videoId,
        title: title ?? this.title,
        artist: artist ?? this.artist,
        genreOrTags: genreOrTags ?? this.genreOrTags,
        playedAt: playedAt ?? this.playedAt,
        completionRatio: completionRatio ?? this.completionRatio,
        durationSeconds: durationSeconds ?? this.durationSeconds,
      );
}

class PlayHistoriesCompanion extends UpdateCompanion<PlayHistory> {
  final Value<int> id;
  final Value<String> videoId;
  final Value<String> title;
  final Value<String> artist;
  final Value<String> genreOrTags;
  final Value<DateTime> playedAt;
  final Value<double> completionRatio;
  final Value<int> durationSeconds;

  const PlayHistoriesCompanion({
    this.id = const Value.absent(),
    this.videoId = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.genreOrTags = const Value.absent(),
    this.playedAt = const Value.absent(),
    this.completionRatio = const Value.absent(),
    this.durationSeconds = const Value.absent(),
  });

  PlayHistoriesCompanion.insert({
    this.id = const Value.absent(),
    required String videoId,
    required String title,
    required String artist,
    this.genreOrTags = const Value.absent(),
    required DateTime playedAt,
    this.completionRatio = const Value.absent(),
    this.durationSeconds = const Value.absent(),
  })  : videoId = Value(videoId),
        title = Value(title),
        artist = Value(artist),
        playedAt = Value(playedAt);
}

class $PlayHistoriesTable extends PlayHistories
    with TableInfo<$PlayHistoriesTable, PlayHistory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlayHistoriesTable(this.attachedDatabase, [this._alias]);

  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsURL('PRIMARY KEY AUTOINCREMENT'));

  static const VerificationMeta _videoIdMeta =
      const VerificationMeta('videoId');
  late final GeneratedColumn<String> videoId = GeneratedColumn<String>(
      'video_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);

  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);

  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
      'artist', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);

  static const VerificationMeta _genreOrTagsMeta =
      const VerificationMeta('genreOrTags');
  late final GeneratedColumn<String> genreOrTags = GeneratedColumn<String>(
      'genre_or_tags', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));

  static const VerificationMeta _playedAtMeta =
      const VerificationMeta('playedAt');
  late final GeneratedColumn<DateTime> playedAt = GeneratedColumn<DateTime>(
      'played_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);

  static const VerificationMeta _completionRatioMeta =
      const VerificationMeta('completionRatio');
  late final GeneratedColumn<double> completionRatio = GeneratedColumn<double>(
      'completion_ratio', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));

  static const VerificationMeta _durationSecondsMeta =
      const VerificationMeta('durationSeconds');
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
      'duration_seconds', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));

  @override
  List<GeneratedColumn> get $columns => [
        id,
        videoId,
        title,
        artist,
        genreOrTags,
        playedAt,
        completionRatio,
        durationSeconds,
      ];

  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'play_histories';
  @override
  VerificationContext validateIntegrity(Insertable<PlayHistory> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlayHistory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlayHistory(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      videoId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}video_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      artist: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}artist'])!,
      genreOrTags: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}genre_or_tags'])!,
      playedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}played_at'])!,
      completionRatio: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}completion_ratio'])!,
      durationSeconds: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}duration_seconds'])!,
    );
  }

  @override
  $PlayHistoriesTable createAlias(String alias) {
    return $PlayHistoriesTable(attachedDatabase, alias);
  }
}

class Download extends DataClass implements Insertable<Download> {
  final String videoId;
  final String title;
  final String artist;
  final int durationSeconds;
  final String thumbnailUrl;
  final String localFilePath;
  final int fileSizeBytes;
  final String status;
  final double downloadProgress;
  final DateTime createdAt;

  const Download({
    required this.videoId,
    required this.title,
    required this.artist,
    required this.durationSeconds,
    required this.thumbnailUrl,
    required this.localFilePath,
    required this.fileSizeBytes,
    required this.status,
    required this.downloadProgress,
    required this.createdAt,
  });

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['video_id'] = Variable<String>(videoId);
    map['title'] = Variable<String>(title);
    map['artist'] = Variable<String>(artist);
    map['duration_seconds'] = Variable<int>(durationSeconds);
    map['thumbnail_url'] = Variable<String>(thumbnailUrl);
    map['local_file_path'] = Variable<String>(localFilePath);
    map['file_size_bytes'] = Variable<int>(fileSizeBytes);
    map['status'] = Variable<String>(status);
    map['download_progress'] = Variable<double>(downloadProgress);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  DownloadsCompanion toCompanion(bool nullToAbsent) {
    return DownloadsCompanion(
      videoId: Value(videoId),
      title: Value(title),
      artist: Value(artist),
      durationSeconds: Value(durationSeconds),
      thumbnailUrl: Value(thumbnailUrl),
      localFilePath: Value(localFilePath),
      fileSizeBytes: Value(fileSizeBytes),
      status: Value(status),
      downloadProgress: Value(downloadProgress),
      createdAt: Value(createdAt),
    );
  }

  Download copyWith({
    String? videoId,
    String? title,
    String? artist,
    int? durationSeconds,
    String? thumbnailUrl,
    String? localFilePath,
    int? fileSizeBytes,
    String? status,
    double? downloadProgress,
    DateTime? createdAt,
  }) =>
      Download(
        videoId: videoId ?? this.videoId,
        title: title ?? this.title,
        artist: artist ?? this.artist,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
        localFilePath: localFilePath ?? this.localFilePath,
        fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
        status: status ?? this.status,
        downloadProgress: downloadProgress ?? this.downloadProgress,
        createdAt: createdAt ?? this.createdAt,
      );
}

class DownloadsCompanion extends UpdateCompanion<Download> {
  final Value<String> videoId;
  final Value<String> title;
  final Value<String> artist;
  final Value<int> durationSeconds;
  final Value<String> thumbnailUrl;
  final Value<String> localFilePath;
  final Value<int> fileSizeBytes;
  final Value<String> status;
  final Value<double> downloadProgress;
  final Value<DateTime> createdAt;

  const DownloadsCompanion({
    this.videoId = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.thumbnailUrl = const Value.absent(),
    this.localFilePath = const Value.absent(),
    this.fileSizeBytes = const Value.absent(),
    this.status = const Value.absent(),
    this.downloadProgress = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
}

class $DownloadsTable extends Downloads
    with TableInfo<$DownloadsTable, Download> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadsTable(this.attachedDatabase, [this._alias]);

  late final GeneratedColumn<String> videoId = GeneratedColumn<String>(
      'video_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);

  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);

  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
      'artist', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);

  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
      'duration_seconds', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));

  late final GeneratedColumn<String> thumbnailUrl = GeneratedColumn<String>(
      'thumbnail_url', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));

  late final GeneratedColumn<String> localFilePath = GeneratedColumn<String>(
      'local_file_path', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));

  late final GeneratedColumn<int> fileSizeBytes = GeneratedColumn<int>(
      'file_size_bytes', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));

  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));

  late final GeneratedColumn<double> downloadProgress = GeneratedColumn<double>(
      'download_progress', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));

  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);

  @override
  List<GeneratedColumn> get $columns => [
        videoId,
        title,
        artist,
        durationSeconds,
        thumbnailUrl,
        localFilePath,
        fileSizeBytes,
        status,
        downloadProgress,
        createdAt,
      ];

  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'downloads';

  @override
  Set<GeneratedColumn> get $primaryKey => {videoId};

  @override
  Download map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Download(
      videoId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}video_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      artist: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}artist'])!,
      durationSeconds: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_seconds'])!,
      thumbnailUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}thumbnail_url'])!,
      localFilePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}local_file_path'])!,
      fileSizeBytes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}file_size_bytes'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      downloadProgress: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}download_progress'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $DownloadsTable createAlias(String alias) {
    return $DownloadsTable(attachedDatabase, alias);
  }
}

class LyricsCache extends DataClass implements Insertable<LyricsCache> {
  final String videoId;
  final String? plainLyrics;
  final String? syncedLyrics;
  final int offsetMs;
  final DateTime cachedAt;

  const LyricsCache({
    required this.videoId,
    this.plainLyrics,
    this.syncedLyrics,
    required this.offsetMs,
    required this.cachedAt,
  });

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['video_id'] = Variable<String>(videoId);
    if (!nullToAbsent || plainLyrics != null) {
      map['plain_lyrics'] = Variable<String>(plainLyrics);
    }
    if (!nullToAbsent || syncedLyrics != null) {
      map['synced_lyrics'] = Variable<String>(syncedLyrics);
    }
    map['offset_ms'] = Variable<int>(offsetMs);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  LyricsCachesCompanion toCompanion(bool nullToAbsent) {
    return LyricsCachesCompanion(
      videoId: Value(videoId),
      plainLyrics: plainLyrics == null && nullToAbsent
          ? const Value.absent()
          : Value(plainLyrics),
      syncedLyrics: syncedLyrics == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedLyrics),
      offsetMs: Value(offsetMs),
      cachedAt: Value(cachedAt),
    );
  }

  LyricsCache copyWith({
    String? videoId,
    String? plainLyrics,
    String? syncedLyrics,
    int? offsetMs,
    DateTime? cachedAt,
  }) =>
      LyricsCache(
        videoId: videoId ?? this.videoId,
        plainLyrics: plainLyrics ?? this.plainLyrics,
        syncedLyrics: syncedLyrics ?? this.syncedLyrics,
        offsetMs: offsetMs ?? this.offsetMs,
        cachedAt: cachedAt ?? this.cachedAt,
      );
}

class LyricsCachesCompanion extends UpdateCompanion<LyricsCache> {
  final Value<String> videoId;
  final Value<String?> plainLyrics;
  final Value<String?> syncedLyrics;
  final Value<int> offsetMs;
  final Value<DateTime> cachedAt;

  const LyricsCachesCompanion({
    this.videoId = const Value.absent(),
    this.plainLyrics = const Value.absent(),
    this.syncedLyrics = const Value.absent(),
    this.offsetMs = const Value.absent(),
    this.cachedAt = const Value.absent(),
  });
}

class $LyricsCachesTable extends LyricsCaches
    with TableInfo<$LyricsCachesTable, LyricsCache> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LyricsCachesTable(this.attachedDatabase, [this._alias]);

  late final GeneratedColumn<String> videoId = GeneratedColumn<String>(
      'video_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);

  late final GeneratedColumn<String> plainLyrics = GeneratedColumn<String>(
      'plain_lyrics', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);

  late final GeneratedColumn<String> syncedLyrics = GeneratedColumn<String>(
      'synced_lyrics', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);

  late final GeneratedColumn<int> offsetMs = GeneratedColumn<int>(
      'offset_ms', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));

  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
      'cached_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);

  @override
  List<GeneratedColumn> get $columns => [
        videoId,
        plainLyrics,
        syncedLyrics,
        offsetMs,
        cachedAt,
      ];

  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lyrics_caches';

  @override
  Set<GeneratedColumn> get $primaryKey => {videoId};

  @override
  LyricsCache map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LyricsCache(
      videoId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}video_id'])!,
      plainLyrics: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}plain_lyrics']),
      syncedLyrics: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}synced_lyrics']),
      offsetMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}offset_ms'])!,
      cachedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}cached_at'])!,
    );
  }

  @override
  $LyricsCachesTable createAlias(String alias) {
    return $LyricsCachesTable(attachedDatabase, alias);
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  late final $PlayHistoriesTable playHistories = $PlayHistoriesTable(this);
  late final $DownloadsTable downloads = $DownloadsTable(this);
  late final $LyricsCachesTable lyricsCaches = $LyricsCachesTable(this);

  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [playHistories, downloads, lyricsCaches];
}
