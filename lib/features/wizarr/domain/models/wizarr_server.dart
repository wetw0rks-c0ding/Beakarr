import 'package:seekarr/core/utils/dynamic_map_utils.dart';

/// Tolerant model for a Wizarr server (Phase 2).
///
/// Live shape (`/api/swagger.json`) carries more fields (server_url,
/// external_url, verified, allow_*, created_at); only the UI-needed
/// subset is modeled, the rest is ignored.
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
