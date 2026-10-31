import 'package:seekarr/core/utils/dynamic_map_utils.dart';

/// Tolerant model for a Wizarr invitation (read-only v1).
class WizarrInvitation {
  final String? code;
  final String? inviteUrl;
  final String? server;
  final String? serverType;
  final int? maxUses;
  final int? usedCount;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  const WizarrInvitation({
    this.code,
    this.inviteUrl,
    this.server,
    this.serverType,
    this.maxUses,
    this.usedCount,
    this.expiresAt,
    this.createdAt,
  });

  factory WizarrInvitation.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString().trim());
    }

    // Tolerate both camelCase and snake_case (and a few live-API aliases).
    final code = stringOrNull(json['code'] ?? json['id']?.toString());
    final inviteUrl = stringOrNull(
      json['inviteUrl'] ??
          json['invite_url'] ??
          json['url'] ??
          json['link'],
    );
    final server = stringOrNull(
      json['server'] ??
          json['displayName'] ??
          json['display_name'] ??
          json['serverName'] ??
          json['server_name'],
    );
    final serverType = stringOrNull(
      json['serverType'] ?? json['server_type'],
    );
    final maxUses = intOrNull(
      json['maxUses'] ??
          json['max_uses'] ??
          json['maxUsesTotal'] ??
          json['uses'],
    );
    final usedCount = intOrNull(
      json['usedCount'] ??
          json['used_count'] ??
          json['used'] ??
          json['usedBy'] ??
          json['used_by'],
    );
    final expiresAt = parseDate(
      json['expiresAt'] ?? json['expires_at'] ?? json['expires'],
    );
    final createdAt = parseDate(
      json['createdAt'] ?? json['created_at'] ?? json['created'],
    );

    return WizarrInvitation(
      code: code,
      inviteUrl: inviteUrl,
      server: server,
      serverType: serverType,
      maxUses: maxUses,
      usedCount: usedCount,
      expiresAt: expiresAt,
      createdAt: createdAt,
    );
  }

  int? get usesLeft {
    if (maxUses == null || maxUses! <= 0) return null;
    final used = usedCount ?? 0;
    final left = maxUses! - used;
    return left < 0 ? 0 : left;
  }

  bool get isExpired {
    final e = expiresAt;
    if (e == null) return false;
    return e.isBefore(DateTime.now());
  }

  bool get isExhausted {
    if (maxUses == null || maxUses! <= 0) return false;
    return (usedCount ?? 0) >= maxUses!;
  }

  String get statusLabel {
    if (isExpired) return 'Expired';
    if (isExhausted) return 'Used up';
    return 'Active';
  }
}
