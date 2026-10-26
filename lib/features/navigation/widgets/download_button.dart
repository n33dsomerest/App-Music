import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/sources/music_source.dart';
import '../../../core/theme/app_theme.dart';
import '../../download/download_providers.dart';

class DownloadButton extends ConsumerWidget {
  final TrackInfo track;
  final double size;

  const DownloadButton({
    super.key,
    required this.track,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadState = ref.watch(trackDownloadStatusProvider(track.id)).value ??
        TrackDownloadState.idle();

    if (downloadState.isDownloading) {
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: downloadState.progress > 0 ? downloadState.progress : null,
              strokeWidth: 2.5,
              color: AppTheme.primaryLight,
            ),
            IconButton(
              padding: EdgeInsets.zero,
              iconSize: size * 0.6,
              icon: const Icon(Icons.close, color: Colors.white70),
              onPressed: () {
                ref.read(downloadManagerProvider).cancelDownload(track.id);
              },
            ),
          ],
        ),
      );
    }

    if (downloadState.isDownloaded) {
      return IconButton(
        iconSize: size,
        icon: const Icon(Icons.download_done_rounded, color: AppTheme.secondaryColor),
        tooltip: 'Downloaded',
        onPressed: () {
          _showDeleteDialog(context, ref);
        },
      );
    }

    if (downloadState.isFailed) {
      return IconButton(
        iconSize: size,
        icon: const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
        tooltip: 'Download failed. Tap to retry',
        onPressed: () {
          ref.read(downloadManagerProvider).enqueueDownload(track);
        },
      );
    }

    return IconButton(
      iconSize: size,
      icon: const Icon(Icons.download_rounded, color: AppTheme.textMuted),
      tooltip: 'Download offline',
      onPressed: () {
        ref.read(downloadManagerProvider).enqueueDownload(track);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloading "${track.title}"...'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Download'),
        content: Text('Remove "${track.title}" from offline downloads?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(downloadManagerProvider).deleteDownload(track.id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
