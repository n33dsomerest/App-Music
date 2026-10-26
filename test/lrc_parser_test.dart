import 'package:flutter_test/flutter_test.dart';
import 'package:music_apl/core/utils/lrc_parser.dart';

void main() {
  group('LrcParser Tests', () {
    const sampleLrc = '''
[ti:Never Gonna Give You Up]
[ar:Rick Astley]
[00:00.00] 
[00:18.50] We're no strangers to love
[00:22.80] You know the rules and so do I
[00:27.10] A full commitment's what I'm thinking of
[00:31.40] You wouldn't get this from any other guy
[00:35.70] I just wanna tell you how I'm feeling
[00:40.00] Gotta make you understand
''';

    test('should correctly parse LRC lines and timestamps', () {
      final lines = LrcParser.parse(sampleLrc);

      expect(lines.length, 7);
      expect(lines[1].text, "We're no strangers to love");
      expect(lines[1].timestamp, const Duration(seconds: 18, milliseconds: 500));
      expect(lines[2].text, 'You know the rules and so do I');
      expect(lines[2].timestamp, const Duration(seconds: 22, milliseconds: 800));
    });

    test('should find active index using binary search', () {
      final lines = LrcParser.parse(sampleLrc);

      // Before first line
      expect(
        LrcParser.findActiveIndex(lines, const Duration(seconds: 5)),
        0,
      );

      // Exactly at second line
      expect(
        LrcParser.findActiveIndex(lines, const Duration(seconds: 18, milliseconds: 500)),
        1,
      );

      // Between second and third line
      expect(
        LrcParser.findActiveIndex(lines, const Duration(seconds: 20)),
        1,
      );

      // At third line
      expect(
        LrcParser.findActiveIndex(lines, const Duration(seconds: 25)),
        2,
      );

      // Beyond last line
      expect(
        LrcParser.findActiveIndex(lines, const Duration(seconds: 50)),
        6,
      );
    });

    test('should apply offset adjustments in binary search', () {
      final lines = LrcParser.parse(sampleLrc);

      // At 18.0s without offset -> still line 0
      expect(
        LrcParser.findActiveIndex(lines, const Duration(seconds: 18)),
        0,
      );

      // At 18.0s with +1.0s offset (target = 19.0s) -> active line 1
      expect(
        LrcParser.findActiveIndex(
          lines,
          const Duration(seconds: 18),
          offset: const Duration(seconds: 1),
        ),
        1,
      );

      // At 19.0s with -1.0s offset (target = 18.0s) -> active line 0
      expect(
        LrcParser.findActiveIndex(
          lines,
          const Duration(seconds: 19),
          offset: const Duration(seconds: -1),
        ),
        0,
      );
    });

    test('should handle empty or null LRC safely', () {
      expect(LrcParser.parse(null), isEmpty);
      expect(LrcParser.parse(''), isEmpty);
      expect(LrcParser.findActiveIndex([], const Duration(seconds: 10)), -1);
    });
  });
}
