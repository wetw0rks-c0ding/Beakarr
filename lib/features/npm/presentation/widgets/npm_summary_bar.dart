import 'package:flutter/material.dart';

import 'package:seekarr/core/app_radius.dart';
import 'package:seekarr/core/app_spacing.dart';
import 'package:seekarr/core/theme.dart';
import 'package:seekarr/features/npm/domain/cert_expiry.dart';
import 'package:seekarr/features/npm/domain/models/npm_certificate.dart';
import 'package:seekarr/features/npm/domain/models/npm_proxy_host.dart';

/// Compact strip above the hosts/certificates lists:
/// "N hosts · M enabled" plus certificate counts and a worst-cert chip.
///
/// The chip only appears when a certificate is inside a warning window, so a
/// healthy instance stays quiet.
class NpmSummaryBar extends StatelessWidget {
  final List<NpmProxyHost> hosts;
  final List<NpmCertificate> certificates;

  /// From [npmWorstCertificateProvider]; null when no certificate is inside a
  /// warning window.
  final NpmCertificate? worstCertificate;
  final VoidCallback? onCertificatesTap;

  const NpmSummaryBar({
    super.key,
    this.hosts = const [],
    this.certificates = const [],
    this.worstCertificate,
    this.onCertificatesTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = hosts.where((host) => host.enabled).length;
    final expiring = certificates
        .where((cert) => certExpirySeverity(cert.expiryStatus()) > 0)
        .length;
    final unreachable = hosts.where((host) => !host.isLive).length;
    final worst = worstCertificate;

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
              const Icon(Icons.router_rounded, size: 16, color: AppColors.npm),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '${hosts.length} host${hosts.length == 1 ? '' : 's'} · '
                  '$enabled enabled',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              if (worst != null) ...[
                const SizedBox(width: AppSpacing.sm),
                _WorstCertChip(certificate: worst, onTap: onCertificatesTap),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${certificates.length} '
                  'cert${certificates.length == 1 ? '' : 's'} · '
                  '$expiring expiring',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ),
              if (unreachable > 0)
                Text(
                  '$unreachable unreachable',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.error,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WorstCertChip extends StatelessWidget {
  final NpmCertificate certificate;
  final VoidCallback? onTap;

  const _WorstCertChip({required this.certificate, this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = certificate.expiryStatus();
    final color = switch (status) {
      CertExpiryStatus.expired || CertExpiryStatus.critical => AppColors.error,
      _ => AppColors.warning,
    };

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.borderRadiusSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_rounded, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            certificate.expiryLabel(),
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return chip;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: chip,
    );
  }
}
