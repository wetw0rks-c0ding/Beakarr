import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seekarr/features/navidrome/data/navidrome_service.dart';
import 'package:seekarr/features/navidrome/presentation/navidrome_providers.dart';
import 'package:seekarr/features/settings/data/settings_provider.dart';
import 'package:seekarr/features/settings/domain/settings_model.dart';

import '../../../test_helpers/fake_api_client.dart';

void main() {
  group('navidromeArtistAlbumsProvider', () {
    test('fetches albums for the given artist id', () async {
      final client = FakeApiClient();
      client.getResponseData = {
        'subsonic-response': {
          'status': 'ok',
          'artist': {
            'id': 'a1',
            'name': 'Artist One',
            'album': [
              {'id': '10', 'name': 'Album One'},
            ],
          },
        },
      };

      final container = ProviderContainer(
        overrides: [
          currentSettingsProvider.overrideWith(
            (ref) => const SettingsModel(
              navidromeUrl: 'https://navidrome.example.com',
              navidromeUsername: 'user',
              navidromePassword: 'pass',
            ),
          ),
          navidromeServiceProvider.overrideWith((ref) => NavidromeService(client)),
        ],
      );
      addTearDown(container.dispose);

      final albums = await container.read(
        navidromeArtistAlbumsProvider('a1').future,
      );

      expect(client.lastGetPath, '/rest/getArtist.view');
      expect(client.lastGetQueryParameters, {'id': 'a1'});
      expect(albums, hasLength(1));
      expect(albums.first.id, '10');
      expect(albums.first.name, 'Album One');
    });

    test('surfaces service errors as AsyncValue.error', () async {
      final client = FakeApiClient();
      client.getException = Exception('boom');

      final container = ProviderContainer(
        overrides: [
          currentSettingsProvider.overrideWith(
            (ref) => const SettingsModel(
              navidromeUrl: 'https://navidrome.example.com',
              navidromeUsername: 'user',
              navidromePassword: 'pass',
            ),
          ),
          navidromeServiceProvider.overrideWith((ref) => NavidromeService(client)),
        ],
      );
      addTearDown(container.dispose);

      Object? caught;
      try {
        await container.read(navidromeArtistAlbumsProvider('a1').future);
      } catch (e) {
        caught = e;
      }
      expect(caught, isA<Object>());
    });

    test('throws on failed subsonic status', () async {
      final client = FakeApiClient();
      client.getResponseData = {
        'subsonic-response': {
          'status': 'failed',
          'error': {'message': 'Wrong username or password'},
        },
      };

      final container = ProviderContainer(
        overrides: [
          currentSettingsProvider.overrideWith(
            (ref) => const SettingsModel(
              navidromeUrl: 'https://navidrome.example.com',
              navidromeUsername: 'user',
              navidromePassword: 'pass',
            ),
          ),
          navidromeServiceProvider.overrideWith((ref) => NavidromeService(client)),
        ],
      );
      addTearDown(container.dispose);

      Object? caught;
      try {
        await container.read(navidromeArtistAlbumsProvider('a1').future);
      } catch (e) {
        caught = e;
      }
      expect(caught, isA<StateError>());
    });
  });
}