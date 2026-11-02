import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:seekarr/core/app_spacing.dart';
import 'package:seekarr/core/widgets/floating_bottom_nav_bar.dart';
import 'package:seekarr/core/widgets/search_bar_header.dart';
import 'package:seekarr/features/navidrome/presentation/navidrome_providers.dart';
import 'package:seekarr/features/navidrome/presentation/widgets/navidrome_cover.dart';

class NavidromeScreen extends ConsumerStatefulWidget {
  const NavidromeScreen({super.key});

  @override
  ConsumerState<NavidromeScreen> createState() => _NavidromeScreenState();
}

class _NavidromeScreenState extends ConsumerState<NavidromeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      body: Column(
        children: [
          SearchBarHeader(
            hintText: 'Search...',
            onQueryChanged: (q) => setState(() => _search = q),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ArtistsTab(search: _search),
                _AlbumsTab(search: _search),
              ],
            ),
          ),
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
    return async.when(
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
          padding: EdgeInsets.only(
                top: AppSpacing.md,
                bottom: AppSpacing.md + FloatingNavBarMetrics.getScrollViewBottomPadding(context),
              ),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final a = filtered[index];
            return ListTile(
              leading: NavidromeCover(coverArtId: a.coverArt),
              title: Text(a.name),
              subtitle: Text(
                '${a.albumCount} album${a.albumCount == 1 ? '' : 's'}',
              ),
              onTap: () => context.push(
                '/services/navidrome/artist/${a.id}?name=${Uri.encodeComponent(a.name)}',
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
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
          padding: EdgeInsets.only(
                top: AppSpacing.md,
                bottom: AppSpacing.md + FloatingNavBarMetrics.getScrollViewBottomPadding(context),
              ),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final a = filtered[index];
            return ListTile(
              leading: NavidromeCover(coverArtId: a.coverArt),
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
