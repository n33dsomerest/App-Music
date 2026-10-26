import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/audio/audio_service_provider.dart';
import '../../../core/sources/music_source.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/lrc_parser.dart';
import '../../lyrics/lyrics_providers.dart';

class LyricsTab extends ConsumerStatefulWidget {
  final TrackInfo track;

  const LyricsTab({
    super.key,
    required this.track,
  });

  @override
  ConsumerState<LyricsTab> createState() => _LyricsTabState();
}

class _LyricsTabState extends ConsumerState<LyricsTab> {
  final ScrollController _scrollController = ScrollController();

  int _currentActiveIndex = -1;
  bool _isUserScrolling = false;
  Timer? _resumeAutoScrollTimer;

  static const double _itemExtent = 56.0;

  @override
  void dispose() {
    _resumeAutoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onUserScrollNotification() {
    _isUserScrolling = true;
    _resumeAutoScrollTimer?.cancel();
    _resumeAutoScrollTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isUserScrolling = false;
        });
        _scrollToActiveIndex(_currentActiveIndex);
      }
    });
  }

  void _scrollToActiveIndex(int index) {
    if (!_scrollController.hasClients || index < 0 || _isUserScrolling) return;

    final viewportHeight = _scrollController.position.viewportDimension;
    final targetOffset = (index * _itemExtent) - (viewportHeight / 2) + (_itemExtent / 2);
    final clampedOffset = targetOffset.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lyricsAsync = ref.watch(lyricsNotifierProvider);
    final positionData = ref.watch(positionDataProvider);

    return lyricsAsync.when(
      loading: () => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryLight),
            SizedBox(height: 16),
            Text(
              'Fetching synchronized lyrics...',
              style: TextStyle(color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
      error: (err, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.music_off_rounded, size: 48, color: Colors.white24),
            const SizedBox(height: 12),
            const Text(
              'Could not load lyrics',
              style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                ref
                    .read(lyricsNotifierProvider.notifier)
                    .loadLyricsForTrack(widget.track, forceRefresh: true);
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (lyrics) {
        if (lyrics == null || lyrics.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lyrics_outlined, size: 54, color: Colors.white24),
                const SizedBox(height: 12),
                const Text(
                  'No lyrics found for this track',
                  style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Enjoy the music!',
                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    ref
                        .read(lyricsNotifierProvider.notifier)
                        .loadLyricsForTrack(widget.track, forceRefresh: true);
                  },
                  icon: const Icon(Icons.search_rounded, size: 16),
                  label: const Text('Search again'),
                ),
              ],
            ),
          );
        }

        // 1. Plain text fallback if no synced lyrics available
        if (!lyrics.isSynced && lyrics.plainLyrics != null) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Plain Lyrics',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ),
                const SizedBox(height: 16),
                SelectableText(
                  lyrics.plainLyrics!,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.8,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 60),
              ],
            ),
          );
        }

        // 2. Synchronized LRC Lyrics
        final lines = lyrics.parsedSyncedLyrics;
        final offset = Duration(milliseconds: lyrics.offsetMs);
        final activeIndex = LrcParser.findActiveIndex(
          lines,
          positionData.position,
          offset: offset,
        );

        if (activeIndex != _currentActiveIndex && activeIndex >= 0) {
          _currentActiveIndex = activeIndex;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToActiveIndex(activeIndex);
          });
        }

        return Column(
          children: [
            // Offset Adjustment Header Bar (+/- 0.5s)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: AppTheme.darkSurfaceVariant.withOpacity(0.4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 20,
                    tooltip: 'Lyrics 0.5s Earlier',
                    icon: const Icon(Icons.remove_circle_outline, color: AppTheme.textMuted),
                    onPressed: () {
                      ref.read(lyricsNotifierProvider.notifier).adjustOffset(-500);
                    },
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Offset: ${(lyrics.offsetMs / 1000.0).toStringAsFixed(1)}s',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    iconSize: 20,
                    tooltip: 'Lyrics 0.5s Later',
                    icon: const Icon(Icons.add_circle_outline, color: AppTheme.textMuted),
                    onPressed: () {
                      ref.read(lyricsNotifierProvider.notifier).adjustOffset(500);
                    },
                  ),
                  if (lyrics.offsetMs != 0) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () {
                        ref
                            .read(lyricsNotifierProvider.notifier)
                            .adjustOffset(-lyrics.offsetMs);
                      },
                      child: const Text('Reset', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ],
              ),
            ),

            // Synced Lyric Lines List
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is UserScrollNotification) {
                    _onUserScrollNotification();
                  }
                  return false;
                },
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 120),
                  itemCount: lines.length,
                  itemExtent: _itemExtent,
                  itemBuilder: (context, index) {
                    final line = lines[index];
                    final isActive = index == _currentActiveIndex;

                    return InkWell(
                      onTap: () {
                        // Tap line to seek audio to that exact moment
                        final targetSeek = line.timestamp - offset;
                        final seekPos = targetSeek.isNegative ? Duration.zero : targetSeek;
                        ref.read(audioHandlerProvider).seek(seekPos);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 250),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isActive ? 21 : 16,
                            fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                            color: isActive
                                ? AppTheme.primaryLight
                                : AppTheme.textMuted.withOpacity(0.65),
                            height: 1.3,
                          ),
                          child: Text(
                            line.text.isEmpty ? '♪' : line.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
