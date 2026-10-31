import 'package:flutter/material.dart' show Color, Icons, ThemeMode;
import 'package:flutter_test/flutter_test.dart';

import 'package:seekarr/features/settings/domain/nav_tab.dart';
import 'package:seekarr/features/settings/domain/service_key.dart';
import 'package:seekarr/features/settings/domain/settings_model.dart';

void main() {
  group('SettingsModel.urlFor', () {
    const settings = SettingsModel(
      seerrUrl: 'https://jelly.example.com',
      radarrUrl: 'https://radarr.example.com',
      sonarrUrl: 'https://sonarr.example.com',
      lidarrUrl: 'https://lidarr.example.com',
    );

    test('returns correct URL for each ServiceKey', () {
      expect(settings.urlFor(ServiceKey.seerr), 'https://jelly.example.com');
      expect(settings.urlFor(ServiceKey.radarr), 'https://radarr.example.com');
      expect(settings.urlFor(ServiceKey.sonarr), 'https://sonarr.example.com');
      expect(settings.urlFor(ServiceKey.lidarr), 'https://lidarr.example.com');
    });
  });

  group('SettingsModel.apiKeyFor', () {
    const settings = SettingsModel(
      seerrApiKey: 'jkey',
      radarrApiKey: 'rkey',
      sonarrApiKey: 'skey',
      lidarrApiKey: 'lkey',
    );

    test('returns correct API key for each ServiceKey', () {
      expect(settings.apiKeyFor(ServiceKey.seerr), 'jkey');
      expect(settings.apiKeyFor(ServiceKey.radarr), 'rkey');
      expect(settings.apiKeyFor(ServiceKey.sonarr), 'skey');
      expect(settings.apiKeyFor(ServiceKey.lidarr), 'lkey');
    });
  });

  group('SettingsModel.copyWithService', () {
    const base = SettingsModel();

    test('updates only the targeted service URL and API key', () {
      final updated = base.copyWithService(
        ServiceKey.radarr,
        url: 'https://new.radarr',
        apiKey: 'new-key',
      );

      expect(updated.radarrUrl, 'https://new.radarr');
      expect(updated.radarrApiKey, 'new-key');
      expect(updated.seerrUrl, '');
      expect(updated.sonarrUrl, '');
      expect(updated.lidarrUrl, '');
    });

    test('partial update only changes provided fields', () {
      final updated = base.copyWithService(
        ServiceKey.sonarr,
        url: 'https://sonarr.local',
      );

      expect(updated.sonarrUrl, 'https://sonarr.local');
      expect(updated.sonarrApiKey, '');
    });

    test('works for all four ServiceKey values', () {
      for (final key in ServiceKey.values) {
        final updated = base.copyWithService(key, url: 'https://test');
        expect(updated.urlFor(key), 'https://test');
      }
    });
  });

  group('SettingsModel.themeMode', () {
    test('defaults to system appearance and resolves to ThemeMode.system', () {
      const settings = SettingsModel();

      expect(settings.themeMode, AppThemeMode.system);
      expect(settings.resolvedThemeMode, ThemeMode.system);
    });

    test('resolves light and dark appearance modes', () {
      const lightSettings = SettingsModel(themeMode: AppThemeMode.light);
      const darkSettings = SettingsModel(themeMode: AppThemeMode.dark);

      expect(lightSettings.resolvedThemeMode, ThemeMode.light);
      expect(darkSettings.resolvedThemeMode, ThemeMode.dark);
    });
  });

  group('NavTab', () {
    test('matches the approved four-tab navigation model', () {
      expect(NavTab.values, [
        NavTab.services,
        NavTab.activity,
        NavTab.search,
        NavTab.settings,
      ]);
      expect(NavTab.values.map((tab) => tab.label), [
        'Services',
        'Activity',
        'Search',
        'Settings',
      ]);
      expect(NavTab.values.map((tab) => tab.accentColor), [
        const Color(0xFF6366F1),
        const Color(0xFFF59E0B),
        const Color(0xFF6366F1),
        const Color(0xFF9CA3AF),
      ]);
    });
  });

  group('ServiceKey.routeParam', () {
    test('uses stable route params including the Seerr rename', () {
      expect(ServiceKey.seerr.routeParam, 'seerr');
      expect(ServiceKey.radarr.routeParam, 'radarr');
      expect(ServiceKey.sonarr.routeParam, 'sonarr');
      expect(ServiceKey.lidarr.routeParam, 'lidarr');
    });
  });

  group('ServiceKey metadata', () {
    test('exposes prototype accent colors and icons', () {
      expect(ServiceKey.seerr.accent.toARGB32(), 0xFF6366F1);
      expect(ServiceKey.radarr.accent.toARGB32(), 0xFFF59E0B);
      expect(ServiceKey.sonarr.accent.toARGB32(), 0xFF8B5CF6);
      expect(ServiceKey.lidarr.accent.toARGB32(), 0xFFEC4899);
      expect(ServiceKey.seerr.icon, Icons.search_rounded);
      expect(ServiceKey.radarr.icon, Icons.movie_rounded);
      expect(ServiceKey.sonarr.icon, Icons.tv_rounded);
      expect(ServiceKey.lidarr.icon, Icons.music_note_rounded);
    });

    test('maps API versions per service', () {
      expect(ServiceKey.seerr.apiVersion, 'v1');
      expect(ServiceKey.radarr.apiVersion, 'v3');
      expect(ServiceKey.sonarr.apiVersion, 'v3');
      expect(ServiceKey.lidarr.apiVersion, 'v1');
    });

    test('maps summary item labels per service', () {
      expect(ServiceKey.seerr.itemLabel, 'requests');
      expect(ServiceKey.radarr.itemLabel, 'movies');
      expect(ServiceKey.sonarr.itemLabel, 'series');
      expect(ServiceKey.lidarr.itemLabel, 'artists');
    });

    test('classifies credential kinds per service', () {
      for (final service in [
        ServiceKey.seerr,
        ServiceKey.radarr,
        ServiceKey.sonarr,
        ServiceKey.lidarr,
        ServiceKey.prowlarr,
        ServiceKey.bazarr,
        ServiceKey.soulsync,
      ]) {
        expect(service.credentialKind, ServiceCredentialKind.apiKey);
        expect(service.usesApiKey, isTrue);
      }
      for (final service in [
        ServiceKey.qbittorrent,
        ServiceKey.navidrome,
        ServiceKey.nzbget,
      ]) {
        expect(
          service.credentialKind,
          ServiceCredentialKind.usernamePassword,
        );
        expect(service.usesApiKey, isFalse);
      }
      expect(ServiceKey.npm.credentialKind, ServiceCredentialKind.emailPassword);
      expect(ServiceKey.npm.usesApiKey, isFalse);
    });

    test('labels the username slot and gates required fields', () {
      expect(ServiceKey.npm.usernameLabel, 'Email');
      expect(ServiceKey.nzbget.usernameLabel, 'Username');
      expect(ServiceKey.seerr.usernameLabel, 'Username');

      // qBittorrent allows anonymous instances; every other credential
      // service requires both fields.
      expect(ServiceKey.qbittorrent.requiresUsername, isFalse);
      expect(ServiceKey.qbittorrent.requiresPassword, isFalse);
      expect(ServiceKey.nzbget.requiresUsername, isTrue);
      expect(ServiceKey.nzbget.requiresPassword, isTrue);
      expect(ServiceKey.npm.requiresUsername, isTrue);
      expect(ServiceKey.npm.requiresPassword, isTrue);
      expect(ServiceKey.navidrome.requiresUsername, isTrue);
      expect(ServiceKey.seerr.requiresUsername, isFalse);
    });

    test('resolves NZBGet and NPM metadata', () {
      expect(ServiceKey.nzbget.title, 'NZBGet');
      expect(ServiceKey.npm.title, 'Nginx PM');
      expect(ServiceKey.nzbget.routeParam, 'nzbget');
      expect(ServiceKey.npm.routeParam, 'npm');
      expect(ServiceKey.nzbget.apiVersion, 'JSON-RPC');
      expect(ServiceKey.npm.apiVersion, 'REST');
      expect(ServiceKey.nzbget.itemLabel, 'downloads');
      expect(ServiceKey.npm.itemLabel, 'proxy hosts');
      expect(ServiceKey.nzbget.isSearchable, isFalse);
      expect(ServiceKey.npm.isSearchable, isFalse);
      expect(ServiceKey.nzbget.icon, Icons.cloud_download_rounded);
      expect(ServiceKey.npm.icon, Icons.router_rounded);
      expect(ServiceKey.nzbget.accent.toARGB32(), 0xFF26A69A);
      expect(ServiceKey.npm.accent.toARGB32(), 0xFFF1583A);
    });

    test('maps NZBGet and NPM credential fields', () {
      const settings = SettingsModel(
        nzbgetUsername: 'nzuser',
        nzbgetPassword: 'nzpass',
        npmIdentity: 'admin@example.com',
        npmPassword: 'nmpass',
      );
      expect(settings.usernameFor(ServiceKey.nzbget), 'nzuser');
      expect(settings.passwordFor(ServiceKey.nzbget), 'nzpass');
      expect(settings.usernameFor(ServiceKey.npm), 'admin@example.com');
      expect(settings.passwordFor(ServiceKey.npm), 'nmpass');
    });

    test('gates isServiceConfigured on the full NZBGet/NPM triple', () {
      expect(const SettingsModel().isServiceConfigured(ServiceKey.nzbget), isFalse);
      expect(const SettingsModel().isServiceConfigured(ServiceKey.npm), isFalse);
      expect(
        const SettingsModel(nzbgetUrl: 'http://nzbget:6789')
            .isServiceConfigured(ServiceKey.nzbget),
        isFalse,
      );
      expect(
        const SettingsModel(
          nzbgetUrl: 'http://nzbget:6789',
          nzbgetUsername: 'u',
          nzbgetPassword: 'p',
        ).isServiceConfigured(ServiceKey.nzbget),
        isTrue,
      );
      expect(
        const SettingsModel(
          npmUrl: 'http://npm:81',
          npmIdentity: 'admin@example.com',
          npmPassword: 'p',
        ).isServiceConfigured(ServiceKey.npm),
        isTrue,
      );
    });

    test('clearedService wipes every stored value per service', () {
      const full = SettingsModel(
        seerrUrl: 'u',
        seerrApiKey: 'k',
        radarrUrl: 'u',
        radarrApiKey: 'k',
        sonarrUrl: 'u',
        sonarrApiKey: 'k',
        lidarrUrl: 'u',
        lidarrApiKey: 'k',
        qbittorrentUrl: 'u',
        qbittorrentUsername: 'u',
        qbittorrentPassword: 'k',
        prowlarrUrl: 'u',
        prowlarrApiKey: 'k',
        bazarrUrl: 'u',
        bazarrApiKey: 'k',
        navidromeUrl: 'u',
        navidromeUsername: 'u',
        navidromePassword: 'k',
        soulsyncUrl: 'u',
        soulsyncApiKey: 'k',
        nzbgetUrl: 'u',
        nzbgetUsername: 'u',
        nzbgetPassword: 'k',
        npmUrl: 'u',
        npmIdentity: 'u',
        npmPassword: 'k',
      );
      for (final service in ServiceKey.values) {
        final cleared = full.clearedService(service);
        expect(cleared.urlFor(service), isEmpty, reason: '$service url');
        expect(cleared.apiKeyFor(service), isEmpty, reason: '$service key');
        expect(
          cleared.usernameFor(service),
          isEmpty,
          reason: '$service username',
        );
        expect(
          cleared.passwordFor(service),
          isEmpty,
          reason: '$service password',
        );
        // Other services untouched.
        for (final other in ServiceKey.values) {
          if (other == service) continue;
          expect(cleared.urlFor(other), isNotEmpty, reason: '$other url kept');
        }
      }
    });

    test('clearedService fully removes SoulSync credentials', () {
      const settings = SettingsModel(
        soulsyncUrl: 'u',
        soulsyncApiKey: 'k',
        soulsyncProxyCookie: 'session=abc',
        soulsyncProfileId: '1',
      );
      final cleared = settings.clearedService(ServiceKey.soulsync);
      expect(cleared.soulsyncUrl, isEmpty);
      expect(cleared.soulsyncApiKey, isEmpty);
      expect(cleared.soulsyncProxyCookie, isEmpty);
      expect(cleared.soulsyncProfileId, isEmpty);
    });

    test('extracts host labels with ports for service cards', () {
      expect(
        ServiceKey.radarr.extractHost('http://radarr.local:7878'),
        'radarr.local:7878',
      );
      expect(
        ServiceKey.seerr.extractHost('seerr.local:5055'),
        'seerr.local:5055',
      );
      expect(
        ServiceKey.sonarr.extractHost('sonarr.local:8989/api?token=secret'),
        'sonarr.local:8989',
      );
      expect(ServiceKey.lidarr.extractHost(''), isNull);
    });
  });
}
