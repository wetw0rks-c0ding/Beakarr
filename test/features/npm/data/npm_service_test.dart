import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seekarr/features/npm/data/npm_client.dart';
import 'package:seekarr/features/npm/data/npm_service.dart';
import 'package:seekarr/features/npm/domain/cert_expiry.dart';
import 'package:seekarr/features/settings/data/settings_provider.dart';
import 'package:seekarr/features/settings/domain/settings_model.dart';

/// In-memory adapter: answers `/api/tokens` with a fresh token and every other
/// path with a fixed body supplied per test.
class _MockAdapter implements HttpClientAdapter {
  _MockAdapter({this.data});

  dynamic data;
  final List<RequestOptions> requests = [];

  int get callCount => requests.length;

  List<String> get paths =>
      requests.map((request) => request.path).toList(growable: false);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final body = options.path == '/api/tokens'
        ? {
            'token': 'tok-1',
            'expires': DateTime.now()
                .toUtc()
                .add(const Duration(hours: 1))
                .toIso8601String(),
          }
        : data;
    return ResponseBody.fromBytes(
      utf8.encode(body is String ? body : jsonEncode(body)),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json; charset=utf-8'],
      },
    );
  }
}

NpmService _service(HttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://npm.local:81'));
  dio.httpClientAdapter = adapter;
  return NpmService(
    NpmClient(
      url: 'http://npm.local:81',
      identity: 'admin@example.com',
      password: 'secret',
      dio: dio,
    ),
  );
}

void main() {
  group('NpmService.getProxyHosts', () {
    test('maps hosts and sends expand=certificate', () async {
      final adapter = _MockAdapter(
        data: [
          {
            'id': 1,
            'domain_names': ['app.example.com', 'www.example.com'],
            'forward_scheme': 'http',
            'forward_host': '192.168.1.10',
            'forward_port': 8080,
            'enabled': true,
            'ssl_forced': true,
            'certificate_id': 7,
            'http2_support': true,
            'allow_websocket_upgrade': true,
            'meta': {'nginx_online': true, 'nginx_err': null},
            'certificate': {
              'id': 7,
              'provider': 'letsencrypt',
              'nice_name': 'example.com',
              'domain_names': ['example.com'],
              'expires_on': '2027-01-01T00:00:00.000Z',
            },
          },
          {
            'id': 2,
            'domain_names': <dynamic>[],
            'forward_scheme': 'https',
            'forward_host': 'nas.local',
            'forward_port': 5001,
            'enabled': false,
            'meta': {'nginx_online': false, 'nginx_err': 'Connection refused'},
          },
        ],
      );
      final service = _service(adapter);

      final hosts = await service.getProxyHosts();

      expect(hosts, hasLength(2));
      final first = hosts.first;
      expect(first.id, 1);
      expect(first.primaryDomain, 'app.example.com');
      expect(first.forwardTarget, 'http://192.168.1.10:8080');
      expect(first.enabled, isTrue);
      expect(first.sslForced, isTrue);
      expect(first.http2Support, isTrue);
      expect(first.isLive, isTrue);
      expect(first.certificate?.id, 7);
      expect(first.toSummary(), isNotNull);

      final second = hosts.last;
      expect(second.primaryDomain, '—');
      expect(second.forwardTarget, 'https://nas.local:5001');
      expect(second.enabled, isFalse);
      expect(second.isLive, isFalse);
      expect(second.nginxError, 'Connection refused');
      expect(second.certificate, isNull);
      expect(second.toSummary(), isNull);

      final dataRequest = adapter.requests.last;
      expect(dataRequest.path, '/api/nginx/proxy-hosts');
      expect(dataRequest.queryParameters, {'expand': 'certificate'});
    });

    test('tolerates a non-list body with an empty list', () async {
      final adapter = _MockAdapter(data: {'error': 'unexpected shape'});
      final service = _service(adapter);

      expect(await service.getProxyHosts(), isEmpty);
    });
  });

  group('NpmService.getCertificates', () {
    test('maps certificates and exposes expiry status', () async {
      final adapter = _MockAdapter(
        data: [
          {
            'id': 7,
            'provider': 'letsencrypt',
            'nice_name': 'example.com',
            'domain_names': ['example.com', 'www.example.com'],
            'expires_on': '2026-11-12T10:00:00.000Z',
            'created_on': '2026-08-14T10:00:00.000Z',
            'modified_on': '2026-10-13T10:00:00.000Z',
          },
        ],
      );
      final service = _service(adapter);

      final certificates = await service.getCertificates();

      expect(certificates, hasLength(1));
      final certificate = certificates.single;
      expect(certificate.id, 7);
      expect(certificate.displayName, 'example.com');
      expect(certificate.isLetsEncrypt, isTrue);
      expect(certificate.domainNames, ['example.com', 'www.example.com']);
      expect(certificate.expiresOn?.isUtc, isTrue);
      expect(
        certificate.expiryStatus(now: DateTime.utc(2026, 11, 9)),
        CertExpiryStatus.critical,
      );
      expect(adapter.requests.last.path, '/api/nginx/certificates');
    });

    test('tolerates a non-list body with an empty list', () async {
      final adapter = _MockAdapter(data: {'unexpected': true});
      final service = _service(adapter);

      expect(await service.getCertificates(), isEmpty);
    });
  });

  group('NpmService.getCertificate', () {
    test('looks up locally without a request', () async {
      final adapter = _MockAdapter(
        data: [
          {'id': 3, 'provider': 'letsencrypt', 'nice_name': 'a.example'},
          {'id': 9, 'provider': 'other', 'nice_name': 'b.example'},
        ],
      );
      final service = _service(adapter);

      final certificates = await service.getCertificates();
      final callsAfterFetch = adapter.callCount;

      expect(service.getCertificate(9)?.niceName, 'b.example');
      expect(service.getCertificate(3, certificates)?.id, 3);
      expect(service.getCertificate(42), isNull);
      expect(
        adapter.callCount,
        callsAfterFetch,
        reason: 'getCertificate is a local lookup, never an HTTP call',
      );
    });

    test('returns null before any certificate list was fetched', () {
      final service = _service(_MockAdapter(data: const <dynamic>[]));
      expect(service.getCertificate(1), isNull);
    });
  });

  group('NpmService provider', () {
    test('throws when the URL is missing', () {
      final container = ProviderContainer(
        overrides: [
          currentSettingsProvider.overrideWith(
            (ref) => const SettingsModel(
              npmIdentity: 'admin@example.com',
              npmPassword: 'secret',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        () => container.read(npmServiceProvider),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Nginx Proxy Manager not configured'),
          ),
        ),
      );
    });

    test('throws when the identity is missing', () {
      final container = ProviderContainer(
        overrides: [
          currentSettingsProvider.overrideWith(
            (ref) => const SettingsModel(
              npmUrl: 'http://npm.local:81',
              npmPassword: 'secret',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(() => container.read(npmServiceProvider), throwsException);
    });

    test('throws when the password is missing', () {
      final container = ProviderContainer(
        overrides: [
          currentSettingsProvider.overrideWith(
            (ref) => const SettingsModel(
              npmUrl: 'http://npm.local:81',
              npmIdentity: 'admin@example.com',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(() => container.read(npmServiceProvider), throwsException);
    });
  });
}
