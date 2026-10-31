import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seekarr/core/app_spacing.dart';
import 'package:seekarr/core/widgets/floating_bottom_nav_bar.dart';
import 'package:seekarr/core/widgets/async_value_widget.dart';
import 'package:seekarr/features/nzbget/domain/models/nzbget_history_item.dart';
import 'package:seekarr/features/nzbget/domain/models/nzbget_queue_item.dart';
import 'package:seekarr/features/nzbget/presentation/nzbget_actions.dart';
import 'package:seekarr/features/nzbget/presentation/nzbget_provider.dart';
import 'package:seekarr/features/nzbget/presentation/widgets/nzbget_history_tile.dart';
import 'package:seekarr/features/nzbget/presentation/widgets/nzbget_queue_tile.dart';
import 'package:seekarr/features/nzbget/presentation/widgets/nzbget_selection_bar.dart';
import 'package:seekarr/features/nzbget/presentation/widgets/nzbget_status_bar.dart';

const int _queueTab = 0;
const int _historyTab = 1;

class NzbgetScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  final double topPadding;

  const NzbgetScreen({super.key, this.showAppBar = true, this.topPadding = 0});

  @override
  ConsumerState<NzbgetScreen> createState() => _NzbgetScreenState();
}

class _NzbgetScreenState extends ConsumerState<NzbgetScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Stop the 5 s poll while the app is backgrounded: NZBGet should not see
    // requests the user cannot act on.
    final enabled = state == AppLifecycleState.resumed;
    if (ref.read(nzbgetPollingEnabledProvider) != enabled) {
      ref.read(nzbgetPollingEnabledProvider.notifier).state = enabled;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(nzbgetPollingProvider);
    final statusAsync = ref.watch(nzbgetStatusProvider);
    final queueAsync = ref.watch(nzbgetQueueProvider);
    final tab = ref.watch(nzbgetTabProvider);

    final queue = queueAsync.asData?.value ?? const <NzbgetQueueItem>[];

    return Scaffold(
      body: Column(
        children: [
          if (widget.topPadding > 0) SizedBox(height: widget.topPadding),
          NzbgetStatusBar(
            status: statusAsync.asData?.value,
            queueCount: queue.length,
            activeCount: queue
                .where((item) => item.status == 'DOWNLOADING')
                .length,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: _queueTab,
                  label: Text('Queue'),
                  icon: Icon(Icons.download_rounded, size: 16),
                ),
                ButtonSegment(
                  value: _historyTab,
                  label: Text('History'),
                  icon: Icon(Icons.history_rounded, size: 16),
                ),
              ],
              selected: {tab},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                final next = selection.first;
                if (next == tab) return;
                ref.read(nzbgetTabProvider.notifier).state = next;
                ref.read(nzbgetSelectionProvider.notifier).state = {};
              },
            ),
          ),
          Expanded(
            child: tab == _historyTab ? const _HistoryTab() : const _QueueTab(),
          ),
          if (tab == _queueTab) const NzbgetSelectionBar(),
        ],
      ),
    );
  }
}

class _QueueTab extends ConsumerWidget {
  const _QueueTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(nzbgetQueueProvider);
    final selected = ref.watch(nzbgetSelectionProvider);

    return AsyncValueWidget<List<NzbgetQueueItem>>(
      value: queueAsync,
      serviceName: 'NZBGet',
      data: (items) {
        if (items.isEmpty) {
          return const _EmptyState(
            icon: Icons.cloud_done_outlined,
            label: 'Queue is empty',
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(nzbgetStatusProvider);
            ref.invalidate(nzbgetQueueProvider);
          },
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              top: 4,
              bottom: FloatingNavBarMetrics.getScrollViewBottomPadding(context),
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return NzbgetQueueTile(
                item: item,
                selected: selected.contains(item.id),
                onTap: () => _toggleSelection(ref, item.id),
                onLongPress: () => _toggleSelection(ref, item.id),
                onTogglePause: () => runNzbgetAction(
                  context,
                  ref,
                  action: (service) => item.isPaused
                      ? service.resumeItems([item.id])
                      : service.pauseItems([item.id]),
                  successMessage: item.isPaused ? 'Resumed' : 'Paused',
                  failureMessage: 'Failed to update item',
                  invalidate: [nzbgetStatusProvider, nzbgetQueueProvider],
                ),
                onDelete: () =>
                    confirmDeleteNzbgetQueueItems(context, ref, {item.id}),
              );
            },
          ),
        );
      },
    );
  }

  void _toggleSelection(WidgetRef ref, int id) {
    final notifier = ref.read(nzbgetSelectionProvider.notifier);
    final current = Set<int>.from(notifier.state);
    if (!current.remove(id)) current.add(id);
    notifier.state = current;
  }
}

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  static const _filters = <String?, String>{
    null: 'All',
    'SUCCESS': 'Success',
    'WARNING': 'Warning',
    'FAILURE': 'Failure',
    'DELETED': 'Deleted',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(nzbgetHistoryProvider);
    final filter = ref.watch(nzbgetHistoryFilterProvider);

    return Column(
      children: [
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            children: [
              for (final entry in _filters.entries)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: FilterChip(
                    label: Text(entry.value),
                    selected: filter == entry.key,
                    onSelected: (_) {
                      ref.read(nzbgetHistoryFilterProvider.notifier).state =
                          entry.key;
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: AsyncValueWidget<List<NzbgetHistoryItem>>(
            value: historyAsync,
            serviceName: 'NZBGet',
            data: (items) {
              final visible = items
                  .where((item) => item.matchesFilter(filter))
                  .toList(growable: false);
              if (visible.isEmpty) {
                return const _EmptyState(
                  icon: Icons.history_toggle_off_rounded,
                  label: 'No history entries',
                );
              }
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(nzbgetHistoryProvider);
                },
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(
              top: 4,
              bottom: FloatingNavBarMetrics.getScrollViewBottomPadding(context),
            ),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final item = visible[index];
                    return NzbgetHistoryTile(
                      item: item,
                      onDelete: () => _confirmDeleteHistory(context, ref, item),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteHistory(
    BuildContext context,
    WidgetRef ref,
    NzbgetHistoryItem item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete from history'),
        content: Text(
          'Remove "${item.name}" from NZBGet history? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await runNzbgetAction(
      context,
      ref,
      action: (service) => service.deleteHistoryItems([item.id]),
      successMessage: 'Deleted from history',
      failureMessage: 'Failed to delete',
      invalidate: [nzbgetStatusProvider, nzbgetHistoryProvider],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String label;

  const _EmptyState({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: AppSpacing.md),
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
