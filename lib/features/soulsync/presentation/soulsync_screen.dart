import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seekarr/core/app_spacing.dart';
import 'package:seekarr/features/settings/data/settings_provider.dart';
import 'package:seekarr/features/soulsync/data/soulsync_service.dart';
import 'package:seekarr/features/soulsync/domain/models/soulsync_discover_item.dart';
import 'package:seekarr/features/soulsync/presentation/soulsync_providers.dart';

class SoulSyncScreen extends ConsumerStatefulWidget {
  const SoulSyncScreen({super.key});

  @override
  ConsumerState<SoulSyncScreen> createState() => _SoulSyncScreenState();
}

class _SoulSyncScreenState extends ConsumerState<SoulSyncScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SoulSync'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Wishlist'),
            Tab(text: 'Downloads'),
            Tab(text: 'Discover'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _WishlistTab(),
          _DownloadsTab(),
          const _DiscoverTab(),
        ],
      ),
    );
  }
}

class _WishlistTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(soulsyncWishlistProvider);
    return async.when(
      data: (items) => items.isEmpty
          ? const Center(child: Text('No wishlist items'))
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                final detail = [
                  if (item.artist.isNotEmpty) item.artist,
                  if (item.album.isNotEmpty) item.album,
                  if (item.reason != null && item.reason!.isNotEmpty)
                    item.reason!,
                ].join(' · ');
                return ListTile(
                  title: Text(item.title.isEmpty ? 'Unknown item' : item.title),
                  subtitle: detail.isEmpty ? null : Text(detail),
                );
              },
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _DownloadsTab extends ConsumerStatefulWidget {
  const _DownloadsTab();

  @override
  ConsumerState<_DownloadsTab> createState() => _DownloadsTabState();
}

class _DownloadsTabState extends ConsumerState<_DownloadsTab> {
  final TextEditingController _controller = TextEditingController();
  bool _requesting = false;
  String? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(soulsyncDownloadsProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Artist - Track Name',
                  labelText: 'Request download',
                ),
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _request(),
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton.icon(
                onPressed: _requesting ? null : _request,
                icon: _requesting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded),
                label: Text(_requesting ? 'Requesting…' : 'Request'),
              ),
              if (_result != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(_result!),
              ],
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(soulsyncDownloadsProvider);
              await ref.read(soulsyncDownloadsProvider.future);
            },
            child: async.when(
            data: (items) => items.isEmpty
                ? const Center(child: Text('No downloads'))
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        title: Text(item.title),
                        subtitle: Text(
                          '${(item.progress * 100).round()}%',
                        ),
                      );
                    },
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
          ),
        ),
      ],
    );
  }

  Future<void> _request() async {
    final query = _controller.text.trim();
    if (query.isEmpty || _requesting) return;
    final settings = ref.read(currentSettingsProvider);
    if (settings.soulsyncProfileId.trim().isEmpty) {
      setState(() {
        _result = 'Select a profile in SoulSync settings first';
      });
      return;
    }
    setState(() {
      _requesting = true;
      _result = null;
    });
    try {
      final service = ref.read(soulsyncServiceProvider);
      final requestId = await service.requestDownload(query);
      if (!mounted) return;
      ref.invalidate(soulsyncDownloadsProvider);
      setState(() => _result = 'Requested (id: $requestId)');
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _result = 'Request failed — check connection and try again',
      );
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }
}

class _DiscoverTab extends ConsumerWidget {
  const _DiscoverTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final similarAsync = ref.watch(soulsyncSimilarArtistsProvider);
    final recentAsync = ref.watch(soulsyncRecentReleasesProvider);
    final bubblesAsync = ref.watch(soulsyncDiscoveryBubblesProvider);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const _PoolSection(),
        const SizedBox(height: AppSpacing.md),
        _DiscoverSection(title: 'Similar Artists', async: similarAsync),
        const SizedBox(height: AppSpacing.md),
        _DiscoverSection(title: 'Recent Releases', async: recentAsync),
        const SizedBox(height: AppSpacing.md),
        _DiscoverSection(title: 'Bubbles', async: bubblesAsync),
      ],
    );
  }
}

/// Discovery pool with user-driven pagination ("Load more").
class _PoolSection extends ConsumerStatefulWidget {
  const _PoolSection();

  @override
  ConsumerState<_PoolSection> createState() => _PoolSectionState();
}

class _PoolSectionState extends ConsumerState<_PoolSection> {
  int _page = 1;
  final List<SoulSyncDiscoverItem> _items = [];
  bool _hasNext = false;
  bool _loadingMore = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(soulsyncDiscoveryPoolPageProvider(_page));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Discovery Pool',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        async.when(
          data: (page) {
            for (final item in page.items) {
              if (!_items.any((e) => e.id == item.id)) _items.add(item);
            }
            _hasNext = page.hasNext;
            return Column(
              children: [
                ..._items.map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      item.title.isEmpty ? 'Unknown' : item.title,
                    ),
                    subtitle: item.subtitle.isEmpty
                        ? null
                        : Text(item.subtitle),
                  ),
                ),
                if (_hasNext)
                  TextButton(
                    onPressed: _loadingMore
                        ? null
                        : () async {
                            setState(() => _loadingMore = true);
                            setState(() => _page++);
                            // The new page provider resolves via watch;
                            // loading state clears on rebuild.
                            setState(() => _loadingMore = false);
                          },
                    child: Text(
                      _loadingMore ? 'Loading…' : 'Load more',
                    ),
                  ),
              ],
            );
          },
          loading: () => _items.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.sm),
                    child: CircularProgressIndicator(),
                  ),
                ),
          error: (e, _) => Text('Error: $e'),
        ),
      ],
    );
  }
}

class _DiscoverSection extends StatelessWidget {
  final String title;
  final AsyncValue<List<SoulSyncDiscoverItem>> async;

  const _DiscoverSection({required this.title, required this.async});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        async.when(
          data: (items) => items.isEmpty
              ? const Text('Nothing here yet')
              : Column(
                  children: items
                      .map(
                        (item) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            item.title.isEmpty ? 'Unknown' : item.title,
                          ),
                          subtitle: item.subtitle.isEmpty
                              ? null
                              : Text(item.subtitle),
                        ),
                      )
                      .toList(),
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
        ),
      ],
    );
  }
}
