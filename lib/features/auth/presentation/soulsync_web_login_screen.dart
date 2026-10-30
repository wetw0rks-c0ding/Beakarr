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
///
/// Returns a `Cookie`-header-ready value built from the non-empty
/// session cookies the proxy/app mint, or null when no session exists.
///
/// LIVE EVIDENCE (device jar, 2026-10-30): `_soulsync_proxy` (the
/// oauth2-proxy session, cf. `_soulsync_proxy_csrf` on the 302) is parked
/// empty until a real Authentik login completes in this jar; `session`
/// (SoulSync's own profile cookie, `{"profile_id":N}`) appears once a
/// profile is picked. API calls need the proxy session; the profile
/// cookie alone 401s. Both are sent — servers ignore unknown cookies —
/// so whichever session is live authenticates.
String? findSoulSyncSessionCookie(Iterable<WebViewCookie> cookies) {
  final parts = <String>[];
  String? proxy;
  String? app;
  for (final c in cookies) {
    if (c.value.isEmpty) continue;
    if (c.name == '_soulsync_proxy') proxy ??= '${c.name}=${c.value}';
    if (c.name == 'session') app ??= '${c.name}=${c.value}';
  }
  if (proxy != null) parts.add(proxy);
  if (app != null) parts.add(app);
  if (parts.isEmpty) return null;
  return parts.join('; ');
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
  /// NOTE: the jar must be queried with the full app URL, not the bare
  /// domain: the proxy scopes `_soulsync_proxy` to Path=/soulsync and a
  /// bare-domain query filters path-scoped cookies out.
  static final Uri _cookieUrl = Uri.parse('https://piracyhub.win/soulsync/');

  Future<void> _checkCookies() async {
    if (_done || !mounted) return;
    try {
      final cookies = await WebViewCookieManager().getCookies(
        domain: _cookieUrl,
      );
      // ignore: avoid_print
      print(
        'DIAG-SOULSYNC jar=${cookies.map((c) => '${c.name}:${c.value.length}').join(",")}',
      );
      final session = findSoulSyncSessionCookie(cookies);
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
