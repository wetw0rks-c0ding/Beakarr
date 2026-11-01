import 'package:seekarr/core/utils/dynamic_map_utils.dart';

/// Tolerant model for a Wizarr invitation (read-only v1).
///
/// Field names follow the live Wizarr v3 `/api/swagger.json`
/// (`Invitation`: id/code/url/status/created/expires/used_at/used_by/
/// duration/unlimited/specific_libraries/display_name/server_names).
class WizarrInvitation {
  final int? id;
  final String? code;
  final String? inviteUrl;
  final String? status;
  final String? displayName;
  final List<String> serverNames;
  final bool unlimited;
  final DateTime? usedAt;
  final String? usedBy;
  final String? duration;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  const WizarrInvitation({
    this.id,
    this.code,
    this.inviteUrl,
    this.status,
    this.displayName,
    this.serverNames = const [],
    this.unlimited = false,
    this.usedAt,
    this.usedBy,
    this.duration,
    this.expiresAt,
    this.createdAt,
  });

  factory WizarrInvitation.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      final s = v.toString().trim();
      if (s.isEmpty) return null;
      return DateTime.tryParse(s);
    }

    List<String> parseNames(dynamic v) {
      if (v is! List) return const [];
      return v
          .map((e) => e?.toString().trim())
          .where((s) => s != null && s.isNotEmpty)
          .cast<String>()
          .toList(growable: false);
    }

    final unlimitedRaw = json['unlimited'];
    final unlimited = unlimitedRaw is bool
        ? unlimitedRaw
        : unlimitedRaw?.toString().toLowerCase() == 'true';

    return WizarrInvitation(
      id: intOrNull(json['id']),
      code: stringOrNull(json['code']),
      inviteUrl: stringOrNull(json['url'] ?? json['link']),
      status: stringOrNull(json['status']),
      displayName: stringOrNull(
        json['displayName'] ?? json['display_name'],
      ),
      serverNames: parseNames(
        json['serverNames'] ?? json['server_names'],
      ),
      unlimited: unlimited,
      usedAt: parseDate(json['usedAt'] ?? json['used_at']),
      usedBy: stringOrNull(json['usedBy'] ?? json['used_by']),
      duration: stringOrNull(json['duration']),
      expiresAt: parseDate(json['expires']),
      createdAt: parseDate(json['created']),
    );
  }

  /// A limited invite is consumed once `used_at`/`used_by` is set.
  bool get used =>
      usedAt != null || (usedBy != null && usedBy!.isNotEmpty);

  /// Remaining uses: null means unlimited, 0 means consumed.
  int? get usesLeft {
    if (unlimited) return null;
    return used ? 0 : 1;
  }

  bool get isExpired {
    if (status != null && status!.toLowerCase() == 'expired') return true;
    final e = expiresAt;
    if (e == null) return false;
    // Expired inclusively: an invite whose expiry is exactly now is expired.
    return !e.isAfter(DateTime.now());
  }

  bool get isExhausted => usesLeft == 0;

  String get statusLabel {
    if (isExpired) return 'Expired';
    if (isExhausted) return 'Used up';
    return 'Active';
  }

  /// Shareable link: the API returns a relative path (`/j/<code>`);
  /// join it onto the configured server URL so copied links open anywhere.
  String? absoluteInviteUrl(String baseUrl) {
    final u = inviteUrl;
    if (u == null || u.isEmpty) return null;
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
    final base = baseUrl.trim();
    if (base.isEmpty) return u;
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return u.startsWith('/') ? '$b$u' : '$b/$u';
  }
}
