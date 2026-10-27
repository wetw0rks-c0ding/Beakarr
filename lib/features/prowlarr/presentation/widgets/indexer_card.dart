import 'package:flutter/material.dart';

import 'package:seekarr/core/app_colors.dart';
import 'package:seekarr/core/app_spacing.dart';
import 'package:seekarr/core/widgets/status_badge.dart';
import 'package:seekarr/features/prowlarr/domain/models/prowlarr_indexer.dart';

class IndexerCard extends StatelessWidget {
  final ProwlarrIndexer indexer;
  final VoidCallback onTap;

  const IndexerCard({
    super.key,
    required this.indexer,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.blue100),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    indexer.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (indexer.message != null) ...[
                  const SizedBox(width: 8),
                  StatusBadge(message: indexer.message!),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Badge(label: 'Protocol:', value: indexer.implementationName, color: AppColors.blue50),
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
        color: color ?? AppColors.blue50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.blue700,
                ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.blue700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
