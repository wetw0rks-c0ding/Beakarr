import 'dart:async';
import 'dart:io';

/// Loopback redirect listener (RFC 8252 section 7.3) for OIDC login.
///
/// Some Android browsers (e.g. Gecko-based) will not hand a custom-scheme
/// redirect back to the OS, stranding the flow on an error page. A loopback
/// redirect (`http://127.0.0.1:<port>/callback`) loads in ANY browser and the
/// app reads the authorization code straight off the socket — no custom
/// scheme involved. Requires `http://127.0.0.1:8765/callback` registered as
/// a redirect URI on the Authentik provider.
class OidcLoopbackListener {
  static const int port = 8765;
  static const String callbackPath = '/callback';
  static String get redirectUri => 'http://127.0.0.1:$port$callbackPath';

  /// Binds 127.0.0.1, serves one callback request, and completes with the
  /// authorization `code`. Throws on provider `error`, missing code, or
  /// [timeout]. Always closes the server.
  static Future<String> awaitCode({
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    try {
      final request = await server.first.timeout(timeout);
      final code = request.uri.queryParameters['code'];
      final error = request.uri.queryParameters['error'];
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..write(
          '<html><body><h1>Login complete — return to Seekarr.</h1></body></html>',
        );
      await request.response.close();
      if (error != null && error.isEmpty == false) {
        throw Exception('Login failed: $error');
      }
      if (code == null || code.isEmpty) {
        throw Exception('Login failed: no code returned');
      }
      return code;
    } finally {
      await server.close(force: true);
    }
  }
}
