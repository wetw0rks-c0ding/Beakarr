import 'package:flutter/material.dart';

class OmvHealthPill extends StatelessWidget {
  final String status;

  const OmvHealthPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = status.trim().toUpperCase();
    Color color;
    String label;
    if (s == 'GOOD' || s.isEmpty) {
      if (s.isEmpty) {
        color = theme.colorScheme.outline;
        label = 'No SMART';
      } else {
        color = Colors.green;
        label = 'Good';
      }
    } else if (s.startsWith('BAD_SECTOR') || s.startsWith('BAD_ATTRIBUTE')) {
      color = Colors.orange;
      label = status;
    } else if (s == 'BAD_STATUS') {
      color = theme.colorScheme.error;
      label = 'Bad';
    } else {
      color = theme.colorScheme.outline;
      label = status.isEmpty ? 'No SMART' : status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}