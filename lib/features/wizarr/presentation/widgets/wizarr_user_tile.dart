import 'package:flutter/material.dart';

import 'package:seekarr/core/app_radius.dart';
import 'package:seekarr/core/app_spacing.dart';
import 'package:seekarr/core/theme.dart';
import 'package:seekarr/features/wizarr/domain/models/wizarr_user.dart';

/// One Wizarr-managed user row (read-only v1).
class WizarrUserTile extends StatelessWidget {
  final WizarrUser user;

  const WizarrUserTile({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final u = user;

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
                Icon(Icons.person_rounded, size: 16, color: AppColors.wizarr),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    u.username ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (u.server != null && u.server!.isNotEmpty)
                  _metaChip(context, u.server!, color: AppColors.wizarr),
              ],
            ),
            if (u.email != null && u.email!.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                u.email!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ],
            if (u.serverType != null && u.serverType!.isNotEmpty) ...[
              const SizedBox(height: 5),
              _metaChip(context, u.serverType!, muted: true),
            ],
            if (u.expiresAt != null) ...[
              const SizedBox(height: 5),
              Text(
                'Expires: ${_formatDate(u.expiresAt!)}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ],
          ],
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
        style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.w700),
      ),
    );
  }

  String _formatDate(DateTime d) {
    // Server instants are UTC; render in the device timezone so the
    // displayed day matches the user's calendar.
    final local = d.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}
