import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// SoulSync cookie-login WebView: loads https://piracyhub.win/soulsync/,
/// detects when the user is past the auth gate (host not auth.* and
/// path not /oauth2/), reads the _soulsync_proxy cookie via
/// WebViewCookieManager for https://piracyhub.win, pops with the value
/// (null on back-out). No token exchange.
class SoulSyncWebLoginScreen extends StatefulWidget {
  const SoulSyncWebLoginScreen({super.key});

  @override
  State<SoulSyncWebLoginScreen> createState() => _SoulSyncWebLoginScreenState();
}

/// Session-cookie lookup, extracted pure for unit testing.
/// Returns the cookie value only when present AND non-empty: the proxy
/// parks an empty `_soulsync_proxy` on logged-out/cleared states, which
/// must not count as a session.
String? findSoulSyncProxyCookie(Iterable<WebViewCookie> cookies) {
  for (final c in cookies) {
    if (c.name == '_soulsync_proxy' && c.value.isNotEmpty) {
      return c.value;
    }
  }
  return null;
}

class _SoulSyncWebLoginScreenState extends State<SoulSyncWebLoginScreen> {
  late final WebViewController controller;
  bool _done = false;
  Timer? _pollTimer;

  static bool _isAppPage(Uri uri) {
    final host = uri.host.toLowerCase();
    final path = uri.path;
    // Success = left auth.* host and not inside /oauth2/
    return !host.startsWith('auth.') && !path.startsWith('/oauth2/');
  }

  void _finish(String? cookie) {
    if (_done || !mounted) return;
    _done = true;
    _pollTimer?.cancel();
    // ignore: avoid_print
    print(
      'DIAG-SOULSYNC finish cookie=${cookie == null ? "null" : "len=${cookie.length}"}',
    );
    Navigator.of(context).pop(cookie);
  }

  /// Single cookie-jar check shared by the page-finished hook and the
  /// poll timer. Only a non-empty session cookie finishes the flow.
  Future<void> _checkCookies() async {
    if (_done || !mounted) return;
    try {
      final cookies = await WebViewCookieManager().getCookies(
        domain: Uri.parse('https://piracyhub.win'),
      );
      // ignore: avoid_print
      print(
        'DIAG-SOULSYNC cookies=${cookies.map((c) => c.name).join(",")}',
      );
      final session = findSoulSyncProxyCookie(cookies);
      // ignore: avoid_print
      print('DIAG-SOULSYNC cookie=${session == null ? "null" : "len=${session.length}"}');
      if (session != null) _finish(session);
    } catch (_) {
      // Cookie store transiently unavailable; next poll retries.
    }
  }

  @override
  void initState() {
    super.initState();
    // ignore: avoid_print
    print('DIAG-SOULSYNC opened');
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri != null && _isAppPage(uri)) {
              // Pass through to let page finish; cookie read in onPageFinished
            }
            return NavigationDecision.navigate;
          },
          onPageFinished: (String url) async {
            final uri = Uri.tryParse(url);
            // ignore: avoid_print
            print('DIAG-SOULSYNC pageFinished url=$url app=${uri != null && _isAppPage(uri)}');
            if (uri != null && _isAppPage(uri)) {
              // Only finish when the proxy actually minted a session
              // cookie. Empty/missing values happen on redirect-chain
              // finishes, cleared cookies, and error pages — popping
              // then would close the screen before the user can log in.
              await _checkCookies();
            }
          },
        ),
      )
      ..loadRequest(Uri.parse('https://piracyhub.win/soulsync/'));
    // In-app actions (profile pick, SPA navigation) don't reload the
    // page, so onPageFinished never fires for them. Poll the jar instead:
    // the proxy sets the session cookie on login without navigating.
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _checkCookies();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SoulSync Login'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: WebViewWidget(controller: controller),
    );
  }
}
