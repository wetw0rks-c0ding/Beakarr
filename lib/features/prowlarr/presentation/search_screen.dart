import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seekarr/core/app_spacing.dart';
import 'package:seekarr/core/widgets/search_bar_header.dart';
import 'package:seekarr/features/prowlarr/domain/models/prowlarr_search_result.dart';
import 'package:seekarr/features/services/presentation/services_provider.dart';
import 'package:seekarr/features/settings/data/settings_provider.dart';
import 'package:seekarr/features/settings/domain/service_key.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncResults = ref.watch(prowlarrSearchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        actions: [
          IconButton(
            onPressed: _searchAndShow,
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: Column(
        children: [
          SearchBarHeader(
            hintText: 'Search for movies, TV shows, comics...',
            onQueryChanged: (query) {
              _searchController.text = query;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: asyncResults.when(
              data: (results) => _buildResultsList(results),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList(List<ProwlarrSearchResult> results) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      itemCount: results.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final result = results[index];
        return ResultCard(result: result);
      },
    );
  }

  void _searchAndShow() {
    // Search is handled by provider
  }
}

class ResultCard extends StatelessWidget {
  final ProwlarrSearchResult result;

  const ResultCard({super.key, required this.result});

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatAge(dynamic age) {
    if (age == null) return '';
    final now = DateTime.now();
    final millisecondsSinceEpoch =
        now.millisecondsSinceEpoch - (((age as num?)?.toDouble() ?? 0) * 24 * 60 * 60 * 1000);
    final target = DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch.toInt());
    final diff = now.difference(target);

    if (diff.inDays > 365) return '${(diff.inDays / 365).toStringAsFixed(1)}y ago';
    if (diff.inDays > 30) return '${(diff.inDays / 30).toStringAsFixed(1)}m ago';
    if (diff.inDays > 0) return '${diff.inDays.toInt()}d ago';
    if (diff.inHours > 0) return '${diff.inHours.toInt()}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes.toInt()}m ago';
    return 'just now';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: () => _showGrabDialog(context, result),
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    result.title ?? '',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (result.seeders != null && result.seeders! > 0) ...[
                  _buildBadge('Seeders:', '${result.seeders ?? 0}', colorScheme.primaryContainer, theme),
                  const SizedBox(width: 8),
                ],
                if (result.leechers != null && result.leechers! > 0) ...[
                  _buildBadge('Leechers:', '${result.leechers ?? 0}', colorScheme.errorContainer, theme),
                  const SizedBox(width: 8),
                ],
                if (result.categories.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  ...result.categories.map((cat) => _buildChip(cat, theme)),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.indexer ?? '',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatSize(result.size)} ${_formatAge(result.age)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String label, String value, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Text(
        '$label$value',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onPrimary,
        ),
      ),
    );
  }

  Widget _buildChip(String category, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          category,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }

  void _showGrabDialog(BuildContext context, ProwlarrSearchResult result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    result.title ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel'),
                ),
              ],
            ),
            const Divider(height: 24),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: const Icon(Icons.download_outlined),
              ),
              title: Text(
                result.title ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (result.seeders != null)
                    Text('Seeders: ${result.seeders ?? 0}', style: Theme.of(context).textTheme.bodySmall),
                  if (result.leechers != null)
                    Text('Leechers: ${result.leechers ?? 0}', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _confirmGrab(context, result),
              icon: const Icon(Icons.check),
              label: const Text('Grab for me'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmGrab(BuildContext context, ProwlarrSearchResult result) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Grab request sent for this release'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
