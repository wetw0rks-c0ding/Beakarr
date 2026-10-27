import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seekarr/core/app_colors.dart';
import 'package:seekarr/core/app_spacing.dart';
import 'package:seekarr/core/widgets/status_badge.dart';
import 'package:seekarr/features/prowlarr/domain/models/prowlarr_indexer.dart';

class IndexersScreen extends ConsumerStatefulWidget {
  const IndexersScreen({super.key});

  @override
  ConsumerState<IndexersScreen> createState() => _IndexersScreenState();
}

class _IndexersScreenState extends ConsumerState<IndexersScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncIndexers = ref.watch(prowlarrIndexersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Indexers'),
        actions: [
          IconButton(
            onPressed: () => _showSearchHistoryBottomSheet(),
            icon: const Icon(Icons.history_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          SearchBarHeader(
            hintText: 'Search indexers...',
            onQueryChanged: (query) {
              _searchController.text = query;
            },
            onSubmitted: (_) {},
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: AsyncValueWidget<List<ProwlarrIndexer>>(
              value: asyncIndexers,
              data: (indexers) => _buildIndexersList(indexers),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error: $error')),
              empty: (_) => _EmptyState(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndexersList(List<ProwlarrIndexer> indexers) {
    final query = _searchController.text.toLowerCase();
    final filtered = indexers.where((i) =>
        i.name.toLowerCase().contains(query) ||
        i.implementationName.toLowerCase().contains(query)).toList();

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      itemCount: filtered.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final indexer = filtered[index];
        return IndexerCard(
          indexer: indexer,
          onTap: () => _showIndexerInfo(context, indexer),
        );
      },
    );
  }

  void _showSearchHistoryBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Search history placeholder',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }

  void _showIndexerInfo(BuildContext context, ProwlarrIndexer indexer) {
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
            Text(
              'Indexer Info',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _InfoRow(label: 'Name', value: indexer.name),
            const Divider(),
            _InfoRow(label: 'Protocol', value: indexer.protocol),
            const Divider(),
            _InfoRow(label: 'Enabled', value: indexer.enable ? 'Yes' : 'No'),
            const Divider(),
            _InfoRow(
              label: 'Capabilities',
              value: [
                if (indexer.supportsRss) 'RSS' else '',
                if (indexer.supportsSearch) 'Search',
              ]
                  .where((v) => v.isNotEmpty)
                  .join(', '),
            ),
          ],
        ),
      ),
    );
  }

  Widget _InfoRow({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _toggleIndexerEnabled(ProwlarrIndexer indexer) {
    // This would call the service API to toggle enable/disable
  }

  Widget _EmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_queue_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'No indexers loaded',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  static String? mapOrNull(String? value) => value;
}

class IndexerCard extends StatelessWidget {
  final ProwlarrIndexer indexer;
  final VoidCallback onTap;

  const IndexerCard({
    super.key,
    required this.indexer,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.blue100),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    indexer.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (indexer.message != null) ...[
                  const SizedBox(width: 8),
                  StatusBadge(message: indexer.message!),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.blue50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Protocol:', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(indexer.implementationName, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                const Spacer(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
