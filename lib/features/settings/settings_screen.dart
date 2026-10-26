import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/audio/audio_service_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_logger.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _selectedFilter = 'ALL';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _copyAllLogs(BuildContext context) {
    final allLogs = AppLogger.exportAll();
    if (allLogs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No logs to copy')),
      );
      return;
    }
    Clipboard.setData(ClipboardData(text: allLogs));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All logs copied to clipboard!'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  void _copySingleLog(BuildContext context, LogEntry entry) {
    Clipboard.setData(ClipboardData(text: entry.format()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Log entry copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentMedia = ref.watch(currentMediaItemStreamProvider).value;
    final playbackState = ref.watch(playbackStateStreamProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_rounded),
            tooltip: 'Copy all logs',
            onPressed: () => _copyAllLogs(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear logs',
            onPressed: () {
              setState(() {
                AppLogger.clear();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logs cleared')),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<LogEntry>>(
        stream: AppLogger().stream,
        initialData: AppLogger().logs,
        builder: (context, snapshot) {
          final allLogs = snapshot.data ?? [];
          final filteredLogs = allLogs.reversed.where((entry) {
            // Level filter
            if (_selectedFilter == 'ERROR' && entry.level != LogLevel.error) {
              return false;
            }
            if (_selectedFilter == 'WARN' && entry.level != LogLevel.warning) {
              return false;
            }
            if (_selectedFilter == 'AUDIO' && !entry.tag.contains('Audio')) {
              return false;
            }
            if (_selectedFilter == 'SOURCE' && !entry.tag.contains('MusicSource')) {
              return false;
            }

            // Search query filter
            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              return entry.message.toLowerCase().contains(query) ||
                  entry.tag.toLowerCase().contains(query);
            }

            return true;
          }).toList();

          return Column(
            children: [
              // Diagnostics & System Summary Card
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.darkSurfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${AppConstants.appName} v${AppConstants.appVersion}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${allLogs.length} logs',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Player State: ${playbackState?.processingState.name ?? "idle"} • ${playbackState?.playing == true ? "Playing" : "Paused"}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                    if (currentMedia != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Active: ${currentMedia.title} - ${currentMedia.artist}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppTheme.secondaryColor),
                      ),
                    ],
                  ],
                ),
              ),

              // Search in Logs
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search log messages...',
                    hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                    prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.textMuted),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppTheme.darkSurfaceVariant.withOpacity(0.5),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim();
                    });
                  },
                ),
              ),

              // Filter Chips Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    _buildFilterChip('ALL', 'All'),
                    _buildFilterChip('ERROR', 'Errors only'),
                    _buildFilterChip('WARN', 'Warnings'),
                    _buildFilterChip('AUDIO', 'Audio Engine'),
                    _buildFilterChip('SOURCE', 'Music Source'),
                  ],
                ),
              ),

              const Divider(height: 1, color: Colors.white10),

              // Log Entries List
              Expanded(
                child: filteredLogs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.notes_rounded, size: 48, color: Colors.white24),
                            SizedBox(height: 12),
                            Text(
                              'No logs recorded yet',
                              style: TextStyle(color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        itemCount: filteredLogs.length,
                        itemBuilder: (context, index) {
                          final entry = filteredLogs[index];
                          return _buildLogCard(context, entry);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _selectedFilter == filterKey;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : AppTheme.textMuted,
        ),
        backgroundColor: AppTheme.darkSurfaceVariant,
        selectedColor: AppTheme.primaryColor,
        showCheckmark: false,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide.none,
        onSelected: (selected) {
          setState(() {
            _selectedFilter = filterKey;
          });
        },
      ),
    );
  }

  Widget _buildLogCard(BuildContext context, LogEntry entry) {
    Color levelColor;
    switch (entry.level) {
      case LogLevel.error:
        levelColor = const Color(0xFFEF4444);
        break;
      case LogLevel.warning:
        levelColor = const Color(0xFFF59E0B);
        break;
      case LogLevel.info:
        levelColor = const Color(0xFF06B6D4);
        break;
    }

    final time =
        '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}:${entry.timestamp.second.toString().padLeft(2, '0')}.${entry.timestamp.millisecond.toString().padLeft(3, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.darkSurfaceVariant.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: entry.level == LogLevel.error
              ? Colors.redAccent.withOpacity(0.3)
              : Colors.white.withOpacity(0.06),
        ),
      ),
      child: InkWell(
        onTap: () => _copySingleLog(context, entry),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Time + Level + Tag + Copy Icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: levelColor.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      entry.level.name.toUpperCase(),
                      style: TextStyle(
                        color: levelColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    entry.tag,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    time,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.copy_rounded, size: 14, color: AppTheme.textMuted),
                ],
              ),
              const SizedBox(height: 6),

              // Message
              SelectableText(
                entry.message,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                  fontFamily: 'monospace',
                ),
              ),

              // Stack trace / error details if present
              if (entry.error != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    'Error: ${entry.error}\n${entry.stackTrace ?? ""}'.trim(),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFFCA5A5),
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
