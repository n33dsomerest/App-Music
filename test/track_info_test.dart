import 'package:flutter_test/flutter_test.dart';
import 'package:music_apl/core/sources/music_source.dart';

void main() {
  group('TrackInfo Tests', () {
    test('serializes and deserializes to MediaItem and JSON correctly', () {
      const track = TrackInfo(
        id: 'dQw4w9WgXcQ',
        title: 'Never Gonna Give You Up',
        artist: 'Rick Astley',
        duration: Duration(minutes: 3, seconds: 33),
        thumbnailUrl: 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
        tags: ['pop', '80s', 'classic'],
      );

      final mediaItem = track.toMediaItem();
      expect(mediaItem.id, track.id);
      expect(mediaItem.title, track.title);
      expect(mediaItem.artist, track.artist);
      expect(mediaItem.duration, track.duration);

      final restoredFromMedia = TrackInfo.fromMediaItem(mediaItem);
      expect(restoredFromMedia.id, track.id);
      expect(restoredFromMedia.title, track.title);
      expect(restoredFromMedia.artist, track.artist);

      final json = track.toJson();
      final restoredFromJson = TrackInfo.fromJson(json);
      expect(restoredFromJson.id, track.id);
      expect(restoredFromJson.title, track.title);
      expect(restoredFromJson.artist, track.artist);
      expect(restoredFromJson.duration, track.duration);
    });
  });
}
