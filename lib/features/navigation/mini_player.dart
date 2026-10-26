import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/audio/audio_service_provider.dart';
import '../../core/theme/app_theme.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaItem = ref.watch(currentMediaItemStreamProvider).value;
    if (mediaItem == null) {
      return const SizedBox.shrink();
    }

    final playbackState = ref.watch(playbackStateStreamProvider).value;
    final isPlaying = playbackState?.playing ?? false;
    final isBuffering = playbackState?.processingState == AudioProcessingState.buffering ||
        playbackState?.processingState == AudioProcessingState.loading;

    final positionData = ref.watch(positionDataProvider);
    final duration = positionData.duration.inMilliseconds > 0
        ? positionData.duration.inMilliseconds
        : (mediaItem.duration?.inMilliseconds ?? 1);
    final position = positionData.position.inMilliseconds.clamp(0, duration);
    final progress = (position / duration).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Material(
        color: AppTheme.darkSurfaceVariant,
        borderRadius: BorderRadius.circular(16),
        elevation: 8,
        shadowColor: Colors.black54,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            context.push('/player');
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress line
              LinearProgressIndicator(
                value: progress,
                minHeight: 2.5,
                backgroundColor: Colors.white10,
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryLight),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    // Album art thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: mediaItem.artUri?.toString() ?? '',
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 44,
                          height: 44,
                          color: Colors.black26,
                          child: const Icon(Icons.music_note, color: Colors.white24, size: 20),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 44,
                          height: 44,
                          color: Colors.black26,
                          child: const Icon(Icons.music_note, color: Colors.white24, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Title & Artist
                    Expanded(
                      child: Column(
                        crossContent: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            mediaItem.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            mediaItem.artist ?? 'Unknown Artist',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Play/Pause button
                    IconButton(
                      iconSize: 28,
                      icon: isBuffering
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppTheme.primaryLight,
                              ),
                            )
                          : Icon(
                              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: AppTheme.textPrimary,
                            ),
                      onPressed: () {
                        final handler = ref.read(audioHandlerProvider);
                        if (isPlaying) {
                          handler.pause();
                        } else {
                          handler.play();
                        }
                      },
                    ),

                    // Next button
                    IconButton(
                      iconSize: 26,
                      icon: const Icon(Icons.skip_next_rounded, color: AppTheme.textPrimary),
                      onPressed: () {
                        ref.read(audioHandlerProvider).skipToNext();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
