import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seekarr/core/api/api_client.dart';
import 'package:seekarr/core/api/service_auth.dart';
import 'package:seekarr/features/qbittorrent/data/qbittorrent_client.dart';
import 'package:seekarr/features/settings/data/settings_provider.dart';
import 'package:seekarr/features/settings/domain/service_key.dart';
import 'package:seekarr/features/settings/domain/settings_model.dart';

/// Represents the reachability state of a configured service.
enum ServiceConnectionStatus {
  notConfigured,
  checking,
  connected,
  disconnected,
}

/// Returns the health-check endpoint path for [service].
String _healthEndpoint(ServiceKey service) {
  switch (service) {
    case ServiceKey.seerr:
      return '/api/v1/status';
    case ServiceKey.radarr:
    case ServiceKey.sonarr:
      return '/api/v3/system/status';
    case ServiceKey.lidarr:
      return '/api/v1/system/status';
    case ServiceKey.qbittorrent:
      return '/api/v2/app/version';
    case ServiceKey.prowlarr:
      return '/api/v1/system/status';
    case ServiceKey.bazarr:
      return '/api/system/status';
    case ServiceKey.navidrome:
      return '/rest/ping.view';
  }
}

/// Pings [service] using the currently configured URL and API key.
///
/// Returns [ServiceConnectionStatus.notConfigured] when URL or API key are
/// missing, [ServiceConnectionStatus.connected] on a 2xx response, otherwise
/// [ServiceConnectionStatus.disconnected]. A 5s timeout is applied to avoid
/// blocking the UI.
Future<ServiceConnectionStatus> _checkService(
  ServiceKey service,
  SettingsModel settings,
) async {
  if (!settings.isServiceConfigured(service)) {
    return ServiceConnectionStatus.notConfigured;
  }

  if (service == ServiceKey.qbittorrent) {
    final client = QbittorrentClient(
      url: settings.qbittorrentUrl,
      username: settings.qbittorrentUsername,
      password: settings.qbittorrentPassword,
    );
    try {
      await client.authenticate().timeout(const Duration(seconds: 5));
      await client.getVersion().timeout(const Duration(seconds: 5));
      return ServiceConnectionStatus.connected;
    } catch (_) {
      return ServiceConnectionStatus.disconnected;
    } finally {
      client.close();
    }
  }

  if (service == ServiceKey.navidrome) {
    final client = ApiClient(
      baseUrl: settings.navidromeUrl,
      auth: SubsonicAuth(settings.navidromeUsername, settings.navidromePassword),
    );
    try {
      final statusCode =
          (await client
                  .get('/rest/ping.view')
                  .timeout(const Duration(seconds: 5)))
              .statusCode ??
          0;
      return statusCode >= 200 && statusCode < 300
          ? ServiceConnectionStatus.connected
          : ServiceConnectionStatus.disconnected;
    } catch (_) {
      return ServiceConnectionStatus.disconnected;
    } finally {
      client.close();
    }
  }

  final url = settings.urlFor(service);
  final apiKey = settings.apiKeyFor(service);

  final client = ApiClient(baseUrl: url, auth: ApiKeyHeaderAuth(apiKey));
  try {
    final statusCode =
        (await client
                .get(_healthEndpoint(service))
                .timeout(const Duration(seconds: 5)))
            .statusCode ??
        0;
    return statusCode >= 200 && statusCode < 300
        ? ServiceConnectionStatus.connected
        : ServiceConnectionStatus.disconnected;
  } catch (_) {
    return ServiceConnectionStatus.disconnected;
  } finally {
    client.close();
  }
}

/// Provides the connection status for a specific [ServiceKey].
///
/// Auto-invalidates whenever the URL or API key for the service changes via
/// [currentSettingsProvider], ensuring the indicator refreshes after the user
/// edits service settings.
final serviceConnectionProvider =
    FutureProvider.family<ServiceConnectionStatus, ServiceKey>((
      ref,
      service,
    ) async {
      final settings = ref.watch(currentSettingsProvider);
      return _checkService(service, settings);
    });

/// Performs the same health check as [_checkService] but surfaces a
/// human-readable [detail] describing the failure.
///
/// [detail] is `HTTP <code>` for a non-2xx response, or
/// `<ExceptionType>: <message>` (truncated to 140 chars) on error. Secrets
/// and credential-bearing URLs are redacted from the message.
Future<({bool ok, String detail})> testServiceConnection(
  ServiceKey service,
  SettingsModel settings,
) async {
  if (!settings.isServiceConfigured(service)) {
    return (ok: false, detail: 'Not configured');
  }

  if (service == ServiceKey.qbittorrent) {
    final client = QbittorrentClient(
      url: settings.qbittorrentUrl,
      username: settings.qbittorrentUsername,
      password: settings.qbittorrentPassword,
    );
    try {
      await client.authenticate().timeout(const Duration(seconds: 5));
      await client.getVersion().timeout(const Duration(seconds: 5));
      return (ok: true, detail: '');
    } catch (e) {
      final code = _httpStatusCode(e);
      if (code != null) {
        return (ok: false, detail: 'HTTP $code');
      }
      return (ok: false, detail: _errorDetail(e, settings, service));
    } finally {
      client.close();
    }
  }

  if (service == ServiceKey.navidrome) {
    final client = ApiClient(
      baseUrl: settings.navidromeUrl,
      auth: SubsonicAuth(settings.navidromeUsername, settings.navidromePassword),
    );
    try {
      final response = await client
          .get('/rest/ping.view')
          .timeout(const Duration(seconds: 5));
      final statusCode = response.statusCode ?? 0;
      if (statusCode >= 200 && statusCode < 300) {
        return (ok: true, detail: '');
      }
      return (ok: false, detail: 'HTTP $statusCode');
    } catch (e) {
      final code = _httpStatusCode(e);
      if (code != null) {
        return (ok: false, detail: 'HTTP $code');
      }
      return (ok: false, detail: _errorDetail(e, settings, service));
    } finally {
      client.close();
    }
  }

  final url = settings.urlFor(service);
  final apiKey = settings.apiKeyFor(service);

  final client = ApiClient(baseUrl: url, auth: ApiKeyHeaderAuth(apiKey));
  try {
    final response = await client
        .get(_healthEndpoint(service))
        .timeout(const Duration(seconds: 5));
    final statusCode = response.statusCode ?? 0;
    if (statusCode >= 200 && statusCode < 300) {
      return (ok: true, detail: '');
    }
    return (ok: false, detail: 'HTTP $statusCode');
  } catch (e) {
    final code = _httpStatusCode(e);
    if (code != null) {
      return (ok: false, detail: 'HTTP $code');
    }
    return (ok: false, detail: _errorDetail(e, settings, service));
  } finally {
    client.close();
  }
}

int? _httpStatusCode(Object e) {
  if (e is DioException) {
    return e.response?.statusCode;
  }
  return null;
}

String _errorDetail(Object e, SettingsModel settings, ServiceKey service) {
  final type = e.runtimeType.toString();
  var message = _messageOf(e);
  message = _scrub(message, settings, service);
  final combined = '$type: $message';
  return combined.length <= 140 ? combined : combined.substring(0, 140);
}

String _messageOf(Object e) {
  if (e is DioException) {
    return e.message ?? e.toString();
  }
  if (e is TimeoutException) {
    return e.message ?? e.toString();
  }
  final s = e.toString();
  final prefix = '${e.runtimeType}: ';
  if (s.startsWith(prefix)) {
    return s.substring(prefix.length);
  }
  return s;
}

String _scrub(String text, SettingsModel settings, ServiceKey service) {
  var out = text;
  final secrets = <String>[];
  if (service == ServiceKey.qbittorrent) {
    secrets.addAll([
      settings.qbittorrentUrl,
      settings.qbittorrentUsername,
      settings.qbittorrentPassword,
    ]);
  } else if (service == ServiceKey.navidrome) {
    secrets.addAll([
      settings.navidromeUrl,
      settings.navidromeUsername,
      settings.navidromePassword,
    ]);
  } else {
    secrets.addAll([settings.urlFor(service), settings.apiKeyFor(service)]);
  }
  for (final secret in secrets) {
    if (secret.isNotEmpty) {
      out = out.replaceAll(secret, '[redacted]');
    }
  }
  return out;
}
