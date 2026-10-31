import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seekarr/core/app_spacing.dart';
import 'package:seekarr/features/bazarr/domain/models/bazarr_subtitle.dart';

class SubtitlesSection extends ConsumerWidget {
  final List<BazarrSubtitle> subtitles;
  final bool isLoading;
  final String? error;
  final void Function(BazarrSubtitle sub)? onDownload;
  final void Function(BazarrSubtitle sub)? onDelete;
  final void Function()? onSearch;

  const SubtitlesSection({
    super.key,
    required this.subtitles,
    this.isLoading = false,
    this.error,
    this.onDownload,
    this.onDelete,
    this.onSearch,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: Text('Subtitles', style: Theme.of(context).textTheme.titleMedium)),
          if (onSearch != null) TextButton.icon(onPressed: onSearch, icon: const Icon(Icons.search, size: 18), label: const Text('Search')),
        ]),
        const SizedBox(height: AppSpacing.sm),
        if (isLoading) const Center(child: Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)))),
        if (error != null) Center(child: Text('Error: $error', style: TextStyle(color: Theme.of(context).colorScheme.error))),
        if (!isLoading && subtitles.isEmpty && error == null) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No subtitles')),
        ...subtitles.map((sub) => _SubtitleRow(sub: sub, onDownload: onDownload, onDelete: onDelete)),
      ],
    );
  }
}

class _SubtitleRow extends StatelessWidget {
  final BazarrSubtitle sub;
  final void Function(BazarrSubtitle)? onDownload;
  final void Function(BazarrSubtitle)? onDelete;
  const _SubtitleRow({required this.sub, this.onDownload, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        dense: true,
        title: Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(4)), child: Text((sub.code2).toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
          const SizedBox(width: 8),
          Expanded(child: Text(sub.name.isNotEmpty ? sub.name : '-', overflow: TextOverflow.ellipsis)),
        ]),
        subtitle: Wrap(spacing: 6, children: [
          if (sub.hi) Chip(label: const Text('HI', style: TextStyle(fontSize: 10)), padding: EdgeInsets.zero, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, visualDensity: VisualDensity.compact),
          if (sub.forced) Chip(label: const Text('Forced', style: TextStyle(fontSize: 10)), padding: EdgeInsets.zero, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, visualDensity: VisualDensity.compact),
        ]),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(icon: const Icon(Icons.download_rounded, size: 20), tooltip: 'Download', onPressed: onDownload != null ? () => onDownload!(sub) : null),
          IconButton(icon: const Icon(Icons.delete_rounded, size: 20, color: Colors.red), tooltip: 'Delete', onPressed: onDelete != null ? () => onDelete!(sub) : null),
        ]),
      ),
    );
  }
}
