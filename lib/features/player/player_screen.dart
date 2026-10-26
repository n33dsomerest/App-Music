import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/audio/audio_service_provider.dart';
import '../../core/sources/music_source.dart';
import '../../core/theme/app_theme.dart';
import 'tabs/lyrics_tab.dart';
import 'tabs/now_playing_tab.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen>
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
    final mediaItem = ref.watch(currentMediaItemStreamProvider).value;

    if (mediaItem == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(
          child: Text('No song currently playing'),
        ),
      );
    }

    final track = TrackInfo.fromMediaItem(mediaItem);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
          onPressed: () => context.pop(),
        ),
        title: Container(
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.darkSurfaceVariant,
            borderRadius: BorderRadius.circular(20),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: AppTheme.primaryColor,
            ),
            labelColor: Colors.white,
            unselectedLabelColor: AppTheme.textMuted,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: 'Now Playing'),
              Tab(text: 'Lyrics'),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.queue_music_rounded),
            tooltip: 'Queue',
            onPressed: () => _showQueueBottomSheet(context, ref),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          NowPlayingTab(track: track),
          LyricsTab(track: track),
        ],
      ),
    );
  }

  void _showQueueBottomSheet(BuildContext context, WidgetRef ref) {
    final handler = ref.read(audioHandlerProvider);
    final queue = handler.currentQueue;
    final current = handler.currentTrack;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Up Next',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        '${queue.length} songs',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Colors.white12),
                Expanded(
                  child: queue.isEmpty
                      ? const Center(child: Text('Queue is empty'))
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: queue.length,
                          itemBuilder: (context, index) {
                            final item = queue[index];
                            final isPlaying = item.id == current?.id;
                            return ListTile(
                              leading: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: isPlaying ? AppTheme.primaryLight : AppTheme.textMuted,
                                  fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              title: Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isPlaying ? AppTheme.primaryLight : AppTheme.textPrimary,
                                  fontWeight: isPlaying ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                item.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                              ),
                              trailing: isPlaying
                                  ? const Icon(Icons.volume_up_rounded, color: AppTheme.primaryLight)
                                  : null,
                              onTap: () {
                                Navigator.pop(ctx);
                                handler.playTrack(item, queue: queue);
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
