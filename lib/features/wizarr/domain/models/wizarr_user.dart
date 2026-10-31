import 'package:seekarr/core/utils/dynamic_map_utils.dart';

/// Tolerant model for a Wizarr-managed user (read-only v1).
class WizarrUser {
  final String? username;
  final String? server;
  final String? serverType;
  final String? email;
  final DateTime? lastActiveAt;

  const WizarrUser({
    this.username,
    this.server,
    this.serverType,
    this.email,
    this.lastActiveAt,
  });

  factory WizarrUser.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString().trim());
    }

    return WizarrUser(
      username: stringOrNull(json['username'] ?? json['name'] ?? json['user']),
      server: stringOrNull(
        json['server'] ?? json['serverName'] ?? json['server_name'],
      ),
      serverType: stringOrNull(
        json['serverType'] ?? json['server_type'],
      ),
      email: stringOrNull(json['email']),
      lastActiveAt: parseDate(
        json['lastActiveAt'] ??
            json['last_active_at'] ??
            json['lastActive'] ??
            json['last_seen'],
      ),
    );
  }
}
