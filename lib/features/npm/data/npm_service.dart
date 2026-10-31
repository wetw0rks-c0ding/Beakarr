import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seekarr/core/utils/dynamic_map_utils.dart';
import 'package:seekarr/features/npm/data/npm_client.dart';
import 'package:seekarr/features/npm/domain/models/npm_certificate.dart';
import 'package:seekarr/features/npm/domain/models/npm_proxy_host.dart';
import 'package:seekarr/features/settings/data/settings_provider.dart';

final npmServiceProvider = Provider<NpmService>((ref) {
  final settings = ref.watch(currentSettingsProvider);
  if (settings.npmUrl.isEmpty ||
      settings.npmIdentity.isEmpty ||
      settings.npmPassword.isEmpty) {
    throw Exception('Nginx Proxy Manager not configured');
  }
  final client = NpmClient(
    url: settings.npmUrl,
    identity: settings.npmIdentity,
    password: settings.npmPassword,
  );
  ref.onDispose(client.close);
  return NpmService(client);
});

/// Read-only endpoint layer over [NpmClient].
///
/// Enable/disable and renew are deliberately absent: they are mutating calls
/// (`PUT /api/nginx/proxy-hosts/{id}`, `POST /api/nginx/certificates/{id}/renew`)
/// deferred past v1.
class NpmService {
  final NpmClient _client;

  /// Last certificate list fetched, used by [getCertificate] so the hosts tab
  /// can cross-link a `certificate_id` without a second round trip.
  List<NpmCertificate>? _lastCertificates;

  NpmService(this._client);

  /// Reachability + auth in one step (the token exchange).
  Future<void> ping() => _client.ensureAuthenticated();

  Future<List<NpmProxyHost>> getProxyHosts() async {
    final response = await _client.get<dynamic>(
      '/api/nginx/proxy-hosts',
      query: const {'expand': 'certificate'},
    );
    return _items(response.data, NpmProxyHost.fromJson);
  }

  Future<List<NpmCertificate>> getCertificates() async {
    final response = await _client.get<dynamic>('/api/nginx/certificates');
    final certificates = _items(response.data, NpmCertificate.fromJson);
    _lastCertificates = certificates;
    return certificates;
  }

  /// Looks [id] up in [certificates] (or the last fetched list) — this never
  /// issues a request.
  NpmCertificate? getCertificate(int id, [List<NpmCertificate>? certificates]) {
    final pool = certificates ?? _lastCertificates;
    if (pool == null) return null;
    for (final certificate in pool) {
      if (certificate.id == id) return certificate;
    }
    return null;
  }

  /// Tolerant list parsing: an unexpected body (object, HTML error page, null)
  /// yields an empty list instead of crashing the tab.
  static List<T> _items<T>(
    dynamic data,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (data is! List) return const [];
    final items = <T>[];
    for (final item in data) {
      final map = mapOrNull(item);
      if (map != null) items.add(fromJson(map));
    }
    return items;
  }
}
