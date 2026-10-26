import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/audio/audio_service_provider.dart';
import '../../../core/sources/music_source.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../navigation/widgets/download_button.dart';

class NowPlayingTab extends ConsumerStatefulWidget {
  final TrackInfo track;

  const NowPlayingTab({
    super.key,
    required this.track,
  });

  @override
  ConsumerState<NowPlayingTab> createState() => _NowPlayingTabState();
}

class _NowPlayingTabState extends ConsumerState<NowPlayingTab> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final handler = ref.watch(audioHandlerProvider);
    final playbackState = ref.watch(playbackStateStreamProvider).value;
    final isPlaying = playbackState?.playing ?? false;
    final isBuffering = playbackState?.processingState == AudioProcessingState.buffering ||
        playbackState?.processingState == AudioProcessingState.loading;

    final positionData = ref.watch(positionDataProvider);
    final duration = positionData.duration > Duration.zero
        ? positionData.duration
        : widget.track.duration;

    final currentPosition = _dragValue != null
        ? Duration(milliseconds: _dragValue!.round())
        : positionData.position;

    final maxDurationMs = duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1.0;
    final currentPositionMs =
        currentPosition.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble();

    final repeatMode = playbackState?.repeatMode ?? AudioServiceRepeatMode.none;
    final shuffleMode = playbackState?.shuffleMode ?? AudioServiceShuffleMode.none;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          const SizedBox(height: 12),

          // Big Album Art
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 340, maxHeight: 340),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.2),
                    blurRadius: 32,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: CachedNetworkImage(
                    imageUrl: widget.track.thumbnailUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: AppTheme.darkSurfaceVariant,
                      child: const Center(
                        child: Icon(Icons.music_note, size: 64, color: Colors.white24),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: AppTheme.darkSurfaceVariant,
                      child: const Center(
                        child: Icon(Icons.music_note, size: 64, color: Colors.white24),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Title & Artist with Download Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossContent: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              DownloadButton(track: widget.track, size: 28),
            ],
          ),
          const SizedBox(height: 24),

          // Progress Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              min: 0.0,
              max: maxDurationMs,
              value: currentPositionMs.clamp(0.0, maxDurationMs),
              onChanged: (val) {
                setState(() {
                  _dragValue = val;
                });
              },
              onChangeEnd: (val) {
                handler.seek(Duration(milliseconds: val.round()));
                setState(() {
                  _dragValue = null;
                });
              },
            ),
          ),

          // Timestamps
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DurationFormatter.format(currentPosition),
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                Text(
                  DurationFormatter.format(duration),
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Playback Controls Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Shuffle
              IconButton(
                iconSize: 24,
                icon: Icon(
                  Icons.shuffle_rounded,
                  color: shuffleMode == AudioServiceShuffleMode.all
                      ? AppTheme.primaryLight
                      : AppTheme.textMuted,
                ),
                onPressed: () {
                  final nextMode = shuffleMode == AudioServiceShuffleMode.all
                      ? AudioServiceShuffleMode.none
                      : AudioServiceShuffleMode.all;
                  handler.setShuffleMode(nextMode);
                },
              ),

              // Skip Previous
              IconButton(
                iconSize: 38,
                icon: const Icon(Icons.skip_previous_rounded, color: AppTheme.textPrimary),
                onPressed: () => handler.skipToPrevious(),
              ),

              // Play / Pause / Buffering button
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryColor, Color(0xFF6366F1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: IconButton(
                  iconSize: 36,
                  icon: isBuffering
                      ? const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                        ),
                  onPressed: () {
                    if (isPlaying) {
                      handler.pause();
                    } else {
                      handler.play();
                    }
                  },
                ),
              ),

              // Skip Next
              IconButton(
                iconSize: 38,
                icon: const Icon(Icons.skip_next_rounded, color: AppTheme.textPrimary),
                onPressed: () => handler.skipToNext(),
              ),

              // Repeat
              IconButton(
                iconSize: 24,
                icon: Icon(
                  repeatMode == AudioServiceRepeatMode.one
                      ? Icons.repeat_one_rounded
                      : Icons.repeat_rounded,
                  color: repeatMode != AudioServiceRepeatMode.none
                      ? AppTheme.primaryLight
                      : AppTheme.textMuted,
                ),
                onPressed: () {
                  final nextMode = repeatMode == AudioServiceRepeatMode.none
                      ? AudioServiceRepeatMode.all
                      : (repeatMode == AudioServiceRepeatMode.all
                          ? AudioServiceRepeatMode.one
                          : AudioServiceRepeatMode.none);
                  handler.setRepeatMode(nextMode);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
