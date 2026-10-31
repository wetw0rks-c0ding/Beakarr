import 'package:flutter/material.dart';

import 'package:seekarr/core/theme.dart';

enum ServiceKey {
  seerr,
  radarr,
  sonarr,
  lidarr,
  qbittorrent,
  prowlarr,
  bazarr,
  navidrome,
  soulsync,
  nzbget,
  npm,
  openmediavault,
  wizarr,
}

/// How [ServiceKey] collects credentials. Replaces the hand-rolled
/// `service == qbittorrent || service == navidrome` chains so new
/// credential services only touch this enum.
enum ServiceCredentialKind { apiKey, usernamePassword, emailPassword }

extension ServiceKeyExtension on ServiceKey {
  String get title {
    switch (this) {
      case ServiceKey.seerr:
        return 'Seerr';
      case ServiceKey.radarr:
        return 'Radarr';
      case ServiceKey.sonarr:
        return 'Sonarr';
      case ServiceKey.lidarr:
        return 'Lidarr';
      case ServiceKey.qbittorrent:
        return 'qBittorrent';
      case ServiceKey.nzbget:
        return 'NZBGet';
      case ServiceKey.npm:
        // Short title: the dashboard app bar has no ellipsis and the
        // full "Nginx Proxy Manager" overflows at 360 dp.
        return 'Nginx PM';
      case ServiceKey.openmediavault:
        return 'OpenMediaVault';
      case ServiceKey.wizarr:
        return 'Wizarr';
      case ServiceKey.prowlarr:
        return 'Prowlarr';
      case ServiceKey.bazarr:
        return 'Bazarr';
      case ServiceKey.navidrome:
        return 'Navidrome';
      case ServiceKey.soulsync:
        return 'SoulSync';
    }
  }

  IconData get icon {
    switch (this) {
      case ServiceKey.seerr:
        return Icons.search_rounded;
      case ServiceKey.radarr:
        return Icons.movie_rounded;
      case ServiceKey.sonarr:
        return Icons.tv_rounded;
      case ServiceKey.lidarr:
        return Icons.music_note_rounded;
      case ServiceKey.qbittorrent:
        return Icons.download_rounded;
      case ServiceKey.nzbget:
        return Icons.cloud_download_rounded;
      case ServiceKey.npm:
        return Icons.router_rounded;
      case ServiceKey.openmediavault:
        return Icons.storage_rounded;
      case ServiceKey.wizarr:
        return Icons.mail_rounded;
      case ServiceKey.prowlarr:
        return Icons.dns_rounded;
      case ServiceKey.bazarr:
        return Icons.closed_caption_rounded;
      case ServiceKey.navidrome:
        return Icons.library_music_rounded;
      case ServiceKey.soulsync:
        return Icons.sync_rounded;
    }
  }

  Color get accent {
    switch (this) {
      case ServiceKey.seerr:
        return AppColors.seerr;
      case ServiceKey.radarr:
        return AppColors.radarr;
      case ServiceKey.sonarr:
        return AppColors.sonarr;
      case ServiceKey.lidarr:
        return AppColors.lidarr;
      case ServiceKey.qbittorrent:
        return AppColors.qbittorrent;
      case ServiceKey.nzbget:
        return AppColors.nzbget;
      case ServiceKey.npm:
        return AppColors.npm;
      case ServiceKey.openmediavault:
        return AppColors.openmediavault;
      case ServiceKey.wizarr:
        return AppColors.wizarr;
      case ServiceKey.prowlarr:
        return AppColors.prowlarr;
      case ServiceKey.bazarr:
        return AppColors.bazarr;
      case ServiceKey.navidrome:
        return AppColors.navidrome;
      case ServiceKey.soulsync:
        return AppColors.soulsync;
    }
  }

  bool get usesApiKey {
    return credentialKind == ServiceCredentialKind.apiKey;
  }

  /// Which credential shape this service collects.
  ServiceCredentialKind get credentialKind => switch (this) {
    ServiceKey.qbittorrent ||
    ServiceKey.navidrome ||
    ServiceKey.nzbget ||
    ServiceKey.openmediavault => ServiceCredentialKind.usernamePassword,
    ServiceKey.npm => ServiceCredentialKind.emailPassword,
    _ => ServiceCredentialKind.apiKey,
  };

  /// Label for the username slot. NPM signs in with an email identity.
  String get usernameLabel => switch (this) {
    ServiceKey.openmediavault => 'Username (admin)',
    _ => switch (credentialKind) {
      ServiceCredentialKind.emailPassword => 'Email',
      _ => 'Username',
    },
  };

  /// Whether the username/email field must be non-empty. qBittorrent
  /// allows anonymous instances; every other credential service requires
  /// both fields.
  bool get requiresUsername =>
      credentialKind != ServiceCredentialKind.apiKey &&
      this != ServiceKey.qbittorrent;

  bool get requiresPassword => requiresUsername;

  bool get isSearchable {
    return this != ServiceKey.qbittorrent &&
        this != ServiceKey.navidrome &&
        this != ServiceKey.nzbget &&
        this != ServiceKey.npm &&
        this != ServiceKey.openmediavault &&
        this != ServiceKey.wizarr;
  }

  bool get supportsManualImport {
    return this == ServiceKey.radarr ||
        this == ServiceKey.sonarr ||
        this == ServiceKey.lidarr;
  }

  String get apiVersion {
    switch (this) {
      case ServiceKey.seerr:
      case ServiceKey.lidarr:
      case ServiceKey.prowlarr:
      case ServiceKey.soulsync:
        return 'v1';
      case ServiceKey.bazarr:
      case ServiceKey.navidrome:
        return '';
      case ServiceKey.radarr:
      case ServiceKey.sonarr:
        return 'v3';
      case ServiceKey.qbittorrent:
        return 'WebUI';
      case ServiceKey.nzbget:
        return 'JSON-RPC';
      case ServiceKey.npm:
        return 'REST';
      case ServiceKey.openmediavault:
        return 'RPC';
      case ServiceKey.wizarr:
        return 'REST';
    }
  }

  String get itemLabel {
    switch (this) {
      case ServiceKey.seerr:
        return 'requests';
      case ServiceKey.radarr:
        return 'movies';
      case ServiceKey.sonarr:
        return 'series';
      case ServiceKey.lidarr:
        return 'artists';
      case ServiceKey.qbittorrent:
        return 'torrents';
      case ServiceKey.nzbget:
        return 'downloads';
      case ServiceKey.npm:
        return 'proxy hosts';
      case ServiceKey.openmediavault:
        return 'disks';
      case ServiceKey.wizarr:
        return 'invitations';
      case ServiceKey.prowlarr:
        return 'indexers';
      case ServiceKey.bazarr:
        return 'subtitles';
      case ServiceKey.navidrome:
        return 'artists';
      case ServiceKey.soulsync:
        return 'wishlist';
    }
  }

  String get routeParam {
    switch (this) {
      case ServiceKey.seerr:
        return 'seerr';
      case ServiceKey.radarr:
      case ServiceKey.sonarr:
      case ServiceKey.lidarr:
      case ServiceKey.qbittorrent:
      case ServiceKey.prowlarr:
      case ServiceKey.bazarr:
      case ServiceKey.navidrome:
      case ServiceKey.soulsync:
      case ServiceKey.nzbget:
      case ServiceKey.npm:
      case ServiceKey.openmediavault:
      case ServiceKey.wizarr:
        return name;
    }
  }

  String? extractHost(String? url) {
    final value = url?.trim() ?? '';
    if (value.isEmpty) return null;
    final parseableValue = value.contains('://') ? value : 'http://$value';

    try {
      final uri = Uri.parse(parseableValue);
      if (uri.host.isNotEmpty) {
        return uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
      }

      return uri.path.isEmpty ? null : uri.path;
    } catch (_) {
      return null;
    }
  }
}
