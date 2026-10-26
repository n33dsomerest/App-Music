import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/audio/audio_handler.dart';
import 'core/audio/audio_service_provider.dart';
import 'core/database/app_database.dart';
import 'core/sources/youtube_music_source.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_logger.dart';
import 'features/navigation/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global Flutter error catching to AppLogger
  FlutterError.onError = (details) {
    AppLogger.error('FlutterError', details.exceptionAsString(), details.exception, details.stack);
    FlutterError.presentError(details);
  };

  AppLogger.info('App', 'App initialized');

  final database = AppDatabase();
  final musicSource = YoutubeMusicSource();

  // Initialize background AudioService with lock-screen controls & notifications
  final audioHandler = await AudioService.init(
    builder: () => MusicAudioHandler(
      musicSource: musicSource,
      database: database,
    ),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.musicapl.app.channel.audio',
      androidNotificationChannelName: 'MusicApl Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        musicSourceProvider.overrideWithValue(musicSource),
        audioHandlerProvider.overrideWithValue(audioHandler),
      ],
      child: const MusicAplApp(),
    ),
  );
}

class MusicAplApp extends StatelessWidget {
  const MusicAplApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MusicApl',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: appRouter,
    );
  }
}
