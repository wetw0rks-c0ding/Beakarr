import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seekarr/core/app_spacing.dart';
import 'package:seekarr/features/bazarr/data/bazarr_service.dart';
import 'package:seekarr/features/bazarr/domain/models/bazarr_subtitle.dart';
import 'package:seekarr/features/bazarr/presentation/bazarr_providers.dart';
import 'package:seekarr/features/bazarr/presentation/subtitles_section.dart';

class MovieSheet extends ConsumerStatefulWidget {
  final int movieId;
  final String title;
  const MovieSheet({super.key, required this.movieId, required this.title});

  @override
  ConsumerState<MovieSheet> createState() => _MovieSheetState();
}

class _MovieSheetState extends ConsumerState<MovieSheet> {
  bool _searching = false;
  List<BazarrSubtitle> _searchResults = [];

  @override
  Widget build(BuildContext context) {
    final subsAsync = ref.watch(bazarrMovieSubtitlesProvider(widget.movieId));
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          Text('Subtitles — ${widget.title}', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          SubtitlesSection(
            subtitles: subsAsync.asData?.value ?? [],
            isLoading: subsAsync.isLoading,
            error: subsAsync.hasError ? subsAsync.error.toString() : null,
            onDownload: (sub) => _download(sub),
            onDelete: (sub) => _delete(sub),
            onSearch: () => _triggerSearch(),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_searching) const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2))),
          if (!_searching && _searchResults.isNotEmpty) ...[
            Text('Search Results', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            ..._searchResults.map((r) => ListTile(
              dense: true,
              title: Text('${r.language.toUpperCase()} — ${r.provider}'),
              subtitle: Text('HI: ${r.hearingImpaired} • Forced: ${r.forced}'),
              trailing: IconButton(icon: const Icon(Icons.download_rounded, size: 20), tooltip: 'Download', onPressed: () => _downloadResult(r)),
            )),
          ],
          const SizedBox(height: AppSpacing.lg),
          TextButton.icon(onPressed: () => _triggerSearch(), icon: const Icon(Icons.search), label: const Text('Manual search subtitles')),
        ],
      ),
    );
  }

  void _download(BazarrSubtitle sub) async {
    try { await ref.read(bazarrServiceProvider).downloadMovieSubtitle(movieId: widget.movieId, language: sub.language, provider: sub.provider); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subtitle downloaded'))); } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: $e'))); }
  }

  void _delete(BazarrSubtitle sub) async {
    try { await ref.read(bazarrServiceProvider).deleteMovieSubtitle(movieId: widget.movieId, language: sub.language, provider: sub.provider); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subtitle deleted'))); } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e'))); }
  }

  void _triggerSearch() async {
    setState(() { _searching = true; _searchResults = []; });
    try {
      final res = await ref.read(bazarrServiceProvider).searchMovieSubtitles(movieId: widget.movieId);
      setState(() { _searchResults = res; _searching = false; });
    } catch (e) { setState(() => _searching = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Search failed: $e'))); }
  }

  void _downloadResult(BazarrSubtitle r) async {
    try { await ref.read(bazarrServiceProvider).downloadMovieSubtitle(movieId: widget.movieId, language: r.language, provider: r.provider); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subtitle downloaded'))); setState(() => _searchResults.removeWhere((x) => x.language == r.language && x.provider == r.provider)); } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: $e'))); }
  }
}
