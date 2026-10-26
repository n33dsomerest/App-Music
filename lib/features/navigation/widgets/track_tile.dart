import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/audio/audio_service_provider.dart';
import '../../../core/sources/music_source.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/duration_formatter.dart';
import 'download_button.dart';

class TrackTile extends ConsumerWidget {
  final TrackInfo track;
  final List<TrackInfo>? queue;
  final VoidCallback? onTap;

  const TrackTile({
    super.key,
    required this.track,
    this.queue,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMedia = ref.watch(currentMediaItemStreamProvider).value;
    final isCurrentTrack = currentMedia?.id == track.id;
    final playbackState = ref.watch(playbackStateStreamProvider).value;
    final isPlaying = isCurrentTrack && (playbackState?.playing ?? false);

    return InkWell(
      onTap: onTap ??
          () {
            ref.read(audioHandlerProvider).playTrack(track, queue: queue);
          },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Thumbnail with playing overlay
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CachedNetworkImage(
                    imageUrl: track.thumbnailUrl,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 52,
                      height: 52,
                      color: AppTheme.darkSurfaceVariant,
                      child: const Icon(Icons.music_note, color: Colors.white24),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 52,
                      height: 52,
                      color: AppTheme.darkSurfaceVariant,
                      child: const Icon(Icons.music_note, color: Colors.white24),
                    ),
                  ),
                  if (isCurrentTrack)
                    Container(
                      width: 52,
                      height: 52,
                      color: Colors.black45,
                      child: Icon(
                        isPlaying ? Icons.equalizer_rounded : Icons.pause_rounded,
                        color: AppTheme.primaryLight,
                        size: 26,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Track metadata
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrentTrack ? AppTheme.primaryLight : AppTheme.textPrimary,
                      fontWeight: isCurrentTrack ? FontWeight.bold : FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (track.duration > Duration.zero) ...[
                        const Text(
                          ' • ',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        ),
                        Text(
                          DurationFormatter.format(track.duration),
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Download button
            DownloadButton(track: track, size: 22),
          ],
        ),
      ),
    );
  }
}
