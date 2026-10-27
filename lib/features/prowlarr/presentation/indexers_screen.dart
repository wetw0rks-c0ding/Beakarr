import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seekarr/core/app_spacing.dart';
import 'package:seekarr/core/widgets/search_bar_header.dart';
import 'package:seekarr/features/prowlarr/domain/models/prowlarr_indexer.dart';
import 'package:seekarr/features/prowlarr/presentation/widgets/indexer_card.dart';
import 'package:seekarr/features/services/presentation/services_provider.dart';

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
              setState(() {
                _searchController.text = query;
              });
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: asyncIndexers.when(
              data: (indexers) => _buildIndexersList(indexers),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error: $error')),
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
        child: Consumer(
          builder: (context, ref, _) {
            final asyncHistory = ref.watch(prowlarrHistoryProvider);
            return asyncHistory.when(
              data: (records) {
                if (records.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No history records',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: records.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final record = records[index];
                    return ListTile(
                      title: Text(record.eventType),
                      subtitle: Text(
                        '${record.indexerId} • ${record.date ?? ''}',
                      ),
                      trailing: Icon(
                        record.successful ? Icons.check : Icons.close,
                        color: record.successful ? Colors.green : Colors.red,
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
            );
          },
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
            _InfoRow(label: 'Protocol', value: indexer.protocol.isEmpty ? 'N/A' : indexer.protocol),
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


}
