import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seekarr/core/app_spacing.dart';
import 'package:seekarr/features/settings/data/settings_provider.dart';
import 'package:seekarr/features/soulsync/data/soulsync_service.dart';
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

class _DiscoverTab extends ConsumerStatefulWidget {
  const _DiscoverTab();

  @override
  ConsumerState<_DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends ConsumerState<_DiscoverTab> {
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
    return Padding(
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
      setState(() => _result = 'Requested (id: $requestId)');
    } catch (_) {
      if (!mounted) return;
      setState(() => _result = 'Request failed — check connection and try again');
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }
}
