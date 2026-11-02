import 'package:flutter/material.dart';

import 'package:seekarr/core/app_radius.dart';
import 'package:seekarr/core/app_spacing.dart';
import 'package:seekarr/core/theme.dart';
import 'package:seekarr/features/npm/domain/cert_expiry.dart';
import 'package:seekarr/features/npm/domain/models/npm_certificate.dart';
import 'package:seekarr/features/npm/domain/models/npm_proxy_host.dart';

/// One proxy-host row. Read-only by design: v1 has no enable/disable toggle
/// (that is `PUT /api/nginx/proxy-hosts/{id}`).
class NpmHostTile extends StatelessWidget {
  final NpmProxyHost host;

  /// Certificate from `?expand=certificate` (or a local lookup by
  /// `certificate_id`); drives the SSL chip.
  final NpmCertificate? certificate;

  const NpmHostTile({super.key, required this.host, this.certificate});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
                Icon(
                  host.sslForced ? Icons.lock_rounded : Icons.language_rounded,
                  size: 16,
                  color: host.enabled
                      ? AppColors.npm
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    host.primaryDomain,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _enabledPill(context),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(
                  child: Text(
                    host.forwardTarget,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontFamily: 'JetBrains Mono',
                      fontSize: 10,
                    ),
                  ),
                ),
                if (host.domainNames.length > 1) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '+${host.domainNames.length - 1} domain'
                    '${host.domainNames.length == 2 ? '' : 's'}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _sslChip(context),
                if (host.http2Support) _metaChip(context, 'HTTP/2'),
                if (host.allowWebsocketUpgrade) _metaChip(context, 'WebSocket'),
              ],
            ),
            if (!host.isLive) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 12,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      host.nginxError.isEmpty
                          ? 'NPM cannot reach this upstream'
                          : host.nginxError,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.error,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _enabledPill(BuildContext context) {
    final color = host.enabled
        ? AppColors.success
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.borderRadiusSm,
      ),
      child: Text(
        host.enabled ? 'ENABLED' : 'DISABLED',
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _sslChip(BuildContext context) {
    final linked = certificate;
    if (linked == null) {
      if (host.certificateId == null) {
        return _metaChip(context, 'No SSL', muted: true);
      }
      return _metaChip(
        context,
        host.sslForced
            ? 'SSL forced · #${host.certificateId}'
            : 'SSL #${host.certificateId}',
        muted: true,
      );
    }

    final status = linked.expiryStatus();
    final (background, foreground) = _sslColors(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.borderRadiusSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_rounded, size: 11, color: foreground),
          const SizedBox(width: 3),
          Text(
            linked.expiryLabel(),
            style: TextStyle(
              color: foreground,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color) _sslColors(BuildContext context, CertExpiryStatus status) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return switch (status) {
      CertExpiryStatus.ok => (
        AppColors.success.withValues(alpha: 0.12),
        AppColors.success,
      ),
      CertExpiryStatus.expiringSoon => (
        AppColors.warning.withValues(alpha: 0.12),
        AppColors.warning,
      ),
      CertExpiryStatus.critical || CertExpiryStatus.expired => (
        AppColors.error.withValues(alpha: 0.12),
        AppColors.error,
      ),
      CertExpiryStatus.unknown => (muted.withValues(alpha: 0.12), muted),
    };
  }

  Widget _metaChip(BuildContext context, String label, {bool muted = false}) {
    final color = muted
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : AppColors.npm;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppRadius.borderRadiusSm,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
