import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../utils/app_logger.dart';

/// A [StreamAudioSource] that buffers and streams audio directly from a Dart byte stream
/// (such as YouTubeExplode's native streamClient) through just_audio's internal loopback proxy.
///
/// This avoids HTTP 403 Forbidden errors because the connection to Google Video CDN
/// is managed internally by the Dart HTTP client with appropriate headers, while the
/// platform player (ExoPlayer / AVPlayer) reads from a local cleartext connection.
///
/// Concurrently, it caches the stream to a local file so future playbacks of the same
/// track do not require network re-fetching.
class YoutubeStreamAudioSource extends StreamAudioSource {
  final Future<Stream<List<int>>> Function() _streamSupplier;
  final int? _sourceLength;
  final String _contentType;
  final File? _cacheFile;

  // In-memory buffer of bytes received so far
  final List<int> _buffer = [];
  bool _downloadStarted = false;
  bool _downloadFinished = false;

  // StreamController used to broadcast incoming chunks to active range readers
  final StreamController<List<int>> _chunkBroadcaster = StreamController<List<int>>.broadcast();
  IOSink? _cacheSink;

  YoutubeStreamAudioSource({
    required Future<Stream<List<int>>> Function() streamSupplier,
    int? sourceLength,
    String contentType = 'audio/mp4',
    File? cacheFile,
    MediaItem? tag,
  })  : _streamSupplier = streamSupplier,
        _sourceLength = sourceLength,
        _contentType = contentType,
        _cacheFile = cacheFile,
        super(tag: tag);

  void _ensureDownloadStarted() {
    if (_downloadStarted) return;
    _downloadStarted = true;

    // Open file sink for persistent local caching
    if (_cacheFile != null) {
      try {
        if (!_cacheFile!.parent.existsSync()) {
          _cacheFile!.parent.createSync(recursive: true);
        }
        _cacheSink = _cacheFile!.openWrite();
      } catch (e) {
        AppLogger.warn('StreamSource', 'Failed to initialize cache file: $e');
      }
    }

    _streamSupplier().then((stream) {
      stream.listen(
        (chunk) {
          _buffer.addAll(chunk);
          try {
            _cacheSink?.add(chunk);
          } catch (_) {}
          _chunkBroadcaster.add(chunk);
        },
        onDone: () async {
          _downloadFinished = true;
          try {
            await _cacheSink?.flush();
            await _cacheSink?.close();
            _cacheSink = null;
          } catch (_) {}
          await _chunkBroadcaster.close();
          AppLogger.info('StreamSource', 'Stream buffering finished (${_buffer.length} bytes cached)');
        },
        onError: (err, st) {
          AppLogger.error('StreamSource', 'Error reading incoming audio stream', err, st);
          _chunkBroadcaster.addError(err, st);
        },
        cancelOnError: true,
      );
    }).catchError((err, st) {
      AppLogger.error('StreamSource', 'Failed to initialize audio stream supplier', err, st);
      _chunkBroadcaster.addError(err, st);
    });
  }

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    _ensureDownloadStarted();

    final effectiveStart = start ?? 0;
    final total = _sourceLength;
    final effectiveEnd = end ?? total;
    final contentLength = (effectiveEnd != null && effectiveEnd > effectiveStart)
        ? (effectiveEnd - effectiveStart)
        : (total != null ? (total - effectiveStart) : null);

    return StreamAudioResponse(
      sourceLength: total,
      contentLength: contentLength,
      offset: effectiveStart,
      stream: _createRangeStream(effectiveStart, effectiveEnd),
      contentType: _contentType,
    );
  }

  Stream<List<int>> _createRangeStream(int start, int? end) async* {
    var currentOffset = 0;

    // 1. Yield data that has already arrived in _buffer
    if (_buffer.isNotEmpty && start < _buffer.length) {
      final sliceEnd = (end != null && end < _buffer.length) ? end : _buffer.length;
      final initialSlice = _buffer.sublist(start, sliceEnd);
      yield initialSlice;
      currentOffset = sliceEnd;
      if (end != null && currentOffset >= end) {
        return;
      }
    } else {
      currentOffset = start;
    }

    // 2. If the stream already finished downloading, we are done
    if (_downloadFinished) {
      return;
    }

    // 3. Listen for future incoming chunks from broadcaster
    await for (final chunk in _chunkBroadcaster.stream) {
      final chunkStart = _buffer.length - chunk.length;
      final chunkEnd = _buffer.length;

      if (chunkEnd <= currentOffset) {
        continue;
      }

      final sliceStart = (currentOffset > chunkStart) ? (currentOffset - chunkStart) : 0;
      final sliceEnd = (end != null && chunkStart + chunk.length > end)
          ? (end - chunkStart)
          : chunk.length;

      if (sliceStart < sliceEnd && sliceStart < chunk.length) {
        final sub = chunk.sublist(sliceStart, sliceEnd.clamp(0, chunk.length));
        yield sub;
        currentOffset += sub.length;
        if (end != null && currentOffset >= end) {
          break;
        }
      }
    }
  }
}
