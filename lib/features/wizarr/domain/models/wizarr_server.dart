import 'package:seekarr/core/utils/dynamic_map_utils.dart';

/// Tolerant model for a Wizarr server (Phase 2).
///
/// Follows the live Wizarr v3 `/api/swagger.json` shape:
/// {id, name, server_type, server_url, external_url, verified,
/// allow_downloads, allow_live_tv, allow_mobile_uploads, created_at}
class WizarrServer {
  final int? id;
  final String? name;
  final String? serverType;

  const WizarrServer({
    this.id,
    this.name,
    this.serverType,
  });

  /// Tolerant fromJson that accepts camelCase and snake_case variants.
  factory WizarrServer.fromJson(Map<String, dynamic> json) {
    return WizarrServer(
      id: intOrNull(json['id']),
      name: stringOrNull(json['name']),
      serverType: stringOrNull(
        json['serverType'] ?? json['server_type'] ?? json['type'],
      ),
    );
  }
}
