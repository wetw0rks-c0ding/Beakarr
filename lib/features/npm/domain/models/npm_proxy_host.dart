import 'package:seekarr/core/utils/dynamic_map_utils.dart';
import 'package:seekarr/features/npm/domain/cert_expiry.dart';
import 'package:seekarr/features/npm/domain/models/npm_certificate.dart';

/// A `GET /api/nginx/proxy-hosts?expand=certificate` entry.
///
/// `meta.nginx_online` reflects NPM's last health check of the upstream, so a
/// host can be enabled yet unreachable — the tile surfaces that separately.
class NpmProxyHost {
  final int id;
  final List<String> domainNames;
  final String forwardScheme;
  final String forwardHost;
  final int forwardPort;
  final bool enabled;
  final bool sslForced;
  final int? certificateId;
  final bool http2Support;
  final bool allowWebsocketUpgrade;

  /// `meta` object; `nginx_online == false` means NPM failed to reach the
  /// upstream, and `nginx_err` carries its message.
  final Map<String, dynamic> meta;

  /// Certificate sub-object included by `?expand=certificate`.
  final NpmCertificate? certificate;

  const NpmProxyHost({
    this.id = 0,
    this.domainNames = const [],
    this.forwardScheme = '',
    this.forwardHost = '',
    this.forwardPort = 0,
    this.enabled = false,
    this.sslForced = false,
    this.certificateId,
    this.http2Support = false,
    this.allowWebsocketUpgrade = false,
    this.meta = const {},
    this.certificate,
  });

  factory NpmProxyHost.fromJson(Map<String, dynamic> json) {
    final meta = mapOrNull(json['meta']) ?? const <String, dynamic>{};
    final certificateJson = mapOrNull(json['certificate']);
    return NpmProxyHost(
      id: intOrNull(json['id']) ?? 0,
      domainNames: _stringList(json['domain_names']),
      forwardScheme: stringOrNull(json['forward_scheme']) ?? '',
      forwardHost: stringOrNull(json['forward_host']) ?? '',
      forwardPort: intOrNull(json['forward_port']) ?? 0,
      enabled: _boolOrFalse(json['enabled']),
      sslForced: _boolOrFalse(json['ssl_forced']),
      certificateId: intOrNull(json['certificate_id']),
      http2Support: _boolOrFalse(json['http2_support']),
      allowWebsocketUpgrade: _boolOrFalse(json['allow_websocket_upgrade']),
      meta: meta,
      certificate: certificateJson == null
          ? null
          : NpmCertificate.fromJson(certificateJson),
    );
  }

  /// First domain, or `—` when the host has none (NPM allows that only for a
  /// half-configured host, but it must not crash the list).
  String get primaryDomain => domainNames.isEmpty ? '—' : domainNames.first;

  /// `meta.nginx_online` is absent on older NPM builds; only an explicit
  /// `false` is treated as down.
  bool get isLive => meta['nginx_online'] != false;

  /// NPM's error text when its own upstream probe failed.
  String get nginxError => stringOrNull(meta['nginx_err']) ?? '';

  bool get hasCertificate => certificateId != null;

  /// `scheme://forward_host:forward_port` for the tile subtitle.
  String get forwardTarget {
    final scheme = forwardScheme.isEmpty ? 'http' : forwardScheme;
    final host = forwardHost.isEmpty ? '—' : forwardHost;
    return forwardPort > 0 ? '$scheme://$host:$forwardPort' : '$scheme://$host';
  }

  /// The linked certificate's [`CertExpiryStatus`] plus its label, taken from
  /// the `expand=certificate` sub-object — no second round trip.
  ({CertExpiryStatus status, String label})? toSummary({DateTime? now}) {
    final linked = certificate;
    if (linked == null) return null;
    final status = linked.expiryStatus(now: now);
    return (status: status, label: linked.expiryLabel(now: now));
  }

  /// Case-insensitive substring match across every domain name.
  bool matchesQuery(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return domainNames.any((domain) => domain.toLowerCase().contains(needle));
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value.map(stringOrNull).whereType<String>().toList(growable: false);
  }

  static bool _boolOrFalse(dynamic value) => value == true || value == 1;
}
