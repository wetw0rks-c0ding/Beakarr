import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seekarr/core/theme.dart';
import 'package:seekarr/core/utils/sheet_utils.dart';
import 'package:seekarr/features/nzbget/presentation/nzbget_actions.dart';
import 'package:seekarr/features/nzbget/presentation/nzbget_provider.dart';
import 'package:seekarr/features/nzbget/presentation/widgets/add_nzb_url_sheet.dart';

/// Trailing action for `ServiceDashboardScreen`: add-by-URL plus an overflow
/// menu for queue-wide pause/resume and refresh.
class NzbgetActionsBar extends ConsumerWidget {
  const NzbgetActionsBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.add_link_rounded, color: AppColors.nzbget),
          tooltip: 'Add NZB by URL',
          onPressed: () => SheetUtils.showSeekarrModalSheet(
            context: context,
            builder: (_) => const AddNzbUrlSheet(),
          ),
        ),
        const _NzbgetOverflowMenu(),
      ],
    );
  }
}

class _NzbgetOverflowMenu extends ConsumerWidget {
  const _NzbgetOverflowMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_NzbgetOverflowAction>(
      icon: const Icon(Icons.more_vert_rounded, color: AppColors.nzbget),
      tooltip: 'More',
      onSelected: (action) => _handle(context, ref, action),
      itemBuilder: (ctx) => const [
        PopupMenuItem(
          value: _NzbgetOverflowAction.pauseAll,
          child: ListTile(
            leading: Icon(Icons.pause_rounded),
            title: Text('Pause all'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: _NzbgetOverflowAction.resumeAll,
          child: ListTile(
            leading: Icon(Icons.play_arrow_rounded),
            title: Text('Resume all'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: _NzbgetOverflowAction.refresh,
          child: ListTile(
            leading: Icon(Icons.refresh_rounded),
            title: Text('Refresh'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Future<void> _handle(
    BuildContext context,
    WidgetRef ref,
    _NzbgetOverflowAction action,
  ) {
    switch (action) {
      case _NzbgetOverflowAction.pauseAll:
        return runNzbgetAction(
          context,
          ref,
          action: (service) => service.pauseQueue(),
          successMessage: 'Queue paused',
          failureMessage: 'Failed to pause',
          invalidate: [nzbgetStatusProvider, nzbgetQueueProvider],
        );
      case _NzbgetOverflowAction.resumeAll:
        return runNzbgetAction(
          context,
          ref,
          action: (service) => service.resumeQueue(),
          successMessage: 'Queue resumed',
          failureMessage: 'Failed to resume',
          invalidate: [nzbgetStatusProvider, nzbgetQueueProvider],
        );
      case _NzbgetOverflowAction.refresh:
        ref.invalidate(nzbgetStatusProvider);
        ref.invalidate(nzbgetQueueProvider);
        ref.invalidate(nzbgetHistoryProvider);
        return Future<void>.value();
    }
  }
}

enum _NzbgetOverflowAction { pauseAll, resumeAll, refresh }
