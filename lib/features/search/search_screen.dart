import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../navigation/widgets/track_tile.dart';
import 'search_providers.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSearchSubmitted(String query) {
    ref.read(searchQueryProvider.notifier).state = query.trim();
  }

  @override
  Widget build(BuildContext context) {
    final currentQuery = ref.watch(searchQueryProvider);
    final searchResultsAsync = ref.watch(searchResultsProvider);
    final suggestions = ref.watch(searchSuggestionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
      ),
      body: Column(
        children: [
          // Search Input Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: _onSearchSubmitted,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search songs, artists, or genres...',
                hintStyle: const TextStyle(color: AppTheme.textMuted),
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textMuted),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: AppTheme.textMuted),
                        onPressed: () {
                          _controller.clear();
                          ref.read(searchQueryProvider.notifier).state = '';
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.darkSurfaceVariant,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) {
                setState(() {});
              },
            ),
          ),

          // Suggestion Chips (when no search query entered)
          if (currentQuery.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: const [
                  Icon(Icons.trending_up_rounded, size: 18, color: AppTheme.primaryLight),
                  SizedBox(width: 8),
                  Text(
                    'Explore Trending Tags',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: suggestions.map((tag) {
                  return ActionChip(
                    label: Text(tag),
                    backgroundColor: AppTheme.darkSurfaceVariant,
                    labelStyle: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    onPressed: () {
                      _controller.text = tag;
                      _onSearchSubmitted(tag);
                    },
                  );
                }).toList(),
              ),
            ),
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search_rounded, size: 64, color: Colors.white12),
                    SizedBox(height: 12),
                    Text(
                      'Find your favorite music',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // Search Results List
            Expanded(
              child: searchResultsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryLight),
                ),
                error: (err, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.white24),
                      const SizedBox(height: 12),
                      Text(
                        'Failed to search: $err',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => ref.refresh(searchResultsProvider),
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
                data: (tracks) {
                  if (tracks.isEmpty) {
                    return const Center(
                      child: Text(
                        'No results found',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 16),
                      ),
                    );
                  }

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: tracks.length,
                    itemBuilder: (context, index) {
                      final track = tracks[index];
                      return TrackTile(
                        track: track,
                        queue: tracks,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
