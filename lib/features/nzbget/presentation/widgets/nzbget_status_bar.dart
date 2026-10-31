import 'package:flutter/material.dart';

import 'package:seekarr/core/app_radius.dart';
import 'package:seekarr/core/app_spacing.dart';
import 'package:seekarr/core/theme.dart';
import 'package:seekarr/features/nzbget/domain/models/nzbget_status.dart';

/// Compact server strip above the queue/history lists.
///
/// Renders placeholders (`—`) while [status] is null so the layout does not
/// jump between the first load and the first poll response.
class NzbgetStatusBar extends StatelessWidget {
  final NzbgetStatus? status;
  final int queueCount;
  final int activeCount;

  const NzbgetStatusBar({
    super.key,
    this.status,
    this.queueCount = 0,
    this.activeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final data = status;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: AppRadius.borderRadiusMd,
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.cloud_download_rounded,
                size: 16,
                color: AppColors.nzbget,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                data == null
                    ? '—'
                    : '${data.downloadRateFormatted} · ${data.remainingSizeFormatted} left',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              if (data != null && data.isPaused) _badge(context, 'PAUSED'),
              if (data != null && data.postJobCount > 0) ...[
                const SizedBox(width: AppSpacing.xs),
                _badge(context, '${data.postJobCount} PP'),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$queueCount item${queueCount == 1 ? '' : 's'} · '
                  '$activeCount downloading',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ),
              if (data != null)
                Text(
                  'Disk ${data.freeDiskSpaceFormatted}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: AppRadius.borderRadiusSm,
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.warning,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
