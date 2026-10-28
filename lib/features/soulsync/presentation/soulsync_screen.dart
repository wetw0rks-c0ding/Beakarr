import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seekarr/core/app_spacing.dart';
import 'package:seekarr/features/soulsync/presentation/soulsync_providers.dart';

class SoulSyncScreen extends ConsumerStatefulWidget {
  const SoulSyncScreen({super.key});

  @override
  ConsumerState<SoulSyncScreen> createState() => _SoulSyncScreenState();
}

class _SoulSyncScreenState extends ConsumerState<SoulSyncScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
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
          _DiscoverTab(controller: _searchController),
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
                return ListTile(
                  title: Text(item.title),
                  subtitle: Text(item.reason ?? item.status),
                );
              },
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _DownloadsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(soulsyncDownloadsProvider);
    return async.when(
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
                  subtitle: Text('${(item.progress * 100).round()}%'),
                );
              },
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _DiscoverTab extends ConsumerWidget {
  final TextEditingController controller;
  const _DiscoverTab({required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Search...'),
            onSubmitted: (q) =>
                ref.read(soulsyncDiscoverQueryProvider.notifier).state = q,
          ),
        ),
        Expanded(
          child: ref.watch(soulsyncDiscoverResultsProvider).when(
                data: (items) => items.isEmpty
                    ? const Center(child: Text('No results'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) =>
                            ListTile(title: Text(items[index].title)),
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
        ),
      ],
    );
  }
}
