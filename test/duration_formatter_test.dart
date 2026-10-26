import 'package:flutter_test/flutter_test.dart';
import 'package:music_apl/core/utils/duration_formatter.dart';

void main() {
  group('DurationFormatter Tests', () {
    test('formats minutes and seconds properly', () {
      expect(DurationFormatter.format(const Duration(seconds: 45)), '0:45');
      expect(DurationFormatter.format(const Duration(minutes: 3, seconds: 5)), '3:05');
      expect(DurationFormatter.format(const Duration(minutes: 12, seconds: 34)), '12:34');
    });

    test('formats hours properly', () {
      expect(
        DurationFormatter.format(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
    });

    test('handles negative duration gracefully', () {
      expect(DurationFormatter.format(const Duration(seconds: -10)), '0:00');
    });

    test('formats bytes properly', () {
      expect(DurationFormatter.formatBytes(500), '500.0 B');
      expect(DurationFormatter.formatBytes(1024), '1.0 KB');
      expect(DurationFormatter.formatBytes(1024 * 1024 * 5), '5.0 MB');
    });
  });
}
