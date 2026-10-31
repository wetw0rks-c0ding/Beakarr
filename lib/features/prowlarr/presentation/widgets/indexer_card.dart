import 'package:flutter/material.dart';

import 'package:seekarr/core/app_spacing.dart';
import 'package:seekarr/core/theme.dart';
import 'package:seekarr/features/prowlarr/domain/models/prowlarr_indexer.dart';

class IndexerCard extends StatelessWidget {
  final ProwlarrIndexer indexer;
  final VoidCallback onTap;

  const IndexerCard({
    super.key,
    required this.indexer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.surfaceContainerHighDark),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    indexer.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                InfoBadge(label: 'Protocol:', value: indexer.protocol.isEmpty ? 'N/A' : indexer.protocol),
                const Spacer(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class Badge extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const Badge({
    super.key,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color ?? AppColors.surfaceContainerHighDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceDark,
                ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceDark,
                ),
          ),
        ],
      ),
    );
  }
}

class InfoBadge extends StatelessWidget {
  final String label;
  final String value;

  const InfoBadge({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceDark,
                ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceDark,
                ),
          ),
        ],
      ),
    );
  }
}
