import 'package:flutter/material.dart' show ThemeMode;

import 'package:seekarr/features/settings/domain/service_key.dart';

enum AppThemeMode {
  system(label: 'System'),
  light(label: 'Light'),
  dark(label: 'Dark');

  const AppThemeMode({required this.label});

  final String label;

  static final Map<String, AppThemeMode> _modesByName = {
    for (final mode in values) mode.name: mode,
  };

  ThemeMode get materialThemeMode {
    return switch (this) {
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
      AppThemeMode.system => ThemeMode.system,
    };
  }

  static AppThemeMode fromName(String? value) =>
      _modesByName[value] ?? AppThemeMode.system;
}

class SettingsModel {
  final String seerrUrl;
  final String seerrApiKey;
  final String radarrUrl;
  final String radarrApiKey;
  final String sonarrUrl;
  final String sonarrApiKey;
  final String lidarrUrl;
  final String lidarrApiKey;
  final String qbittorrentUrl;
  final String qbittorrentUsername;
  final String qbittorrentPassword;
  final String prowlarrUrl;
  final String prowlarrApiKey;
  final String bazarrUrl;
  final String bazarrApiKey;
  final String navidromeUrl;
  final String navidromeUsername;
  final String navidromePassword;
  final String soulsyncUrl;
  final String soulsyncApiKey;
  final String soulsyncProxyCookie;
  final String soulsyncProfileId;
  final String region;
  final AppThemeMode themeMode;
  final String oidcIssuer; // empty = disabled; plain URL-like field (NOT secret)
  final String oidcClientId; // default 'seekarr'
  final bool jailbroken; // iOS TrollStore install path (default off)

  static final Map<ServiceKey, _ServiceSettingsAccess> _serviceSettingsAccess =
      {
        ServiceKey.seerr: _ServiceSettingsAccess(
          url: (settings) => settings.seerrUrl,
          apiKey: (settings) => settings.seerrApiKey,
          update: (settings, {url, apiKey}) =>
              settings.copyWith(seerrUrl: url, seerrApiKey: apiKey),
        ),
        ServiceKey.radarr: _ServiceSettingsAccess(
          url: (settings) => settings.radarrUrl,
          apiKey: (settings) => settings.radarrApiKey,
          update: (settings, {url, apiKey}) =>
              settings.copyWith(radarrUrl: url, radarrApiKey: apiKey),
        ),
        ServiceKey.sonarr: _ServiceSettingsAccess(
          url: (settings) => settings.sonarrUrl,
          apiKey: (settings) => settings.sonarrApiKey,
          update: (settings, {url, apiKey}) =>
              settings.copyWith(sonarrUrl: url, sonarrApiKey: apiKey),
        ),
        ServiceKey.lidarr: _ServiceSettingsAccess(
          url: (settings) => settings.lidarrUrl,
          apiKey: (settings) => settings.lidarrApiKey,
          update: (settings, {url, apiKey}) =>
              settings.copyWith(lidarrUrl: url, lidarrApiKey: apiKey),
        ),
        ServiceKey.qbittorrent: _ServiceSettingsAccess(
          url: (settings) => settings.qbittorrentUrl,
          apiKey: (settings) => settings.qbittorrentPassword,
          update: (settings, {url, apiKey}) => settings.copyWith(
            qbittorrentUrl: url,
            qbittorrentPassword: apiKey,
          ),
        ),
        ServiceKey.prowlarr: _ServiceSettingsAccess(
          url: (settings) => settings.prowlarrUrl,
          apiKey: (settings) => settings.prowlarrApiKey,
          update: (settings, {url, apiKey}) =>
              settings.copyWith(prowlarrUrl: url, prowlarrApiKey: apiKey),
        ),
        ServiceKey.bazarr: _ServiceSettingsAccess(
          url: (settings) => settings.bazarrUrl,
          apiKey: (settings) => settings.bazarrApiKey,
          update: (settings, {url, apiKey}) =>
              settings.copyWith(bazarrUrl: url, bazarrApiKey: apiKey),
        ),
        ServiceKey.navidrome: _ServiceSettingsAccess(
          url: (settings) => settings.navidromeUrl,
          apiKey: (settings) => settings.navidromePassword,
          update: (settings, {url, apiKey}) => settings.copyWith(
            navidromeUrl: url,
            navidromePassword: apiKey,
          ),
        ),
        ServiceKey.soulsync: _ServiceSettingsAccess(
          url: (settings) => settings.soulsyncUrl,
          apiKey: (settings) => settings.soulsyncApiKey,
          update: (settings, {url, apiKey}) => settings.copyWith(
            soulsyncUrl: url,
            soulsyncApiKey: apiKey,
          ),
        ),
        // Note: soulsyncProxyCookie handled separately (secure store, not
        // in _ServiceSettingsAccess) to keep cookie out of the generic
        // apiKey path — it flows through SoulSyncAuth directly.
      };

  static String normalizeRegion(String? region) {
    final normalized = region?.trim().toUpperCase() ?? '';
    return normalized.isEmpty ? 'US' : normalized;
  }

  const SettingsModel({
    this.seerrUrl = '',
    this.seerrApiKey = '',
    this.radarrUrl = '',
    this.radarrApiKey = '',
    this.sonarrUrl = '',
    this.sonarrApiKey = '',
    this.lidarrUrl = '',
    this.lidarrApiKey = '',
    this.qbittorrentUrl = '',
    this.qbittorrentUsername = '',
    this.qbittorrentPassword = '',
    this.prowlarrUrl = '',
    this.prowlarrApiKey = '',
    this.bazarrUrl = '',
    this.bazarrApiKey = '',
    this.navidromeUrl = '',
    this.navidromeUsername = '',
    this.navidromePassword = '',
    this.soulsyncUrl = '',
    this.soulsyncApiKey = '',
    this.soulsyncProxyCookie = '',
    this.soulsyncProfileId = '',
    this.region = 'US',
    this.themeMode = AppThemeMode.system,
    this.oidcIssuer = '',
    this.oidcClientId = 'seekarr',
    this.jailbroken = false,
  });

  SettingsModel copyWith({
    String? seerrUrl,
    String? seerrApiKey,
    String? radarrUrl,
    String? radarrApiKey,
    String? sonarrUrl,
    String? sonarrApiKey,
    String? lidarrUrl,
    String? lidarrApiKey,
    String? qbittorrentUrl,
    String? qbittorrentUsername,
    String? qbittorrentPassword,
    String? prowlarrUrl,
    String? prowlarrApiKey,
    String? bazarrUrl,
    String? bazarrApiKey,
    String? navidromeUrl,
    String? navidromeUsername,
    String? navidromePassword,
    String? soulsyncUrl,
    String? soulsyncApiKey,
    String? soulsyncProxyCookie,
    String? soulsyncProfileId,
    String? region,
    AppThemeMode? themeMode,
    String? oidcIssuer,
    String? oidcClientId,
    bool? jailbroken,
  }) {
    return SettingsModel(
      seerrUrl: seerrUrl ?? this.seerrUrl,
      seerrApiKey: seerrApiKey ?? this.seerrApiKey,
      radarrUrl: radarrUrl ?? this.radarrUrl,
      radarrApiKey: radarrApiKey ?? this.radarrApiKey,
      sonarrUrl: sonarrUrl ?? this.sonarrUrl,
      sonarrApiKey: sonarrApiKey ?? this.sonarrApiKey,
      lidarrUrl: lidarrUrl ?? this.lidarrUrl,
      lidarrApiKey: lidarrApiKey ?? this.lidarrApiKey,
      qbittorrentUrl: qbittorrentUrl ?? this.qbittorrentUrl,
      qbittorrentUsername: qbittorrentUsername ?? this.qbittorrentUsername,
      qbittorrentPassword: qbittorrentPassword ?? this.qbittorrentPassword,
      prowlarrUrl: prowlarrUrl ?? this.prowlarrUrl,
      prowlarrApiKey: prowlarrApiKey ?? this.prowlarrApiKey,
      bazarrUrl: bazarrUrl ?? this.bazarrUrl,
      bazarrApiKey: bazarrApiKey ?? this.bazarrApiKey,
      navidromeUrl: navidromeUrl ?? this.navidromeUrl,
      navidromeUsername: navidromeUsername ?? this.navidromeUsername,
      navidromePassword: navidromePassword ?? this.navidromePassword,
      soulsyncUrl: soulsyncUrl ?? this.soulsyncUrl,
      soulsyncApiKey: soulsyncApiKey ?? this.soulsyncApiKey,
      soulsyncProxyCookie: soulsyncProxyCookie ?? this.soulsyncProxyCookie,
      soulsyncProfileId: soulsyncProfileId ?? this.soulsyncProfileId,
      region: region ?? this.region,
      themeMode: themeMode ?? this.themeMode,
      oidcIssuer: oidcIssuer ?? this.oidcIssuer,
      oidcClientId: oidcClientId ?? this.oidcClientId,
      jailbroken: jailbroken ?? this.jailbroken,
    );
  }

  ThemeMode get resolvedThemeMode => themeMode.materialThemeMode;

  _ServiceSettingsAccess _serviceAccessFor(ServiceKey service) {
    return _serviceSettingsAccess[service]!;
  }

  /// Returns the URL configured for [service].
  String urlFor(ServiceKey service) {
    return _serviceAccessFor(service).url(this);
  }

  /// Returns the API key configured for [service].
  String apiKeyFor(ServiceKey service) {
    return _serviceAccessFor(service).apiKey(this);
  }

  /// Returns a copy with the URL and/or API key updated for [service].
  SettingsModel copyWithService(
    ServiceKey service, {
    String? url,
    String? apiKey,
  }) {
    return _serviceAccessFor(service).update(this, url: url, apiKey: apiKey);
  }

  SettingsModel copyWithQbittorrent({
    String? url,
    String? username,
    String? password,
  }) {
    return copyWith(
      qbittorrentUrl: url,
      qbittorrentUsername: username,
      qbittorrentPassword: password,
    );
  }

  SettingsModel copyWithProwlarr({
    String? url,
    String? apiKey,
  }) {
    return copyWith(
      prowlarrUrl: url,
      prowlarrApiKey: apiKey,
    );
  }

  SettingsModel copyWithNavidrome({
    String? url,
    String? username,
    String? password,
  }) {
    return copyWith(
      navidromeUrl: url,
      navidromeUsername: username,
      navidromePassword: password,
    );
  }

  SettingsModel copyWithSoulSync({
    String? url,
    String? apiKey,
    String? proxyCookie,
    String? profileId,
  }) {
    return copyWith(
      soulsyncUrl: url,
      soulsyncApiKey: apiKey,
      soulsyncProxyCookie: proxyCookie,
      soulsyncProfileId: profileId,
    );
  }

  String usernameFor(ServiceKey service) {
    if (service == ServiceKey.qbittorrent) return qbittorrentUsername;
    if (service == ServiceKey.navidrome) return navidromeUsername;
    return '';
  }

  String passwordFor(ServiceKey service) {
    if (service == ServiceKey.qbittorrent) return qbittorrentPassword;
    if (service == ServiceKey.prowlarr) return prowlarrApiKey;
    if (service == ServiceKey.navidrome) return navidromePassword;
    return '';
  }

  bool isServiceConfigured(ServiceKey service) {
    if (service == ServiceKey.qbittorrent) {
      return qbittorrentUrl.isNotEmpty;
    }
    if (service == ServiceKey.prowlarr) {
      return prowlarrUrl.isNotEmpty &&
          (prowlarrApiKey.isNotEmpty || _isArrstackMode);
    }
    if (service == ServiceKey.navidrome) {
      return navidromeUrl.isNotEmpty &&
          navidromeUsername.isNotEmpty &&
          navidromePassword.isNotEmpty;
    }
    if (service == ServiceKey.sonarr) {
      // Sonarr provider runs URL-only whenever any OIDC issuer is set
      // (per-service pair or the shared ArrStack pair); the interceptor
      // mints the service token lazily on 401.
      return sonarrUrl.isNotEmpty &&
          (sonarrApiKey.isNotEmpty || oidcIssuer.isNotEmpty);
    }
    if (service == ServiceKey.radarr) {
      // Radarr provider runs URL-only in ArrStack mode only.
      return radarrUrl.isNotEmpty &&
          (radarrApiKey.isNotEmpty || _isArrstackMode);
    }
    if (service == ServiceKey.soulsync) {
      return soulsyncUrl.isNotEmpty &&
          (soulsyncApiKey.isNotEmpty || soulsyncProxyCookie.isNotEmpty);
    }
    return urlFor(service).isNotEmpty && apiKeyFor(service).isNotEmpty;
  }

  /// Same definition as `OidcSessionService.isArrstackMode`, kept local so
  /// the domain model does not depend on the auth data layer (which would
  /// close an import cycle via settings_service).
  bool get _isArrstackMode {
    final trimmed = oidcIssuer.trim().replaceAll(RegExp(r'/+$'), '');
    return trimmed.endsWith('/o/arrstack');
  }
}

class _ServiceSettingsAccess {
  final String Function(SettingsModel settings) url;
  final String Function(SettingsModel settings) apiKey;
  final SettingsModel Function(
    SettingsModel settings, {
    String? url,
    String? apiKey,
  })
  update;

  const _ServiceSettingsAccess({
    required this.url,
    required this.apiKey,
    required this.update,
  });
}
