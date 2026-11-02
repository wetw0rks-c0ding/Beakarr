import 'package:flutter/material.dart';

import 'package:seekarr/core/app_radius.dart';
import 'package:seekarr/core/app_spacing.dart';
import 'package:seekarr/core/theme.dart';
import 'package:seekarr/features/npm/domain/cert_expiry.dart';
import 'package:seekarr/features/npm/domain/models/npm_certificate.dart';

/// One certificate row: name, provider, domains and expiry chip.
///
/// Read-only: renew is `POST /api/nginx/certificates/{id}/renew`, deferred
/// past v1.
class NpmCertTile extends StatelessWidget {
  final NpmCertificate certificate;

  const NpmCertTile({super.key, required this.certificate});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final status = certificate.expiryStatus();
    final color = switch (status) {
      CertExpiryStatus.ok => AppColors.success,
      CertExpiryStatus.expiringSoon => AppColors.warning,
      CertExpiryStatus.critical || CertExpiryStatus.expired => AppColors.error,
      CertExpiryStatus.unknown => colorScheme.onSurfaceVariant,
    };

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
                Icon(Icons.verified_user_rounded, size: 16, color: color),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    certificate.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _providerPill(context),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              certificate.domainNames.isEmpty
                  ? 'No domains'
                  : certificate.domainNames.join(', '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: AppRadius.borderRadiusSm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_rounded, size: 11, color: color),
                  const SizedBox(width: 3),
                  Text(
                    certificate.expiryLabel(),
                    style: TextStyle(
                      color: color,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _providerPill(BuildContext context) {
    final label = certificate.provider.isEmpty
        ? 'CUSTOM'
        : certificate.provider.toUpperCase();
    final color = certificate.isLetsEncrypt
        ? AppColors.success
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.borderRadiusSm,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
