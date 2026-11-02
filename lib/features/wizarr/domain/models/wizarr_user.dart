import 'package:seekarr/core/utils/dynamic_map_utils.dart';

/// Tolerant model for a Wizarr-managed user (read-only v1).
///
/// Field names follow the live Wizarr v3 `/api/swagger.json`
/// (`User`: id/username/email/server/server_type/expires/created_at).
class WizarrUser {
  final int? id;
  final String? username;
  final String? email;
  final String? server;
  final String? serverType;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  const WizarrUser({
    this.id,
    this.username,
    this.email,
    this.server,
    this.serverType,
    this.expiresAt,
    this.createdAt,
  });

  factory WizarrUser.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      final s = v.toString().trim();
      if (s.isEmpty) return null;
      return DateTime.tryParse(s);
    }

    return WizarrUser(
      id: intOrNull(json['id']),
      username: stringOrNull(json['username'] ?? json['name']),
      email: stringOrNull(json['email']),
      server: stringOrNull(json['server']),
      serverType: stringOrNull(json['serverType'] ?? json['server_type']),
      expiresAt: parseDate(json['expires']),
      createdAt: parseDate(
        json['createdAt'] ?? json['created_at'] ?? json['created'],
      ),
    );
  }
}
