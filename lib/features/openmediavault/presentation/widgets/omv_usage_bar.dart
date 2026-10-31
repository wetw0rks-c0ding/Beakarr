import 'package:flutter/material.dart';

/// Full-width usage bar with label + percentage + progress indicator.
///
/// Requires bounded width from its parent (e.g. directly in a Column or
/// Card). Do NOT place inside a Row as a non-flex child (such as
/// [OmvStatTile.trailing]): rows pass unbounded width constraints and the
/// inner Expanded then throws during layout.
///
/// Correct placement (same as this screen's Storage tab and the Overview
/// Memory row): as a full-width sibling below the tile —
/// ```dart
/// Column(
///   children: [
///     OmvStatTile(label: 'Memory', value: '23.7 GiB / 31.3 GiB'),
///     if (ratio != null) OmvUsageBar(label: '', ratio: ratio, valueLabel: '76%'),
///   ],
/// )
/// ```
class OmvUsageBar extends StatelessWidget {
  final String label;
  final double? ratio; // 0..1
  final String? valueLabel;

  const OmvUsageBar({
    super.key,
    required this.label,
    this.ratio,
    this.valueLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = (ratio ?? 0).clamp(0.0, 1.0);
    Color color;
    if (ratio == null) {
      color = theme.colorScheme.outline;
    } else if (r >= 0.9) {
      color = theme.colorScheme.error;
    } else if (r >= 0.75) {
      color = Colors.orange;
    } else {
      color = Theme.of(context).colorScheme.primary;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
              if (valueLabel != null)
                Text(valueLabel!, style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio == null ? null : r,
              minHeight: 8,
              color: color,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}