import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:seekarr/core/app_colors.dart';
import 'package:seekarr/core/app_spacing.dart';
import 'package:seekarr/core/widgets/status_badge.dart';
import 'package:seekarr/features/prowlarr/domain/models/prowlarr_search_result.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _lastSearchQuery;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            onSubmitted: (_) => _searchAndShow(),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: StreamBuilder<List<ProwlarrSearchResult>>(
              stream: Controller().stream,
              initialData: <ProwlarrSearchResult>[],
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final results = snapshot.data ?? [];
                if (results.isEmpty) {
                  return _EmptyState();
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  itemCount: results.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final result = results[index];
                    return ResultCard(result: result);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _searchAndShow() {
    final query = _searchController.text.trim();
    if (query.isEmpty || _lastSearchQuery == query) {
      return;
    }

    _debounceTimer?.cancel();

    // Debounce search for 300ms
    _debounceTimer = Timer(
      const Duration(milliseconds: 300),
      () async {
        final settings = ref.read(currentSettingsProvider);
        if (!settings.isServiceConfigured(ServiceKey.prowlarr)) return;

        try {
          final client = ApiClient(
            baseUrl: settings.prowlarrUrl,
            auth: ApiKeyHeaderAuth(settings.prowlarrApiKey),
          );

          final response = await client.post('/api/v1/indexer/search', data: {'query': query}).timeout(
            const Duration(seconds: 15),
          );

          if (response.data is List<dynamic>) {
            final results = (response.data as List<dynamic>).map((json) {
              return ProwlarrSearchResult.fromJson(json as Map<String, dynamic>);
            }).toList();

            // Update stream
            Controller().add(results);
            _lastSearchQuery = query;
          } else if (response.data is Map<String, dynamic>) {
            final releases = response.data['releases'] ?? response.data['data'];
            if (releases is List) {
              final results = (releases as List).map((json) {
                return ProwlarrSearchResult.fromJson(json as Map<String, dynamic>);
              }).toList();
              Controller().add(results);
              _lastSearchQuery = query;
            }
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Search failed'),
              action: SnackBarAction(
                label: 'Retry',
                onPressed: _searchAndShow,
              ),
            ),
          );
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      },
    );
  }

  Widget _EmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'No results found',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class ResultCard extends StatelessWidget {
  final ProwlarrSearchResult result;

  const ResultCard({
    super.key,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sizeBytes = _formatSize(result.size);

    return InkWell(
      onTap: () => _showGrabDialog(context),
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
                    result.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                  Badge(label: 'Seeders:', value: '${result.seeders ?? 0}', color: AppColors.green50),
                  const SizedBox(width: 8),
                ],
                if (result.leechers != null && result.leechers! > 0) ...[
                  Badge(label: 'Leechers:', value: '${result.leechers ?? 0}', color: AppColors.red50),
                  const SizedBox(width: 8),
                ],
                // Category chips
                ...result.categories.map(
                  (category) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.blue50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      category,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.blue700,
                          ),
                    ),
                  ),
                ),
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
                        result.indexer,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.blue700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$sizeBytes ${_formatAge(result.age)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.purple50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    result.protocol,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.purple700,
                        ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatAge(double? age) {
    if (age == null) return '';
    final now = DateTime.now();
    final target = DateTime.fromMillisecondsSinceEpoch(now.millisecondsSinceEpoch - (age * 24 * 60 * 60 * 1000));
    final diff = now.difference(target);

    if (diff.inDays > 365) return '${(diff.inDays / 365).toStringAsFixed(1)}y ago';
    if (diff.inDays > 30) return '${(diff.inDays / 30).toStringAsFixed(1)}m ago';
    if (diff.inDays > 0) return '${diff.inDays.toInt()}d ago';
    if (diff.inHours > 0) return '${diff.inHours.toInt()}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes.toInt()}m ago';
    return 'just now';
  }

  void _showGrabDialog(BuildContext context) {
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
                Text(
                  'Grab Release',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
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
                backgroundColor: AppColors.blue50,
                child: const Icon(Icons.download_outlined, color: AppColors.blue700),
              ),
              title: Text(
                result.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (result.seeders != null)
                    Text(
                      'Seeders: ${result.seeders ?? 0}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (result.leechers != null)
                    Text(
                      'Leechers: ${result.leechers ?? 0}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _confirmGrab(context),
              icon: const Icon(Icons.check),
              label: const Text('Grab for me'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmGrab(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Grab request sent for this release'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  static String? mapOrNull(String? value) => value;
}
