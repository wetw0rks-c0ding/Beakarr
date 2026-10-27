import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seekarr/core/app_spacing.dart';
import 'package:seekarr/core/widgets/search_bar_header.dart';
import 'package:seekarr/features/bazarr/domain/models/bazarr_series.dart';
import 'package:seekarr/features/bazarr/domain/models/bazarr_movie.dart';
import 'package:seekarr/features/bazarr/domain/models/bazarr_wanted_entry.dart';
import 'package:seekarr/features/bazarr/domain/models/bazarr_provider.dart';
import 'package:seekarr/features/bazarr/presentation/bazarr_providers.dart';
import 'package:seekarr/features/bazarr/presentation/episode_sheet.dart';
import 'package:seekarr/features/bazarr/presentation/movie_sheet.dart';

class BazarrScreen extends ConsumerStatefulWidget {
  const BazarrScreen({super.key});

  @override
  ConsumerState<BazarrScreen> createState() => _BazarrScreenState();
}

class _BazarrScreenState extends ConsumerState<BazarrScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
        title: const Text('Bazarr'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Series'),
            Tab(text: 'Movies'),
            Tab(text: 'Wanted'),
            Tab(text: 'Providers'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _SeriesTab(search: _searchController.text, onSearch: (q) => setState(() => _searchController.text = q)),
          _MoviesTab(search: _searchController.text, onSearch: (q) => setState(() => _searchController.text = q)),
          _WantedTab(),
          _ProvidersTab(),
        ],
      ),
    );
  }
}

class _SeriesTab extends ConsumerWidget {
  final String search;
  final ValueChanged<String> onSearch;
  const _SeriesTab({required this.search, required this.onSearch});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bazarrSeriesProvider);
    return Column(children: [
      SearchBarHeader(hintText: 'Series...', onQueryChanged: onSearch),
      const SizedBox(height: AppSpacing.md),
      Expanded(child: async.when(
        data: (list) => _SeriesList(items: list, query: search.toLowerCase()),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      )),
    ]);
  }
}

class _SeriesList extends StatelessWidget {
  final List<BazarrSeries> items;
  final String query;
  const _SeriesList({required this.items, required this.query});

  @override
  Widget build(BuildContext context) {
    final filtered = items.where((s) => s.title.toLowerCase().contains(query) || (s.year > 0 ? '${s.year}' : '').contains(query)).toList();
    if (filtered.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No series found')));
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final s = filtered[index];
        return ListTile(
          title: Text(s.title),
          subtitle: Text('Year: ${s.year} • Seasons: ${s.seasonCount}'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            // Missing-subtitles badge approximation
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(12)), child: const Text('0 missing', style: TextStyle(fontSize: 11))),
            IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _openEpisodeSheet(context, s)),
          ]),
        );
      },
    );
  }

  void _openEpisodeSheet(BuildContext context, BazarrSeries series) {
    // For simplicity open episode sheet with first season/episode placeholder; real usage passes specific ep
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))), builder: (_) => EpisodeSheet(seriesId: series.id, season: 1, episode: 1, seriesTitle: series.title));
  }
}

class _MoviesTab extends ConsumerWidget {
  final String search;
  final ValueChanged<String> onSearch;
  const _MoviesTab({required this.search, required this.onSearch});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bazarrMoviesProvider);
    return Column(children: [
      SearchBarHeader(hintText: 'Movies...', onQueryChanged: onSearch),
      const SizedBox(height: AppSpacing.md),
      Expanded(child: async.when(
        data: (list) => _MoviesList(items: list, query: search.toLowerCase()),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      )),
    ]);
  }
}

class _MoviesList extends StatelessWidget {
  final List<BazarrMovie> items;
  final String query;
  const _MoviesList({required this.items, required this.query});

  @override
  Widget build(BuildContext context) {
    final filtered = items.where((m) => m.title.toLowerCase().contains(query) || (m.year > 0 ? '${m.year}' : '').contains(query)).toList();
    if (filtered.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No movies found')));
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final m = filtered[index];
        return ListTile(
          title: Text(m.title),
          subtitle: Text('Year: ${m.year}'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(12)), child: const Text('0 missing', style: TextStyle(fontSize: 11))),
            IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))), builder: (_) => MovieSheet(movieId: m.id, title: m.title))),
          ]),
        );
      },
    );
  }
}

class _WantedTab extends StatefulWidget {
  const _WantedTab();
  @override
  State<_WantedTab> createState() => _WantedTabState();
}

class _WantedTabState extends State<_WantedTab> with SingleTickerProviderStateMixin {
  late final TabController _ctrl;
  @override
  void initState() { super.initState(); _ctrl = TabController(length: 2, vsync: this); }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      TabBar(controller: _ctrl, tabs: const [Tab(text: 'Movies'), Tab(text: 'Episodes')]),
      Expanded(child: TabBarView(
        controller: _ctrl,
        children: [
          Consumer(builder: (c, ref, _) => ref.watch(bazarrWantedMoviesProvider).when(data: (l) => _WantedList(items: l, label: 'movie'), loading: () => const Center(child: CircularProgressIndicator()), error: (e,_) => Center(child: Text('Error: $e')))),
          Consumer(builder: (c, ref, _) => ref.watch(bazarrWantedEpisodesProvider).when(data: (l) => _WantedList(items: l, label: 'episode'), loading: () => const Center(child: CircularProgressIndicator()), error: (e,_) => Center(child: Text('Error: $e')))),
        ],
      )),
    ]);
  }
}

class _WantedList extends StatelessWidget {
  final List<BazarrWantedEntry> items;
  final String label;
  const _WantedList({required this.items, required this.label});
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No wanted items')));
    return ListView.separated(padding: const EdgeInsets.symmetric(vertical: AppSpacing.md), itemCount: items.length, separatorBuilder: (_, __) => const SizedBox(height: 8), itemBuilder: (context, i) {
      final w = items[i];
      return ListTile(title: Text(w.title ?? 'Unknown'), subtitle: Text('${w.type} • $label'), trailing: const Icon(Icons.download_rounded));
    });
  }
}

class _ProvidersTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bazarrProvidersProvider);
    return async.when(
      data: (list) => ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final p = list[index];
          return ListTile(
            leading: Container(width: 12, height: 12, decoration: BoxDecoration(color: p.enabled ? Colors.green : Colors.grey, shape: BoxShape.circle)),
            title: Text(p.name),
            subtitle: Text(p.enabled ? 'Enabled' : 'Disabled'),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}
