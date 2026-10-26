import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/audio/audio_service_provider.dart';
import '../../core/theme/app_theme.dart';
import '../download/download_providers.dart';
import '../home/home_providers.dart';
import '../navigation/widgets/track_tile.dart';
import 'library_providers.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final downloadedTracksAsync = ref.watch(downloadedTracksStreamProvider);
    final activeDownloadsAsync = ref.watch(activeDownloadsStreamProvider);
    final historyTracksAsync = ref.watch(recentlyPlayedStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Library'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryLight,
          labelColor: AppTheme.primaryLight,
          unselectedLabelColor: AppTheme.textMuted,
          tabs: const [
            Tab(text: 'Downloaded'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Downloaded Tab
          downloadedTracksAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
            data: (downloadedTracks) {
              final activeDownloads = activeDownloadsAsync.value ?? [];

              if (downloadedTracks.isEmpty && activeDownloads.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.cloud_download_outlined, size: 64, color: Colors.white24),
                      SizedBox(height: 16),
                      Text(
                        'No downloaded songs yet',
                        style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Tap the download icon on any track to listen offline',
                        style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                );
              }

              return ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // Active Downloads Section
                  if (activeDownloads.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text(
                        'Downloading (${activeDownloads.length})',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondaryColor,
                        ),
                      ),
                    ),
                    ...activeDownloads.map((d) {
                      return ListTile(
                        leading: const Icon(Icons.downloading_rounded, color: AppTheme.secondaryColor),
                        title: Text(
                          d.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: LinearProgressIndicator(
                          value: d.downloadProgress > 0 ? d.downloadProgress : null,
                          backgroundColor: Colors.white10,
                          color: AppTheme.secondaryColor,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.cancel_outlined, color: Colors.white54),
                          onPressed: () {
                            ref.read(downloadManagerProvider).cancelDownload(d.videoId);
                          },
                        ),
                      );
                    }),
                    const Divider(height: 24, color: Colors.white12),
                  ],

                  // Downloaded Songs Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${downloadedTracks.length} Offline Tracks',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        if (downloadedTracks.isNotEmpty)
                          FilledButton.tonalIcon(
                            onPressed: () {
                              ref
                                  .read(audioHandlerProvider)
                                  .playTrack(downloadedTracks.first, queue: downloadedTracks);
                            },
                            icon: const Icon(Icons.play_arrow_rounded, size: 18),
                            label: const Text('Play All'),
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Downloaded Songs List
                  ...downloadedTracks.map((track) {
                    return TrackTile(
                      track: track,
                      queue: downloadedTracks,
                    );
                  }),
                ],
              );
            },
          ),

          // 2. Play History Tab
          historyTracksAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
            data: (historyTracks) {
              if (historyTracks.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.history_rounded, size: 64, color: Colors.white24),
                      SizedBox(height: 16),
                      Text(
                        'Listening history is empty',
                        style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Songs you play will appear here',
                        style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: historyTracks.length,
                itemBuilder: (context, index) {
                  final track = historyTracks[index];
                  return TrackTile(
                    track: track,
                    queue: historyTracks,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
