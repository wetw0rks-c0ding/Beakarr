import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seekarr/features/npm/data/npm_client.dart';

/// A canned HTTP reply for [_MockAdapter].
typedef _Reply = ({int status, Object? body});

/// In-memory [HttpClientAdapter] driven by a per-request [responder].
///
/// The responder (rather than a single canned body) is needed because the
/// token machine under test answers `/api/tokens` and the data endpoint
/// differently, and because a re-login must return a *different* token.
class _MockAdapter implements HttpClientAdapter {
  _MockAdapter(this.responder);

  final _Reply Function(RequestOptions options) responder;
  final List<RequestOptions> requests = [];

  int get callCount => requests.length;

  int countPath(String path) =>
      requests.where((request) => request.path == path).length;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final reply = responder(options);
    final body = reply.body;
    final text = body is String ? body : jsonEncode(body);
    return ResponseBody.fromBytes(
      utf8.encode(text),
      reply.status,
      headers: {
        Headers.contentTypeHeader: ['application/json; charset=utf-8'],
      },
    );
  }
}

NpmClient _client(
  HttpClientAdapter adapter, {
  String url = 'http://npm.local:81',
  String identity = 'admin@example.com',
  String password = 'secret',
}) {
  final dio = Dio(BaseOptions(baseUrl: url));
  dio.httpClientAdapter = adapter;
  return NpmClient(url: url, identity: identity, password: password, dio: dio);
}

String _iso(DateTime value) => value.toUtc().toIso8601String();

String _jwt(Map<String, dynamic> payload) {
  String segment(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${segment({'alg': 'HS256', 'typ': 'JWT'})}.${segment(payload)}.sig';
}

int _epochSeconds(DateTime value) =>
    value.toUtc().millisecondsSinceEpoch ~/ 1000;

void main() {
  group('NpmClient baseUrl normalization', () {
    test('trims trailing slash', () {
      final client = NpmClient(
        url: 'http://npm.local:81/',
        identity: 'a',
        password: 'b',
      );
      expect(client.baseUrl, 'http://npm.local:81');
      client.close();
    });

    test('prepends http:// when the scheme is missing', () {
      final client = NpmClient(
        url: 'npm.local:81',
        identity: 'a',
        password: 'b',
      );
      expect(client.baseUrl, 'http://npm.local:81');
      client.close();
    });

    test('preserves https', () {
      final client = NpmClient(
        url: 'https://npm.example/',
        identity: 'a',
        password: 'b',
      );
      expect(client.baseUrl, 'https://npm.example');
      client.close();
    });
  });

  group('NpmClient.hasCredentials', () {
    test('false without an identity', () {
      final client = NpmClient(url: 'http://x', identity: '', password: 'p');
      expect(client.hasCredentials, isFalse);
      client.close();
    });

    test('false without a password', () {
      final client = NpmClient(
        url: 'http://x',
        identity: 'a@b.c',
        password: '',
      );
      expect(client.hasCredentials, isFalse);
      client.close();
    });

    test('true when both are present', () {
      final client = NpmClient(
        url: 'http://x',
        identity: 'a@b.c',
        password: 'p',
      );
      expect(client.hasCredentials, isTrue);
      client.close();
    });

    test('trims the identity', () {
      final client = NpmClient(
        url: 'http://x',
        identity: '  a@b.c  ',
        password: 'p',
      );
      expect(client.identity, 'a@b.c');
      client.close();
    });
  });

  group('NpmClient.login', () {
    test('posts {identity, secret} and returns a token', () async {
      final adapter = _MockAdapter(
        (_) => (
          status: 200,
          body: {
            'token': 'tok-1',
            'expires': _iso(DateTime.now().add(const Duration(hours: 1))),
          },
        ),
      );
      final client = _client(adapter);

      await client.login();

      expect(adapter.requests, hasLength(1));
      final login = adapter.requests.single;
      expect(login.path, '/api/tokens');
      expect(login.method, 'POST');
      expect(login.data, {'identity': 'admin@example.com', 'secret': 'secret'});
      expect(client.isTokenFresh, isTrue);

      client.close();
    });

    test('401 throws NpmAuthException("HTTP 401")', () async {
      final adapter = _MockAdapter(
        (_) => (status: 401, body: {'error': 'Unauthorized'}),
      );
      final client = _client(adapter);

      await expectLater(
        client.login(),
        throwsA(
          isA<NpmAuthException>().having(
            (e) => e.message,
            'message',
            'HTTP 401',
          ),
        ),
      );

      client.close();
    });

    test('requires_2fa throws the 2FA exception with its message', () async {
      final adapter = _MockAdapter(
        (_) => (status: 200, body: {'requires_2fa': true}),
      );
      final client = _client(adapter);

      await expectLater(
        client.login(),
        throwsA(
          isA<NpmTwoFactorRequiredException>().having(
            (e) => e.message,
            'message',
            'This account has 2FA enabled — API token auth is not supported',
          ),
        ),
      );
      expect(client.isTokenFresh, isFalse);

      client.close();
    });

    test('a token response without a token is an auth failure', () async {
      final adapter = _MockAdapter((_) => (status: 200, body: {}));
      final client = _client(adapter);

      await expectLater(client.login(), throwsA(isA<NpmAuthException>()));

      client.close();
    });

    test('throws without credentials instead of posting', () async {
      final adapter = _MockAdapter(
        (_) => (status: 200, body: {'token': 'tok'}),
      );
      final client = _client(adapter, identity: '', password: '');

      await expectLater(client.login(), throwsA(isA<NpmAuthException>()));
      expect(adapter.callCount, 0);

      client.close();
    });
  });

  group('NpmClient token expiry', () {
    test('trusts expires from the response', () async {
      final adapter = _MockAdapter(
        (_) => (
          status: 200,
          body: {
            'token': 'opaque-token',
            'expires': _iso(DateTime.now().add(const Duration(minutes: 10))),
          },
        ),
      );
      final client = _client(adapter);

      await client.login();
      expect(client.isTokenFresh, isTrue);

      client.close();
    });

    test('treats an expires timestamp in the past as stale', () async {
      final adapter = _MockAdapter(
        (_) => (
          status: 200,
          body: {
            'token': 'opaque-token',
            'expires': _iso(
              DateTime.now().subtract(const Duration(minutes: 5)),
            ),
          },
        ),
      );
      final client = _client(adapter);

      await client.login();
      expect(
        client.isTokenFresh,
        isFalse,
        reason: 'an expired server timestamp must force a re-login',
      );

      client.close();
    });

    test('uses the JWT exp claim when expires is absent', () async {
      final adapter = _MockAdapter(
        (_) => (
          status: 200,
          body: {
            'token': _jwt({
              'exp': _epochSeconds(
                DateTime.now().add(const Duration(hours: 2)),
              ),
            }),
          },
        ),
      );
      final client = _client(adapter);

      await client.login();
      expect(client.isTokenFresh, isTrue);

      client.close();
    });

    test('a past JWT exp claim makes the token stale', () async {
      final adapter = _MockAdapter(
        (_) => (
          status: 200,
          body: {
            'token': _jwt({
              'exp': _epochSeconds(
                DateTime.now().subtract(const Duration(minutes: 10)),
              ),
            }),
          },
        ),
      );
      final client = _client(adapter);

      await client.login();
      expect(
        client.isTokenFresh,
        isFalse,
        reason: 'the exp claim wins over the 30 minute fallback',
      );

      client.close();
    });

    test('falls back to 30 minutes for an opaque token', () async {
      final adapter = _MockAdapter(
        (_) => (status: 200, body: {'token': 'not-a-jwt'}),
      );
      final client = _client(adapter);

      await client.login();
      expect(client.isTokenFresh, isTrue);

      client.close();
    });
  });

  group('NpmClient.get', () {
    test('authenticates first and applies the bearer header', () async {
      final adapter = _MockAdapter((options) {
        if (options.path == '/api/tokens') {
          return (
            status: 200,
            body: {
              'token': 'tok-1',
              'expires': _iso(DateTime.now().add(const Duration(hours: 1))),
            },
          );
        }
        return (status: 200, body: <dynamic>[]);
      });
      final client = _client(adapter);

      final response = await client.get(
        '/api/nginx/proxy-hosts',
        query: {'expand': 'certificate'},
      );

      expect(response.statusCode, 200);
      expect(adapter.countPath('/api/tokens'), 1);
      final dataRequest = adapter.requests.last;
      expect(dataRequest.path, '/api/nginx/proxy-hosts');
      expect(dataRequest.queryParameters, {'expand': 'certificate'});
      expect(dataRequest.headers['Authorization'], 'Bearer tok-1');

      client.close();
    });

    test('reuses a fresh cached token', () async {
      final adapter = _MockAdapter((options) {
        if (options.path == '/api/tokens') {
          return (
            status: 200,
            body: {
              'token': 'tok-1',
              'expires': _iso(DateTime.now().add(const Duration(hours: 1))),
            },
          );
        }
        return (status: 200, body: <dynamic>[]);
      });
      final client = _client(adapter);

      await client.get('/api/nginx/proxy-hosts');
      await client.get('/api/nginx/certificates');

      expect(adapter.countPath('/api/tokens'), 1);
      expect(adapter.callCount, 3);

      client.close();
    });

    test(
      're-logs in before the next call when expires is in the past',
      () async {
        var logins = 0;
        final adapter = _MockAdapter((options) {
          if (options.path == '/api/tokens') {
            logins++;
            return (
              status: 200,
              body: {
                'token': 'tok-$logins',
                'expires': logins == 1
                    ? _iso(DateTime.now().subtract(const Duration(minutes: 1)))
                    : _iso(DateTime.now().add(const Duration(hours: 1))),
              },
            );
          }
          return (status: 200, body: <dynamic>[]);
        });
        final client = _client(adapter);

        await client.get('/api/nginx/proxy-hosts');
        await client.get('/api/nginx/certificates');

        expect(logins, 2);
        expect(adapter.requests.last.headers['Authorization'], 'Bearer tok-2');

        client.close();
      },
    );

    test('concurrent ensureAuthenticated calls share one login', () async {
      final adapter = _MockAdapter(
        (_) => (
          status: 200,
          body: {
            'token': 'tok-1',
            'expires': _iso(DateTime.now().add(const Duration(hours: 1))),
          },
        ),
      );
      final client = _client(adapter);

      await Future.wait([
        client.ensureAuthenticated(),
        client.ensureAuthenticated(),
        client.ensureAuthenticated(),
      ]);

      expect(adapter.countPath('/api/tokens'), 1);

      client.close();
    });
  });

  group('NpmClient 401 retry interceptor', () {
    test('re-logs in once and retries the request', () async {
      var logins = 0;
      var dataCalls = 0;
      final adapter = _MockAdapter((options) {
        if (options.path == '/api/tokens') {
          logins++;
          return (
            status: 200,
            body: {
              'token': 'tok-$logins',
              'expires': _iso(DateTime.now().add(const Duration(hours: 1))),
            },
          );
        }
        dataCalls++;
        return dataCalls == 1
            ? (status: 401, body: {'error': 'Unauthorized'})
            : (status: 200, body: <dynamic>[]);
      });
      final client = _client(adapter);

      // Cache a token first, then count only the failed request onwards.
      await client.login();
      adapter.requests.clear();

      final response = await client.get('/api/nginx/proxy-hosts');

      expect(response.statusCode, 200);
      expect(adapter.callCount, 3, reason: 'GET → login → retried GET');
      expect(adapter.countPath('/api/tokens'), 1);
      expect(adapter.countPath('/api/nginx/proxy-hosts'), 2);
      expect(
        adapter.requests.last.headers['Authorization'],
        'Bearer tok-2',
        reason: 'the retry must carry the refreshed token',
      );

      client.close();
    });

    test('a second 401 propagates and the interceptor stops', () async {
      var logins = 0;
      final adapter = _MockAdapter((options) {
        if (options.path == '/api/tokens') {
          logins++;
          return (
            status: 200,
            body: {
              'token': 'tok-$logins',
              'expires': _iso(DateTime.now().add(const Duration(hours: 1))),
            },
          );
        }
        return (status: 401, body: {'error': 'Unauthorized'});
      });
      final client = _client(adapter);

      await client.login();
      adapter.requests.clear();

      await expectLater(
        client.get('/api/nginx/proxy-hosts'),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'statusCode',
            401,
          ),
        ),
      );

      expect(adapter.callCount, 3, reason: 'GET → login → retried GET only');
      expect(adapter.countPath('/api/nginx/proxy-hosts'), 2);
      expect(adapter.countPath('/api/tokens'), 1);

      client.close();
    });

    test('does not retry when the re-login itself fails', () async {
      var logins = 0;
      final adapter = _MockAdapter((options) {
        if (options.path == '/api/tokens') {
          logins++;
          return logins == 1
              ? (
                  status: 200,
                  body: {
                    'token': 'tok-1',
                    'expires': _iso(
                      DateTime.now().add(const Duration(hours: 1)),
                    ),
                  },
                )
              : (status: 401, body: {'error': 'Unauthorized'});
        }
        return (status: 401, body: {'error': 'Unauthorized'});
      });
      final client = _client(adapter);

      await client.login();
      adapter.requests.clear();

      await expectLater(
        client.get('/api/nginx/proxy-hosts'),
        throwsA(isA<DioException>()),
      );

      expect(adapter.countPath('/api/nginx/proxy-hosts'), 1);
      expect(adapter.countPath('/api/tokens'), 1);

      client.close();
    });
  });
}
