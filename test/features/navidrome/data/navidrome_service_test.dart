import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seekarr/features/navidrome/data/navidrome_service.dart';
import 'package:seekarr/features/settings/data/settings_provider.dart';
import 'package:seekarr/features/settings/domain/settings_model.dart';

import '../../../test_helpers/fake_api_client.dart';

void main() {
  group('navidromeServiceProvider', () {
    test('throws when Navidrome is not configured', () {
      final container = ProviderContainer(
        overrides: [
          currentSettingsProvider.overrideWith((ref) => const SettingsModel()),
        ],
      );
      addTearDown(container.dispose);

      expect(() => container.read(navidromeServiceProvider), throwsException);
    });

    test('returns a service when Navidrome is configured', () {
      final container = ProviderContainer(
        overrides: [
          currentSettingsProvider.overrideWith(
            (ref) => const SettingsModel(
              navidromeUrl: 'https://navidrome.example.com',
              navidromeUsername: 'user',
              navidromePassword: 'pass',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(navidromeServiceProvider), isA<NavidromeService>());
    });
  });

  group('NavidromeService', () {
    late FakeApiClient client;
    late NavidromeService service;

    setUp(() {
      client = FakeApiClient();
      service = NavidromeService(client);
    });

    test('getArtists fetches and maps artists', () async {
      client.getResponseData = {
        'subsonic-response': {
          'status': 'ok',
          'artists': {
            'index': [
              {
                'name': 'A',
                'artist': [
                  {'id': '1', 'name': 'Artist One', 'albumCount': 2},
                ],
              },
            ],
          },
        },
      };

      final artists = await service.getArtists();
      expect(client.lastGetPath, '/rest/getArtists.view');
      expect(artists, hasLength(1));
      expect(artists.first.id, '1');
      expect(artists.first.name, 'Artist One');
      expect(artists.first.albumCount, 2);
    });

    test('getArtists throws on error', () async {
      client.getException = Exception('boom');
      expect(() => service.getArtists(), throwsA(isA<Object>()));
    });

    test('getArtists throws on failed status', () async {
      client.getResponseData = {
        'subsonic-response': {
          'status': 'failed',
          'error': {'message': 'Wrong username or password'},
        },
      };
      expect(() => service.getArtists(), throwsA(isA<StateError>()));
    });

    test('getAlbums fetches and maps albums', () async {
      client.getResponseData = {
        'subsonic-response': {
          'status': 'ok',
          'albumList2': {
            'album': [
              {
                'id': '10',
                'name': 'Album One',
                'artist': 'Artist One',
                'year': 2020,
                'songCount': 5,
              },
            ],
          },
        },
      };

      final albums = await service.getAlbums();
      expect(client.lastGetPath, '/rest/getAlbumList2.view');
      expect(albums, hasLength(1));
      expect(albums.first.id, '10');
      expect(albums.first.name, 'Album One');
      expect(albums.first.year, 2020);
      expect(albums.first.songCount, 5);
    });

    test('getAlbumTracks fetches and maps tracks', () async {
      client.getResponseData = {
        'subsonic-response': {
          'status': 'ok',
          'album': {
            'id': '10',
            'name': 'Album One',
            'song': [
              {'id': '20', 'title': 'Track One', 'duration': 180, 'track': 1},
            ],
          },
        },
      };

      final tracks = await service.getAlbumTracks('10');
      expect(client.lastGetPath, '/rest/getAlbum.view');
      expect(client.lastGetQueryParameters, {'id': '10'});
      expect(tracks, hasLength(1));
      expect(tracks.single.id, '20');
      expect(tracks.single.title, 'Track One');
      expect(tracks.single.durationSeconds, 180);
      expect(tracks.single.trackNumber, 1);
    });

    test('getAlbumTracks throws on error', () async {
      client.getException = Exception('boom');
      expect(() => service.getAlbumTracks('10'), throwsA(isA<Object>()));
    });

    test('getAlbumTracks throws on failed status', () async {
      client.getResponseData = {
        'subsonic-response': {
          'status': 'failed',
          'error': {'message': 'Wrong username or password'},
        },
      };
      expect(() => service.getAlbumTracks('10'), throwsA(isA<StateError>()));
    });
  });
}