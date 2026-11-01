import 'package:seekarr/core/utils/dynamic_map_utils.dart';

/// Tolerant model for a Wizarr library (Phase 2).
///
/// Follows the live Wizarr v3 `/api/swagger.json` shape:
/// {id, name, external_id, server_id, server_name, enabled}
class WizarrLibrary {
  final int? id;
  final String? name;
  final int? externalId;
  final int? serverId;
  final String? serverName;
  final bool? enabled;

  const WizarrLibrary({
    this.id,
    this.name,
    this.externalId,
    this.serverId,
    this.serverName,
    this.enabled,
  });

  /// Tolerant fromJson that accepts camelCase and snake_case variants.
  factory WizarrLibrary.fromJson(Map<String, dynamic> json) {
    return WizarrLibrary(
      id: intOrNull(json['id']),
      name: stringOrNull(json['name']),
      externalId: intOrNull(json['external_id'] ?? json['externalId']),
      serverId: intOrNull(json['server_id'] ?? json['serverId']),
      serverName: stringOrNull(json['server_name'] ?? json['serverName']),
      enabled: boolOrNull(json['enabled']),
    );
  }

  /// Whether this library is enabled (true or absent).
  bool get isEnabled => enabled == null || enabled!;
}
