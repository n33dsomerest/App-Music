class AppConstants {
  static const String appName = 'MusicApl';
  static const String appVersion = '1.0.0';

  // API Endpoints
  static const String lrclibBaseUrl = 'https://lrclib.net/api';

  // Storage Keys & Directories
  static const String downloadsDirectoryName = 'downloads';
  static const String lyricsCacheTable = 'lyrics_cache';
  static const String historyTable = 'play_history';
  static const String downloadsTable = 'downloads';

  // Player Settings
  static const Duration defaultPositionUpdateInterval = Duration(milliseconds: 200);
  static const Duration lyricsOffsetStep = Duration(milliseconds: 500);

  // Recommendation Scoring Weights
  static const double recentWeight7Days = 3.0;
  static const double recentWeight30Days = 1.5;
  static const double highCompletionThreshold = 0.7;
  static const double highCompletionBonus = 2.0;
}
