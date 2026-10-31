import 'package:seekarr/core/utils/dynamic_map_utils.dart';
import 'package:seekarr/features/npm/domain/cert_expiry.dart';

/// A `GET /api/nginx/certificates` entry.
///
/// `fromJson` is tolerant: NPM returns the same shape for Let's Encrypt and
/// custom certs, omits fields on older versions, and a single odd row must
/// never blank the certificates tab.
class NpmCertificate {
  final int id;
  final String provider;
  final String niceName;
  final List<String> domainNames;

  /// ISO-8601 with `Z`, parsed as UTC.
  final DateTime? expiresOn;
  final DateTime? createdOn;
  final DateTime? modifiedOn;

  const NpmCertificate({
    this.id = 0,
    this.provider = '',
    this.niceName = '',
    this.domainNames = const [],
    this.expiresOn,
    this.createdOn,
    this.modifiedOn,
  });

  factory NpmCertificate.fromJson(Map<String, dynamic> json) {
    return NpmCertificate(
      id: intOrNull(json['id']) ?? 0,
      provider: stringOrNull(json['provider']) ?? '',
      niceName: stringOrNull(json['nice_name']) ?? '',
      domainNames: _stringList(json['domain_names']),
      expiresOn: _dateOrNull(json['expires_on']),
      createdOn: _dateOrNull(json['created_on']),
      modifiedOn: _dateOrNull(json['modified_on']),
    );
  }

  /// Certificate name to show in a tile; falls back to the first domain, then
  /// the id so a row without a `nice_name` is still identifiable.
  String get displayName {
    if (niceName.isNotEmpty) return niceName;
    if (domainNames.isNotEmpty) return domainNames.first;
    return 'Certificate #$id';
  }

  bool get isLetsEncrypt => provider == 'letsencrypt';

  CertExpiryStatus expiryStatus({DateTime? now}) =>
      certExpiryStatus(expiresOn, now: now);

  String expiryLabel({DateTime? now}) => certExpiryLabel(
    expiresOn,
    now: now,
    status: expiryStatus(now: now),
  );

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value.map(stringOrNull).whereType<String>().toList(growable: false);
  }

  static DateTime? _dateOrNull(dynamic value) {
    final text = stringOrNull(value);
    if (text == null) return null;
    return DateTime.tryParse(text);
  }
}
