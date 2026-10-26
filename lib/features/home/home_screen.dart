import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/audio/audio_service_provider.dart';
import '../../core/sources/music_source.dart';
import '../../core/theme/app_theme.dart';
import '../navigation/widgets/download_button.dart';
import 'home_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeDataAsync = ref.watch(homeDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.graphic_eq_rounded, color: AppTheme.primaryLight, size: 22),
            ),
            const SizedBox(width: 10),
            const Text('MusicApl'),
          ],
        ),
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryLight,
        backgroundColor: AppTheme.darkSurfaceVariant,
        onRefresh: () async {
          ref.refresh(homeDataProvider);
        },
        child: homeDataAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryLight),
          ),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to load suggestions: $err',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.refresh(homeDataProvider),
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          ),
          data: (homeData) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                // Recently Played Section (if user has history)
                if (homeData.recentlyPlayed.isNotEmpty) ...[
                  _buildSectionHeader(
                    context: context,
                    title: 'Recently Played',
                    subtitle: 'Jump back into your favorites',
                    onPlayAll: () {
                      ref.read(audioHandlerProvider).playTrack(
                            homeData.recentlyPlayed.first,
                            queue: homeData.recentlyPlayed,
                          );
                    },
                  ),
                  SizedBox(
                    height: 190,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: homeData.recentlyPlayed.length,
                      itemBuilder: (context, index) {
                        final track = homeData.recentlyPlayed[index];
                        return _buildHorizontalTrackCard(context, ref, track, homeData.recentlyPlayed);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Dynamic Sections ("Because you listened to <Artist>", "More like <Genre>", etc.)
                ...homeData.sections.map((section) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        context: context,
                        title: section.title,
                        subtitle: section.subtitle,
                        onPlayAll: section.tracks.isNotEmpty
                            ? () {
                                ref.read(audioHandlerProvider).playTrack(
                                      section.tracks.first,
                                      queue: section.tracks,
                                    );
                              }
                            : null,
                      ),
                      SizedBox(
                        height: 190,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: section.tracks.length,
                          itemBuilder: (context, index) {
                            final track = section.tracks[index];
                            return _buildHorizontalTrackCard(context, ref, track, section.tracks);
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required BuildContext context,
    required String title,
    String? subtitle,
    VoidCallback? onPlayAll,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onPlayAll != null)
            IconButton(
              iconSize: 22,
              icon: const Icon(Icons.play_circle_fill_rounded, color: AppTheme.primaryLight),
              tooltip: 'Play section',
              onPressed: onPlayAll,
            ),
        ],
      ),
    );
  }

  Widget _buildHorizontalTrackCard(
    BuildContext context,
    WidgetRef ref,
    TrackInfo track,
    List<TrackInfo> queue,
  ) {
    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 14),
      child: InkWell(
        onTap: () {
          ref.read(audioHandlerProvider).playTrack(track, queue: queue);
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Artwork with download badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: CachedNetworkImage(
                      imageUrl: track.thumbnailUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: AppTheme.darkSurfaceVariant,
                        child: const Icon(Icons.music_note, color: Colors.white24),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: AppTheme.darkSurfaceVariant,
                        child: const Icon(Icons.music_note, color: Colors.white24),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      shape: BoxShape.circle,
                    ),
                    child: DownloadButton(track: track, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Title
            Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),

            // Artist
            Text(
              track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
