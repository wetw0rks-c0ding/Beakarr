import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seekarr/core/theme.dart';
import 'package:seekarr/features/nzbget/presentation/nzbget_actions.dart';
import 'package:seekarr/features/nzbget/presentation/nzbget_provider.dart';

/// Multi-select action bar for queue items keyed by NZBID.
class NzbgetSelectionBar extends ConsumerWidget {
  const NzbgetSelectionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(nzbgetSelectionProvider);
    final colorScheme = Theme.of(context).colorScheme;

    if (selected.isEmpty) return const SizedBox.shrink();

    return Material(
      elevation: 8,
      color: colorScheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                TextButton(
                  onPressed: () {
                    ref.read(nzbgetSelectionProvider.notifier).state = {};
                  },
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                Text(
                  '${selected.length} selected',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 16),
                TextButton.icon(
                  onPressed: () => runNzbgetAction(
                    context,
                    ref,
                    action: (service) => service.resumeItems(selected.toList()),
                    successMessage: 'Resumed',
                    failureMessage: 'Failed to resume',
                    invalidate: [nzbgetStatusProvider, nzbgetQueueProvider],
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Resume'),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.pause_rounded,
                    color: AppColors.warning,
                  ),
                  tooltip: 'Pause',
                  onPressed: () => runNzbgetAction(
                    context,
                    ref,
                    action: (service) => service.pauseItems(selected.toList()),
                    failureMessage: 'Failed to pause',
                    invalidate: [nzbgetStatusProvider, nzbgetQueueProvider],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: colorScheme.error,
                  ),
                  tooltip: 'Delete',
                  onPressed: () =>
                      confirmDeleteNzbgetQueueItems(context, ref, selected),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Confirms and deletes the selected queue items (they move to history).
///
/// Returns `true` when the delete succeeded, in which case the selection is
/// cleared.
Future<bool> confirmDeleteNzbgetQueueItems(
  BuildContext context,
  WidgetRef ref,
  Set<int> ids,
) async {
  final count = ids.length;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete downloads'),
      content: Text(
        'Remove $count item${count > 1 ? 's' : ''} from the queue? '
        '${count > 1 ? 'They' : 'It'} will move to History.',
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
  if (confirmed != true || !context.mounted) return false;

  final ok = await runNzbgetAction(
    context,
    ref,
    action: (service) => service.deleteQueueItems(ids.toList()),
    successMessage: 'Deleted $count item${count > 1 ? 's' : ''}',
    failureMessage: 'Failed to delete',
    invalidate: [
      nzbgetStatusProvider,
      nzbgetQueueProvider,
      nzbgetHistoryProvider,
    ],
  );
  if (ok) {
    ref.read(nzbgetSelectionProvider.notifier).state = {};
  }
  return ok;
}
