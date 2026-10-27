import 'package:flutter/material.dart';

import 'package:seekarr/core/utils/release_utils.dart';

/// Widget displaying a single release item in the interactive search list.
///
/// Shows release title, metadata (indexer, size, seeders, quality, age),
/// custom formats, and any rejection reasons.
class ReleaseListItem extends StatelessWidget {
  final dynamic release;
  final VoidCallback onGrab;

  const ReleaseListItem({
    super.key,
    required this.release,
    required this.onGrab,
  });

  @override
  Widget build(BuildContext context) {
    // Basic info
    final releaseTitle = release['title'] as String? ?? 'Unknown';
    final indexer = release['indexer'] as String? ?? 'Unknown';
    final sizeNum = release['size'] as num? ?? 0;
    final sizeStr = formatReleaseSize(sizeNum.toInt());
    final seeders = (release['seeders'] as num?)?.toInt() ?? 0;
    final quality = release['quality']?['quality']?['name'] as String? ?? '';
    final ageNum = release['ageMinutes'] as num? ?? 0;
    final ageStr = formatReleaseAge(ageNum.toInt());

    // Custom formats
    final customFormatScore =
        (release['customFormatScore'] as num?)?.toInt() ?? 0;
    final customFormats = release['customFormats'] as List<dynamic>? ?? [];

    // Rejection info
    final rejections = release['rejections'] as List<dynamic>? ?? [];
    final isRejected = rejections.isNotEmpty;
    final isApproved = release['approved'] as bool? ?? false;

    // Determine status color
    Color statusColor;
    if (isRejected) {
      statusColor = Colors.red;
    } else if (isApproved) {
      statusColor = Colors.green;
    } else {
      statusColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: isRejected
            ? Border.all(color: Colors.red.withValues(alpha: 0.3), width: 1)
            : null,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Material(
          color: Colors.transparent,
          child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: _buildLeadingIcon(statusColor, customFormatScore),
          title: Text(
            releaseTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
          subtitle: _buildSubtitleRow(
            indexer: indexer,
            sizeStr: sizeStr,
            seeders: seeders,
            quality: quality,
            ageStr: ageStr,
          ),
          trailing: IconButton(
            icon: const Icon(Icons.download, size: 20),
            color: statusColor,
            onPressed: onGrab,
            tooltip: 'Grab Release',
          ),
          children: [
            // Custom Formats section
            if (customFormats.isNotEmpty) ...[
              _buildSectionHeader(context, 'Custom Formats', customFormatScore),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: customFormats.map<Widget>((cf) {
                  final name = cf['name'] as String? ?? 'Unknown';
                  final score = (cf['score'] as num?)?.toInt() ?? 0;
                  return CustomFormatChip(name: name, score: score);
                }).toList(),
              ),
            ],

            // Rejections section
            if (isRejected) ...[
              const SizedBox(height: 12),
              _buildSectionHeader(
                context,
                'Rejection Reasons',
                null,
                isError: true,
              ),
              ...rejections.map<Widget>((rejection) {
                final reason = rejection is String
                    ? rejection
                    : (rejection['reason'] as String? ?? rejection.toString());
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 14,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          reason,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],

            // Empty custom formats message
            if (customFormats.isEmpty && !isRejected)
              const Text(
                'No custom format data available',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildLeadingIcon(Color statusColor, int score) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            score >= 0 ? '+$score' : '$score',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
          Text('CF', style: TextStyle(fontSize: 8, color: statusColor)),
        ],
      ),
    );
  }

  Widget _buildSubtitleRow({
    required String indexer,
    required String sizeStr,
    required int seeders,
    required String quality,
    required String ageStr,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          InfoChip(icon: Icons.dns_outlined, text: indexer),
          InfoChip(icon: Icons.storage_outlined, text: sizeStr),
          InfoChip(icon: Icons.arrow_upward, text: '$seeders'),
          if (quality.isNotEmpty)
            InfoChip(icon: Icons.hd_outlined, text: quality),
          InfoChip(icon: Icons.schedule_outlined, text: ageStr),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    int? score, {
    bool isError = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isError ? Colors.red : Colors.grey[400],
            ),
          ),
          if (score != null) ...[
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: score >= 0
                    ? Colors.green.withValues(alpha: 0.2)
                    : Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Score: ${score >= 0 ? '+$score' : score}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: score >= 0 ? Colors.green : Colors.red,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Chip showing a custom format name with its score.
class CustomFormatChip extends StatelessWidget {
  final String name;
  final int score;

  const CustomFormatChip({super.key, required this.name, required this.score});

  @override
  Widget build(BuildContext context) {
    final isPositive = score >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPositive
            ? Colors.green.withValues(alpha: 0.15)
            : Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPositive
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name, style: const TextStyle(fontSize: 10)),
          const SizedBox(width: 4),
          Text(
            isPositive ? '+$score' : '$score',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isPositive ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small chip displaying an icon with text, used for metadata display.
class InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const InfoChip({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: Colors.grey),
        const SizedBox(width: 2),
        Text(text, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
