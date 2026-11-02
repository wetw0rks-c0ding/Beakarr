import 'package:flutter_test/flutter_test.dart';
import 'package:seekarr/core/utils/url_utils.dart';

void main() {
  group('UrlUtils', () {
    group('buildUrl', () {
      test('builds correct URL with trailing slash in baseUrl', () {
        final result = UrlUtils.buildUrl(
          'http://localhost:7878/',
          '/api/v3/image.jpg',
        );
        expect(result, 'http://localhost:7878/api/v3/image.jpg');
      });

      test('builds correct URL without trailing slash in baseUrl', () {
        final result = UrlUtils.buildUrl(
          'http://localhost:7878',
          '/api/v3/image.jpg',
        );
        expect(result, 'http://localhost:7878/api/v3/image.jpg');
      });

      test('handles path without leading slash', () {
        final result = UrlUtils.buildUrl(
          'http://localhost:7878',
          'api/v3/image.jpg',
        );
        expect(result, 'http://localhost:7878/api/v3/image.jpg');
      });

      test('returns empty string when baseUrl is empty', () {
        final result = UrlUtils.buildUrl('', '/api/v3/image.jpg');
        expect(result, '');
      });

      test('returns empty string when path is empty', () {
        final result = UrlUtils.buildUrl('http://localhost:7878', '');
        expect(result, '');
      });
    });

    group('validateServiceUrl', () {
      test('returns required error for null', () {
        expect(UrlUtils.validateServiceUrl(null), 'Server URL is required');
      });

      test('returns required error for empty string', () {
        expect(UrlUtils.validateServiceUrl(''), 'Server URL is required');
      });

      test('returns required error for whitespace only', () {
        expect(UrlUtils.validateServiceUrl('  '), 'Server URL is required');
      });

      test('rejects non-http schemes', () {
        expect(
          UrlUtils.validateServiceUrl('ftp://host.com'),
          'URL must start with http:// or https://',
        );
      });

      test('rejects non-url values', () {
        expect(
          UrlUtils.validateServiceUrl('not-a-url'),
          'URL must start with http:// or https://',
        );
      });

      test('rejects bare http scheme', () {
        expect(
          UrlUtils.validateServiceUrl('http://'),
          'Enter a valid URL (e.g. http://192.168.1.100:7878)',
        );
      });

      test('rejects bare https scheme', () {
        expect(
          UrlUtils.validateServiceUrl('https://'),
          'Enter a valid URL (e.g. http://192.168.1.100:7878)',
        );
      });

      test('accepts localhost with port', () {
        expect(UrlUtils.validateServiceUrl('http://localhost:7878'), isNull);
      });

      test('accepts fqdn over https', () {
        expect(
          UrlUtils.validateServiceUrl('https://radarr.mydomain.com'),
          isNull,
        );
      });

      test('accepts private ip with port', () {
        expect(
          UrlUtils.validateServiceUrl('http://192.168.1.100:8989'),
          isNull,
        );
      });

      test('accepts local hostname with port', () {
        expect(UrlUtils.validateServiceUrl('http://mynas.local:7878'), isNull);
      });

      test('accepts reverse proxy base path', () {
        expect(
          UrlUtils.validateServiceUrl('https://proxy.example.com/radarr'),
          isNull,
        );
      });

      test('accepts trailing slash', () {
        expect(UrlUtils.validateServiceUrl('http://10.0.0.1:7878/'), isNull);
      });

      test('accepts whitespace around valid URL', () {
        expect(
          UrlUtils.validateServiceUrl('  http://localhost:7878  '),
          isNull,
        );
      });
    });

    group('normalizeBaseUrl', () {
      test('trims whitespace', () {
        expect(
          UrlUtils.normalizeBaseUrl('  http://localhost:6789  '),
          'http://localhost:6789',
        );
      });

      test('prepends http:// when the scheme is missing', () {
        expect(
          UrlUtils.normalizeBaseUrl('nzbget.local:6789'),
          'http://nzbget.local:6789',
        );
      });

      test('strips a trailing slash', () {
        expect(
          UrlUtils.normalizeBaseUrl('https://proxy.example.com/nzbget/'),
          'https://proxy.example.com/nzbget',
        );
      });

      test('keeps a sub-path intact', () {
        expect(
          UrlUtils.normalizeBaseUrl('http://host/nzbget'),
          'http://host/nzbget',
        );
      });

      test('returns empty for empty input', () {
        expect(UrlUtils.normalizeBaseUrl('   '), '');
      });
    });
  });
}
