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
/// Returns a `Cookie`-header-ready value, or null when no session exists.
///
/// The ONLY cookie that counts is the oauth2-proxy session
/// `_soulsync_proxy` (non-empty, minted by /oauth2/callback after a real
/// Authentik login). Everything else in the jar is decoration: `session`
/// is SoulSync's own profile cookie and authenticates nothing at the
/// proxy (verified: API with profile-cookie-only → 401 from oauth2-proxy,
/// which 401s API-style requests instead of redirecting). Accepting
/// `session` alone caused instant flash-close "logins" with no session.
String? findSoulSyncSessionCookie(Iterable<WebViewCookie> cookies) {
  for (final c in cookies) {
    if (c.name == '_soulsync_proxy' && c.value.isNotEmpty) {
      return '${c.name}=${c.value}';
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
            final isApp = uri != null && _isAppPage(uri);
            // ignore: avoid_print
            print('DIAG-SOULSYNC pageFinished url=$url app=$isApp');
            if (isApp) {
              // Only finish when the proxy actually minted a session
              // cookie. Empty/missing values happen on redirect-chain
              // finishes, cleared cookies, and error pages — popping
              // then would close the screen before the user can log in.
              await _checkCookies();
            }
          },
        ),
      );
    // Login must reflect LIVE auth state, never a cached shell: a cached
    // app page would show logged-in UI with no session behind it. Clear
    // first, then load.
    // ignore: avoid_print
    controller.clearCache().whenComplete(() {
      print('DIAG-SOULSYNC cache cleared');
      if (mounted) {
        controller.loadRequest(Uri.parse('https://piracyhub.win/soulsync/'));
      }
    });
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
