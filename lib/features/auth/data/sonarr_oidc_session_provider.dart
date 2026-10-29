import 'dart:convert';
import 'package:flutter/foundation.dart';

/// In-memory model for Sonarr OIDC session per host.
class _HostSession {
  final String serviceToken;
  final List<String> permissions;
  final String role;
  final int expiresAtEpoch; // Unix timestamp in seconds

  _HostSession({
    required this.serviceToken,
    required this.permissions,
    required this.role,
    required this.expiresAtEpoch,
  });

  /// Check if session is still valid (not expired + buffer for 5 min TTL)
  bool isExpired() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final buffer = 300; // 5 minutes buffer
    return now >= expiresAtEpoch - buffer;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'serviceToken': serviceToken,
        'permissions': permissions,
        'role': role,
        'expiresAtEpoch': expiresAtEpoch,
      };

  factory _HostSession.fromJson(Map<String, dynamic> json) => _HostSession(
        serviceToken: json['serviceToken'] as String,
        permissions: (json['permissions'] as List<dynamic>).cast<String>(),
        role: json['role'] as String,
        expiresAtEpoch: json['expiresAtEpoch'] as int,
      );
}

/// In-memory Map<String, _HostSession> keyed by base URL.
/// 
/// This provider manages the cached Sonarr service tokens and permissions
/// per host. Tokens are cached until expiry - 5 minutes buffer.
class SonarrOidcSessionProvider {
  static final Map<String, _HostSession> _cache = <String, _HostSession>{};

  /// Update cache with new session data from /api/auth/oidc/exchange response
  /// and /api/auth/me call. Must be called atomically.
  static Future<void> update(String baseUrl, dynamic exchangeResponse) async {
    if (exchangeResponse == null || exchangeResponse is! Map<String, dynamic>) {
      debugPrint('SonarrOidcSessionProvider: exchangeResponse is null or invalid');
      return;
    }

    final token = exchangeResponse['token'] as String?;
    final permissions = (exchangeResponse['permissions'] as List<dynamic>?)?.cast<String>() ?? <String>[];
    final role = exchangeResponse['role'] as String? ?? 'ReadOnly';
    final expiresIn = exchangeResponse['expires_in'] as int? ?? 300;

    if (token == null || token.isEmpty) {
      debugPrint('SonarrOidcSessionProvider: No service token in response');
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final expiresAtEpoch = now + expiresIn;

    final session = _HostSession(
      serviceToken: token,
      permissions: permissions,
      role: role,
      expiresAtEpoch: expiresAtEpoch,
    );

    _cache[baseUrl] = session;
    
    if (kDebugMode) {
      debugPrint('SonarrOidcSessionProvider: Cached session for $baseUrl'
          ' - role: $role, permissions: ${permissions.join(", ")}, expiresAtEpoch: $expiresAtEpoch');
    }
  }

  /// Get cached session for a host URL. Returns null if no valid cache or expired.
  static _HostSession? getSonarrSession(String baseUrl) {
    final raw = _cache[baseUrl];
    if (raw == null) return null;
    
    // Check if expired (including 5 minute buffer)
    if (raw.isExpired()) {
      debugPrint('SonarrOidcSessionProvider: Session expired for $baseUrl');
      _cache.remove(baseUrl);
      return null;
    }

    return raw;
  }

  /// Clear cache for a specific host or all hosts.
  static void clear(String? baseUrl) {
    if (baseUrl != null && baseUrl.isNotEmpty) {
      _cache.remove(baseUrl);
    } else {
      _cache.clear();
    }
    
    if (kDebugMode) {
      debugPrint('SonarrOidcSessionProvider: Cleared cache${baseUrl == null ? " completely" : " for $baseUrl"}');
    }
  }

  /// Check if there's a valid cached session for the host.
  static bool hasValidSession(String baseUrl) {
    return getSonarrSession(baseUrl) != null;
  }

  /// Get permissions from cache, returns empty list if no valid session.
  static List<String> getPermissions(String baseUrl) {
    final session = getSonarrSession(baseUrl);
    if (session == null) {
      debugPrint('SonarrOidcSessionProvider: No valid session for $baseUrl');
      return <String>[];
    }
    return session.permissions;
  }

  /// Get role from cache. Returns 'ReadOnly' if no valid session.
  static String getRole(String baseUrl) {
    final session = getSonarrSession(baseUrl);
    if (session == null) return 'ReadOnly';
    return session.role;
  }

  /// Clear all cached sessions.
  static void clearAll() => clear(null);

  /// All cached hosts (keys only, for Riverpod sync).
  static List<String> get cachedHostKeys => _cache.keys.toList();

  /// Get number of cached hosts.
  static int getCachedHostCount() => _cache.length;
}
