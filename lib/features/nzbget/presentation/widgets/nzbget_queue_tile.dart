import 'package:flutter/material.dart';

import 'package:seekarr/core/app_radius.dart';
import 'package:seekarr/core/app_spacing.dart';
import 'package:seekarr/core/theme.dart';
import 'package:seekarr/features/nzbget/domain/models/nzbget_queue_item.dart';

/// One download-queue row: name, category chip, status pill, size, progress,
/// health and per-item pause/resume + delete actions.
class NzbgetQueueTile extends StatelessWidget {
  final NzbgetQueueItem item;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onTogglePause;
  final VoidCallback? onDelete;

  const NzbgetQueueTile({
    super.key,
    required this.item,
    this.selected = false,
    this.onTap,
    this.onLongPress,
    this.onTogglePause,
    this.onDelete,
  });

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
        color: selected
            ? AppColors.nzbget.withValues(alpha: 0.08)
            : colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderRadiusMd,
          side: BorderSide(
            color: selected
                ? AppColors.nzbget.withValues(alpha: 0.4)
                : colorScheme.outline,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: AppRadius.borderRadiusMd,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      item.isPostProcessing
                          ? Icons.settings_suggest_rounded
                          : Icons.cloud_download_rounded,
                      size: 16,
                      color: item.isPaused
                          ? colorScheme.onSurfaceVariant
                          : AppColors.nzbget,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _statusPill(context, pill),
                    if (onTogglePause != null || onDelete != null)
                      _actionMenu(context),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    if (item.category.isNotEmpty) ...[
                      _categoryChip(context),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Text(
                      '${item.remainingSizeFormatted} / '
                      '${item.fileSizeFormatted}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontSize: 10,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'HP ${item.healthFormatted}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: item.health < 1000
                            ? AppColors.warning
                            : colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: AppRadius.borderRadiusXs,
                  child: SizedBox(
                    height: 3,
                    width: double.infinity,
                    child: LinearProgressIndicator(
                      value: item.progress,
                      backgroundColor: colorScheme.outline,
                      color: item.isPaused
                          ? colorScheme.onSurfaceVariant
                          : AppColors.nzbget,
                    ),
                  ),
                ),
                if (item.isPostProcessing) ...[
                  const SizedBox(height: 5),
                  Text(
                    [
                      if (item.postInfoText.isNotEmpty) item.postInfoText,
                      if (item.postStageProgress > 0)
                        '${item.postStageProgress}%',
                    ].join(' · '),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.warning,
                      fontSize: 10,
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Text(
                        item.progressFormatted,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          fontSize: 10,
                        ),
                      ),
                      if (item.activeDownloads > 0) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '${item.activeDownloads} conn',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 10,
                              ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  (Color background, Color foreground) _pillColors(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final muted = colorScheme.onSurfaceVariant;
    if (item.isPaused) {
      return (muted.withValues(alpha: 0.18), muted);
    }
    if (item.isPostProcessing) {
      return (AppColors.warning.withValues(alpha: 0.12), AppColors.warning);
    }
    return (AppColors.nzbget.withValues(alpha: 0.09), AppColors.nzbget);
  }

  Widget _statusPill(BuildContext context, (Color, Color) colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: AppRadius.borderRadiusSm,
      ),
      child: Text(
        item.status.isEmpty ? '—' : item.status,
        style: TextStyle(
          color: colors.$2,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _categoryChip(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: AppRadius.borderRadiusXs,
      ),
      child: Text(
        item.category,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontSize: 9,
        ),
      ),
    );
  }

  Widget _actionMenu(BuildContext context) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      iconSize: 18,
      icon: Icon(
        Icons.more_vert_rounded,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      tooltip: 'Item actions',
      onSelected: (value) {
        if (value == 'delete') {
          onDelete?.call();
        } else {
          onTogglePause?.call();
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'pause',
          child: ListTile(
            leading: Icon(
              item.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            ),
            title: Text(item.isPaused ? 'Resume' : 'Pause'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(
              Icons.delete_outline_rounded,
              color: Theme.of(ctx).colorScheme.error,
            ),
            title: const Text('Delete'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}
