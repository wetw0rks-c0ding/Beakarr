import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seekarr/core/app_spacing.dart';
import 'package:seekarr/core/widgets/search_bar_header.dart';
import 'package:seekarr/features/navidrome/presentation/navidrome_providers.dart';

class NavidromeScreen extends ConsumerStatefulWidget {
  const NavidromeScreen({super.key});

  @override
  ConsumerState<NavidromeScreen> createState() => _NavidromeScreenState();
}

class _NavidromeScreenState extends ConsumerState<NavidromeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
        title: const Text('Navidrome'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Artists'),
            Tab(text: 'Albums'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ArtistsTab(search: _searchController.text),
          _AlbumsTab(search: _searchController.text),
        ],
      ),
    );
  }
}

class _ArtistsTab extends ConsumerWidget {
  final String search;
  const _ArtistsTab({required this.search});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(navidromeArtistsProvider);
    return Column(
      children: [
        SearchBarHeader(hintText: 'Artists...', onQueryChanged: (_) {}),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: async.when(
            data: (list) {
              final filtered = list
                  .where((a) => a.name.toLowerCase().contains(search.toLowerCase()))
                  .toList();
              if (filtered.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No artists found'),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final a = filtered[index];
                  return ListTile(
                    title: Text(a.name),
                    subtitle: Text(
                      '${a.albumCount} album${a.albumCount == 1 ? '' : 's'}',
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }
}

class _AlbumsTab extends ConsumerWidget {
  final String search;
  const _AlbumsTab({required this.search});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(navidromeAlbumsProvider);
    return async.when(
      data: (list) {
        final filtered = list
            .where((a) => a.name.toLowerCase().contains(search.toLowerCase()))
            .toList();
        if (filtered.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No albums found'),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final a = filtered[index];
            return ListTile(
              title: Text(a.name),
              subtitle: Text(a.artist ?? ''),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}