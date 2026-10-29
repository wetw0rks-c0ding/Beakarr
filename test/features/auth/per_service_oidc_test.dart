import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'dart:io';
import 'package:seekarr/features/auth/data/oidc_session_service.dart';
import '../../test_helpers/fake_secure_settings_store.dart';

void main() {
  late FakeSecureSettingsStore fakeStore;

  setUp(() {
    fakeStore = FakeSecureSettingsStore();
  });

  group('OidcSessionService.perServiceIssuer', () {
    test('derives origin correctly from seekarr base for sonarr', () async {
      const base = 'https://auth.piracyhub.win/application/o/seekarr/';
      final result = OidcSessionService.perServiceIssuer(base, 'sonarr');
      expect(
        result,
        equals('https://auth.piracyhub.win/application/o/sonarr/'),
      );
    });

    test('is idempotent when base is already sonarr issuer', () async {
      const base = 'https://auth.piracyhub.win/application/o/sonarr/';
      final result1 = OidcSessionService.perServiceIssuer(base, 'sonarr');
      final result2 = OidcSessionService.perServiceIssuer(result1, 'sonarr');
      expect(
        result1,
        equals('https://auth.piracyhub.win/application/o/sonarr/'),
      );
      expect(
        result2,
        equals('https://auth.piracyhub.win/application/o/sonarr/'),
      );
    });

    test('returns empty string when base is empty', () async {
      final result = OidcSessionService.perServiceIssuer('', 'sonarr');
      expect(result, equals(''));
    });

    test('returns empty string for garbage base', () async {
      final result = OidcSessionService.perServiceIssuer('garbage!!', 'sonarr');
      expect(result, isEmpty);
    });
  });

  group('OidcSessionService.perServiceClientId', () {
    test('returns service name', () async {
      expect(OidcSessionService.perServiceClientId('sonarr'), equals('sonarr'));
    });
  });

  group('saveTokensFor + accessTokenFor round-trip for sonarr', () {
    test('stores and retrieves access token correctly', () async {
      const access = 'test_access_token';
      const refresh = 'test_refresh_token';
      final expiry = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;

      await OidcSessionService(fakeStore).saveTokensFor(
        service: 'sonarr',
        access: access,
        refresh: refresh,
        expiryEpoch: expiry,
        pkceVerifier: 'test_verifier',
      );

      expect(
        await OidcSessionService(fakeStore).accessTokenFor('sonarr'),
        equals(access),
      );
      expect(
        await OidcSessionService(fakeStore).refreshTokenFor('sonarr'),
        equals(refresh),
      );
    });

    test('stores expiry epoch correctly', () async {
      final expiry = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
      await OidcSessionService(fakeStore).saveTokensFor(
        service: 'sonarr',
        access: '',
        refresh: '',
        expiryEpoch: expiry,
        pkceVerifier: '',
      );

      final stored = await OidcSessionService(
        fakeStore,
      ).expiryEpochFor('sonarr');
      expect(stored, equals(expiry));
    });

    test('stores pkce verifier correctly', () async {
      await OidcSessionService(fakeStore).saveTokensFor(
        service: 'sonarr',
        access: '',
        refresh: '',
        expiryEpoch: 0,
        pkceVerifier: 'my_secret_verifier_123',
      );

      final stored = await OidcSessionService(
        fakeStore,
      ).pkceVerifierFor('sonarr');
      expect(stored, equals('my_secret_verifier_123'));
    });
  });

  group('seekarr base keys and sonarr keys are independent', () {
    test(
      'write base via saveTokens, write sonarr via saveTokensFor, read both back',
      () async {
        const seekarrAccess = 'seekarr_base_access';
        const seekarrRefresh = 'seekarr_base_refresh';
        await OidcSessionService(fakeStore).saveTokens(
          access: seekarrAccess,
          refresh: seekarrRefresh,
          expiryEpoch: 0,
          pkceVerifier: '',
        );

        const sonarrAccess = 'sonarr_access';
        const sonarrRefresh = 'sonarr_refresh';
        final expiry = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
        await OidcSessionService(fakeStore).saveTokensFor(
          service: 'sonarr',
          access: sonarrAccess,
          refresh: sonarrRefresh,
          expiryEpoch: expiry,
          pkceVerifier: '',
        );

        expect(
          await OidcSessionService(fakeStore).accessToken,
          equals(seekarrAccess),
        );
        expect(
          await OidcSessionService(fakeStore).refreshToken,
          equals(seekarrRefresh),
        );
        expect(
          await OidcSessionService(fakeStore).accessTokenFor('sonarr'),
          equals(sonarrAccess),
        );
        expect(
          await OidcSessionService(fakeStore).refreshTokenFor('sonarr'),
          equals(sonarrRefresh),
        );
      },
    );
  });

  group('sessionStateFor', () {
    test('is disabled when empty', () async {
      final state = await OidcSessionService(
        fakeStore,
      ).sessionStateFor('sonarr');
      expect(state, equals(SessionStatus.disabled));
    });

    test('is active after save with future expiry', () async {
      final expiry = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
      await OidcSessionService(fakeStore).saveTokensFor(
        service: 'sonarr',
        access: 'active_token',
        refresh: '',
        expiryEpoch: expiry,
        pkceVerifier: '',
      );

      final state = await OidcSessionService(
        fakeStore,
      ).sessionStateFor('sonarr');
      expect(state, equals(SessionStatus.active));
    });

    test('is error after save with past expiry', () async {
      final pastExpiry = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 3600;
      await OidcSessionService(fakeStore).saveTokensFor(
        service: 'sonarr',
        access: 'expired_token',
        refresh: '',
        expiryEpoch: pastExpiry,
        pkceVerifier: '',
      );

      final state = await OidcSessionService(
        fakeStore,
      ).sessionStateFor('sonarr');
      expect(state, equals(SessionStatus.error));
    });
  });

  group('clearFor removes only that service', () {
    test('sonarr cleared, radarr untouched', () async {
      const sonarrAccess = 'sonarr_access';
      const radarrAccess = 'radarr_access';
      final expiry = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;

      await OidcSessionService(fakeStore).saveTokensFor(
        service: 'sonarr',
        access: sonarrAccess,
        refresh: '',
        expiryEpoch: expiry,
        pkceVerifier: '',
      );

      await OidcSessionService(fakeStore).saveTokensFor(
        service: 'radarr',
        access: radarrAccess,
        refresh: '',
        expiryEpoch: expiry,
        pkceVerifier: '',
      );

      await OidcSessionService(fakeStore).clearFor('sonarr');

      expect(
        await OidcSessionService(fakeStore).accessTokenFor('sonarr'),
        isNull,
      );
      expect(
        await OidcSessionService(fakeStore).accessTokenFor('radarr'),
        equals(radarrAccess),
      );
    });
  });

  group('arrstack single-tile mode', () {
    test('isArrstackMode detects the arrstack issuer', () {
      expect(
        OidcSessionService.isArrstackMode(
          'https://auth.piracyhub.win/application/o/arrstack/',
        ),
        isTrue,
      );
      expect(
        OidcSessionService.isArrstackMode(
          'https://auth.piracyhub.win/application/o/arrstack',
        ),
        isTrue,
      );
      expect(
        OidcSessionService.isArrstackMode(
          'https://auth.piracyhub.win/application/o/sonarr/',
        ),
        isFalse,
      );
      expect(OidcSessionService.isArrstackMode(''), isFalse);
    });

    test(
      'perServiceIssuer returns base for every service in arrstack mode',
      () {
        const base = 'https://auth.piracyhub.win/application/o/arrstack/';
        for (final svc in ['sonarr', 'radarr', 'lidarr']) {
          expect(OidcSessionService.perServiceIssuer(base, svc), equals(base));
        }
      },
    );

    test('perServiceClientId returns arrstack in arrstack mode', () {
      const base = 'https://auth.piracyhub.win/application/o/arrstack/';
      expect(
        OidcSessionService.perServiceClientId('sonarr', base),
        equals('arrstack'),
      );
      expect(OidcSessionService.perServiceClientId('sonarr'), equals('sonarr'));
    });
  });

  group('refresh outcome', () {
    late HttpServer server;
    late String base;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      base = 'http://localhost:${server.port}';
    });

    tearDown(() async {
      await server.close();
      await OidcSessionService(fakeStore).clearFor('sonarr');
    });

    Future<void> stubIdp({required int tokenStatus}) async {
      server.listen((req) async {
        if (req.uri.path == '/.well-known/openid-configuration') {
          req.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'token_endpoint': '$base/token'}));
          await req.response.close();
        } else if (req.uri.path == '/token') {
          req.response
            ..statusCode = tokenStatus
            ..headers.contentType = ContentType.json
            ..write(
              tokenStatus == 200
                  ? jsonEncode({
                      'access_token': 'new-access',
                      'refresh_token': 'new-refresh',
                      'expires_in': 3600,
                    })
                  : jsonEncode({'error': 'invalid_grant'}),
            );
          await req.response.close();
        } else {
          req.response.statusCode = 404;
          await req.response.close();
        }
      });
    }

    test('refreshFor refreshed on 200 and stores the new pair', () async {
      await stubIdp(tokenStatus: 200);
      final sess = OidcSessionService(fakeStore);
      await sess.saveTokensFor(
        service: 'sonarr',
        access: 'old-access',
        refresh: 'old-refresh',
        expiryEpoch: 0,
      );
      expect(
        await sess.refreshFor('sonarr', base, 'sonarr'),
        equals(RefreshOutcome.refreshed),
      );
      expect(await sess.accessTokenFor('sonarr'), equals('new-access'));
      expect(await sess.refreshTokenFor('sonarr'), equals('new-refresh'));
    });

    test('refreshFor rejected on 400 and drops access only', () async {
      await stubIdp(tokenStatus: 400);
      final sess = OidcSessionService(fakeStore);
      await sess.saveTokensFor(
        service: 'sonarr',
        access: 'old-access',
        refresh: 'old-refresh',
        expiryEpoch: 0,
      );
      expect(
        await sess.refreshFor('sonarr', base, 'sonarr'),
        equals(RefreshOutcome.rejected),
      );
      expect(await sess.accessTokenFor('sonarr'), isNull);
      expect(await sess.refreshTokenFor('sonarr'), equals('old-refresh'));
    });

    test('refreshFor rejected with no stored refresh token', () async {
      expect(
        await OidcSessionService(
          fakeStore,
        ).refreshFor('sonarr', base, 'sonarr'),
        equals(RefreshOutcome.rejected),
      );
    });

    test('refreshFor transient on 500 and keeps the stored pair', () async {
      await stubIdp(tokenStatus: 500);
      final sess = OidcSessionService(fakeStore);
      await sess.saveTokensFor(
        service: 'sonarr',
        access: 'old-access',
        refresh: 'old-refresh',
        expiryEpoch: 0,
      );
      expect(
        await sess.refreshFor('sonarr', base, 'sonarr'),
        equals(RefreshOutcome.transient),
      );
      expect(await sess.accessTokenFor('sonarr'), equals('old-access'));
      expect(await sess.refreshTokenFor('sonarr'), equals('old-refresh'));
    });

    test('concurrent refreshFor shares a single token call', () async {
      var tokenHits = 0;
      server.listen((req) async {
        if (req.uri.path == '/.well-known/openid-configuration') {
          req.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'token_endpoint': '$base/token'}));
          await req.response.close();
        } else if (req.uri.path == '/token') {
          tokenHits++;
          // Hold the first call so the others join it in-flight.
          await Future<void>.delayed(const Duration(milliseconds: 200));
          req.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'access_token': 'new-access',
                'refresh_token': 'new-refresh',
                'expires_in': 3600,
              }),
            );
          await req.response.close();
        } else {
          req.response.statusCode = 404;
          await req.response.close();
        }
      });
      final sess = OidcSessionService(fakeStore);
      await sess.saveTokensFor(
        service: 'sonarr',
        access: 'old-access',
        refresh: 'old-refresh',
        expiryEpoch: 0,
      );
      final results = await Future.wait([
        sess.refreshFor('sonarr', base, 'sonarr'),
        sess.refreshFor('sonarr', base, 'sonarr'),
        sess.refreshFor('sonarr', base, 'sonarr'),
      ]);
      expect(results, everyElement(equals(RefreshOutcome.refreshed)));
      expect(tokenHits, equals(1));
    });
  });
}
