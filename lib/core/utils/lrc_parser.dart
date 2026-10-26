class LrcLine {
  final Duration timestamp;
  final String text;

  const LrcLine({
    required this.timestamp,
    required this.text,
  });

  @override
  String toString() => '[${timestamp.inMilliseconds}ms] $text';
}

class LrcParser {
  static final RegExp _tagRegex = RegExp(r'\[(\d{2,}):(\d{2})(?:\.(\d{2,3}))?\]');

  /// Parses raw LRC string into a sorted list of [LrcLine].
  static List<LrcLine> parse(String? rawLrc) {
    if (rawLrc == null || rawLrc.trim().isEmpty) {
      return [];
    }

    final lines = rawLrc.split('\n');
    final List<LrcLine> parsed = [];

    for (var rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      // Skip metadata tags like [ti:], [ar:], [al:], etc.
      if (line.startsWith('[') && !line.startsWith(RegExp(r'\[\d'))) {
        continue;
      }

      final matches = _tagRegex.allMatches(line).toList();
      if (matches.isEmpty) continue;

      // The lyric text is everything after the last tag
      final text = line.substring(matches.last.end).trim();

      for (final match in matches) {
        final minutes = int.tryParse(match.group(1) ?? '0') ?? 0;
        final seconds = int.tryParse(match.group(2) ?? '0') ?? 0;
        final millisStr = match.group(3);

        int milliseconds = 0;
        if (millisStr != null) {
          if (millisStr.length == 2) {
            milliseconds = (int.tryParse(millisStr) ?? 0) * 10;
          } else {
            milliseconds = int.tryParse(millisStr) ?? 0;
          }
        }

        final duration = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: milliseconds,
        );

        parsed.add(LrcLine(timestamp: duration, text: text));
      }
    }

    // Sort chronologically
    parsed.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return parsed;
  }

  /// Binary search to find the active lyric line index for [currentPosition]
  /// with an optional [offset] (e.g. +/-500ms).
  ///
  /// Returns -1 if before the first line, otherwise index in [lines].
  static int findActiveIndex(
    List<LrcLine> lines,
    Duration currentPosition, {
    Duration offset = Duration.zero,
  }) {
    if (lines.isEmpty) return -1;

    final target = currentPosition + offset;
    if (target < lines.first.timestamp) {
      return -1;
    }

    int low = 0;
    int high = lines.length - 1;
    int result = 0;

    while (low <= high) {
      final mid = (low + high) ~/ 2;
      if (lines[mid].timestamp <= target) {
        result = mid; // Candidate line
        low = mid + 1; // Look for a later matching line
      } else {
        high = mid - 1;
      }
    }

    return result;
  }
}
