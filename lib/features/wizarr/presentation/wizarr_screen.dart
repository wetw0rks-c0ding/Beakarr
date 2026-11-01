import 'package:flutter/material.dart';

import 'package:seekarr/core/app_spacing.dart';
import 'package:seekarr/core/widgets/floating_bottom_nav_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seekarr/core/widgets/async_value_widget.dart';
import 'package:seekarr/features/wizarr/data/wizarr_client.dart';
import 'package:seekarr/features/wizarr/data/wizarr_providers.dart';
import 'package:seekarr/features/wizarr/domain/models/wizarr_invitation.dart';
import 'package:seekarr/features/wizarr/domain/models/wizarr_user.dart';
import 'package:seekarr/features/wizarr/presentation/wizarr_create_sheet.dart';
import 'package:seekarr/features/wizarr/presentation/widgets/wizarr_invite_tile.dart';
import 'package:seekarr/features/wizarr/presentation/widgets/wizarr_user_tile.dart';

class WizarrScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  final double topPadding;

  const WizarrScreen({super.key, this.showAppBar = true, this.topPadding = 0});

  @override
  ConsumerState<WizarrScreen> createState() => _WizarrScreenState();
}

const int _invitationsTab = 0;
const int _usersTab = 1;

class _WizarrScreenState extends ConsumerState<WizarrScreen> {
  int _tab = _invitationsTab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar ? AppBar(title: const Text('Wizarr')) : null,
      body: Column(
        children: [
          if (widget.topPadding > 0)
            SizedBox(
              height: widget.topPadding + MediaQuery.paddingOf(context).top,
            ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: _invitationsTab,
                  label: Text('Invitations'),
                ),
                ButtonSegment(value: _usersTab, label: Text('Users')),
              ],
              selected: {_tab},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  setState(() => _tab = selection.first),
            ),
          ),
          Expanded(
            child: switch (_tab) {
              _usersTab => const _UsersTab(),
              _ => const _InvitationsTab(),
            },
          ),
        ],
      ),
    );
  }
}

class _InvitationsTab extends ConsumerWidget {
  const _InvitationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(wizarrInvitationsProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: [
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      fullscreenDialog: true,
                      builder: (_) => const WizarrCreateSheet(),
                    ),
                  );
                  ref.invalidate(wizarrInvitationsProvider);
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('New invite'),
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncValueWidget<List<WizarrInvitation>>(
            value: async,
            serviceName: 'Wizarr',
            data: (items) {
        // Read inside the data branch: the service provider throws when
        // unconfigured, and that must stay inside AsyncValueWidget's error
        // UI (NotConfiguredPlaceholder), not escape this build.
        final baseUrl = ref.read(wizarrServiceProvider).client.baseUrl;
        if (items.isEmpty) {
          return _emptyState(
            context,
            icon: Icons.mail_outline_rounded,
            label: 'No invitations',
            onRefresh: () async {
              ref.invalidate(wizarrInvitationsProvider);
              await ref.read(wizarrInvitationsProvider.future);
            },
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(wizarrInvitationsProvider);
            await ref.read(wizarrInvitationsProvider.future);
          },
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              bottom: FloatingNavBarMetrics.getScrollViewBottomPadding(context),
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final inv = items[index];
              return WizarrInviteTile(
                invitation: inv,
                baseUrl: baseUrl,
                onRevoke: inv.id == null
                    ? null
                    : () => showRevokeDialog(context, inv),
              );
            },
          ),
        );
      },
    ), // AsyncValueWidget
        ), // Expanded
      ], // Column
    ); // Column
  }
}

class _UsersTab extends ConsumerWidget {
  const _UsersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(wizarrUsersProvider);
    return AsyncValueWidget<List<WizarrUser>>(
      value: async,
      serviceName: 'Wizarr',
      data: (items) {
        if (items.isEmpty) {
          return _emptyState(
            context,
            icon: Icons.people_outline_rounded,
            label: 'No users',
            onRefresh: () async {
              ref.invalidate(wizarrUsersProvider);
              await ref.read(wizarrUsersProvider.future);
            },
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(wizarrUsersProvider);
            await ref.read(wizarrUsersProvider.future);
          },
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              bottom: FloatingNavBarMetrics.getScrollViewBottomPadding(context),
            ),
            itemCount: items.length,
            itemBuilder: (context, index) => WizarrUserTile(user: items[index]),
          ),
        );
      },
    );
  }
}

Widget _emptyState(
  BuildContext context, {
  required IconData icon,
  required String label,
  required Future<void> Function() onRefresh,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  return RefreshIndicator(
    onRefresh: onRefresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        top: AppSpacing.xxxl,
        bottom: FloatingNavBarMetrics.getScrollViewBottomPadding(context),
      ),
      children: [
        Icon(icon, size: 48, color: colorScheme.onSurfaceVariant),
        const SizedBox(height: AppSpacing.md),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Pull down to refresh',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ],
    ),
  );
}

Future<void> showRevokeDialog(
  BuildContext context,
  WizarrInvitation invitation,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => _RevokeDialog(invitation: invitation),
  );
}

class _RevokeDialog extends ConsumerStatefulWidget {
  final WizarrInvitation invitation;

  const _RevokeDialog({required this.invitation});

  @override
  ConsumerState<_RevokeDialog> createState() => _RevokeDialogState();
}

class _RevokeDialogState extends ConsumerState<_RevokeDialog> {
  bool _submitting = false;
  String? _error;

  Future<void> _revoke() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final service = ref.read(wizarrServiceProvider);
      await service.revokeInvitation(id: widget.invitation.id!);
      if (!mounted) return;
      ref.invalidate(wizarrInvitationsProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invite revoked')));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      final msg = e is WizarrException
          ? e.message
          : "Couldn't revoke invite — check connection and try again.";
      setState(() {
        _error = msg;
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.invitation.code ?? '';
    return AlertDialog(
      title: Text('Revoke invite $code?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Guests with the link will no longer be able to join.'),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _revoke,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Revoke'),
        ),
      ],
    );
  }
}
