import 'package:flutter_test/flutter_test.dart';
import 'package:music_apl/core/utils/app_logger.dart';

void main() {
  group('AppLogger Tests', () {
    setUp(() {
      AppLogger.clear();
    });

    test('should record log entries correctly', () {
      AppLogger.info('TestTag', 'Test Info Message');
      AppLogger.warn('TestTag', 'Test Warning Message');
      AppLogger.error('TestTag', 'Test Error Message', 'Simulated Exception');

      final logs = AppLogger().logs;
      expect(logs.length, 3);
      expect(logs[0].level, LogLevel.info);
      expect(logs[0].message, 'Test Info Message');
      expect(logs[1].level, LogLevel.warning);
      expect(logs[2].level, LogLevel.error);
      expect(logs[2].error, 'Simulated Exception');
    });

    test('should export all logs formatted for clipboard copying', () {
      AppLogger.info('Audio', 'Starting playback');
      final export = AppLogger.exportAll();

      expect(export, contains('[INFO]'));
      expect(export, contains('[Audio]'));
      expect(export, contains('Starting playback'));
    });

    test('should clear logs', () {
      AppLogger.info('Tag', 'Msg');
      expect(AppLogger().logs.isNotEmpty, true);
      AppLogger.clear();
      expect(AppLogger().logs.isEmpty, true);
    });
  });
}
