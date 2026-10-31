import 'package:flutter/material.dart';

import 'package:seekarr/core/app_radius.dart';
import 'package:seekarr/core/app_spacing.dart';
import 'package:seekarr/core/theme.dart';
import 'package:seekarr/features/nzbget/domain/models/nzbget_history_item.dart';

/// One finished download row: name, outcome pill, size, relative age and a
/// final-delete action.
class NzbgetHistoryTile extends StatelessWidget {
  final NzbgetHistoryItem item;
  final VoidCallback? onDelete;

  const NzbgetHistoryTile({super.key, required this.item, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pill = _pillColors(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: Material(
        color: colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderRadiusMd,
          side: BorderSide(color: colorScheme.outline),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
          child: Row(
            children: [
              Icon(
                item.succeeded
                    ? Icons.check_circle_outline_rounded
                    : item.failed
                    ? Icons.error_outline_rounded
                    : Icons.history_rounded,
                size: 16,
                color: pill.$2,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        item.fileSizeFormatted,
                        if (item.category.isNotEmpty) item.category,
                        if (item.historyTimeFormatted.isNotEmpty)
                          item.historyTimeFormatted,
                      ].join(' · '),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: pill.$1,
                  borderRadius: AppRadius.borderRadiusSm,
                ),
                child: Text(
                  item.status.isEmpty ? '—' : item.statusLabel,
                  style: TextStyle(
                    color: pill.$2,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              if (onDelete != null)
                IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  tooltip: 'Delete from history',
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                ),
            ],
          ),
        ),
      ),
    );
  }

  (Color background, Color foreground) _pillColors(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    if (item.succeeded) {
      return (AppColors.success.withValues(alpha: 0.12), AppColors.success);
    }
    if (item.deleted) {
      return (muted.withValues(alpha: 0.15), muted);
    }
    if (item.status.startsWith('WARNING')) {
      return (AppColors.warning.withValues(alpha: 0.12), AppColors.warning);
    }
    if (item.failed) {
      return (AppColors.error.withValues(alpha: 0.12), AppColors.error);
    }
    return (muted.withValues(alpha: 0.15), muted);
  }
}
