import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:seekarr/core/app_radius.dart';
import 'package:seekarr/core/app_spacing.dart';
import 'package:seekarr/core/theme.dart';
import 'package:seekarr/features/wizarr/domain/models/wizarr_invitation.dart';

/// One Wizarr invitation row. Read-only by design (v1): no revoke/create.
class WizarrInviteTile extends StatelessWidget {
  final WizarrInvitation invitation;

  const WizarrInviteTile({super.key, required this.invitation});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final inv = invitation;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: AppRadius.borderRadiusMd,
          border: Border.all(color: colorScheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.mail_rounded, size: 16, color: AppColors.wizarr),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    inv.code ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                  ),
                ),
                const SizedBox(width: 6),
                _statusChip(context, inv.statusLabel),
              ],
            ),
            if (inv.server != null && inv.server!.isNotEmpty) ...[
              const SizedBox(height: 5),
              Row(
                children: [
                  _metaChip(context, inv.server!, color: AppColors.wizarr),
                  if (inv.serverType != null && inv.serverType!.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _metaChip(context, inv.serverType!, muted: true),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 7),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _metaChip(
                  context,
                  inv.usesLeft == null
                      ? 'Unlimited uses'
                      : '${inv.usesLeft} uses left',
                  muted: inv.usesLeft == null,
                ),
                _metaChip(
                  context,
                  inv.expiresAt == null
                      ? 'No expiry'
                      : _formatDate(inv.expiresAt!),
                  muted: true,
                ),
              ],
            ),
            if (inv.inviteUrl != null && inv.inviteUrl!.isNotEmpty) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: inv.inviteUrl!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invite link copied')),
                  );
                },
                child: Text(
                  inv.inviteUrl!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.wizarr,
                        fontFamily: 'JetBrains Mono',
                        fontSize: 10,
                        decoration: TextDecoration.underline,
                      ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusChip(BuildContext context, String label) {
    final color = label == 'Active'
        ? AppColors.success
        : (label == 'Expired' ? AppColors.error : AppColors.warning);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.borderRadiusSm,
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _metaChip(
    BuildContext context,
    String label, {
    Color? color,
    bool muted = false,
  }) {
    final c = muted
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : (color ?? AppColors.wizarr);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: AppRadius.borderRadiusSm,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: c,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}