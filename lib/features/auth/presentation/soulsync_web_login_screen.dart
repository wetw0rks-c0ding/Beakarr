import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// SoulSync cookie-login WebView: starts at the proxy login initiator
/// (forces a deterministic handshake: 302 → Authentik → /oauth2/callback
/// which mints `_soulsync_proxy` → rd back to the app), detects the
/// authed app page, reads the session cookies, pops with the value
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
/// The ONLY gate that counts is the oauth2-proxy session
/// `_soulsync_proxy` (non-empty, minted by /oauth2/callback after a real
/// Authentik login): without it the flow must stay open, never pop.
/// When it IS present, the full non-empty jar travels with it — the
/// in-WebView app authenticates its API with the whole set (verified:
/// single-cookie replays 401 while the page's own fetches succeed), and
/// servers ignore unknown cookies. Cosmetic-only `color-scheme` is still
/// excluded to keep the header to authentication material.
String? findSoulSyncSessionCookie(Iterable<WebViewCookie> cookies) {
  var proxyFound = false;
  final parts = <String>[];
  for (final c in cookies) {
    if (c.value.isEmpty) continue;
    if (c.name == '_soulsync_proxy') proxyFound = true;
    if (c.name == 'color-scheme') continue;
    parts.add('${c.name}=${c.value}');
  }
  if (!proxyFound || parts.isEmpty) return null;
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
  /// Jar query URL: the full app URL, not the bare domain — the proxy
  /// scopes `_soulsync_proxy` to Path=/soulsync and a bare-domain query
  /// filters path-scoped cookies out.
  static final Uri _cookieUrl = Uri.parse('https://piracyhub.win/soulsync/');

  /// Entry point: the proxy login initiator, so the handshake runs
  /// deterministically — loading the app URL directly may serve cached
  /// or anonymous content without ever hitting the gate.
  static final Uri _startUrl =
      Uri.parse('https://piracyhub.win/oauth2/start?rd=/soulsync/');

  /// One-shot in-page probe (DIAG only): location, JS-visible cookie
  /// names+lengths, and the status of the page's OWN profiles fetch.
  /// Distinguishes live-authenticated pages from cached shells.
  Future<void> _probePage() async {
    if (_done || !mounted) return;
    try {
      final href =
          await controller.runJavaScriptReturningResult('location.href');
      // ignore: avoid_print
      print('DIAG-SOULSYNC probe href=$href');
      final jar =
          await controller.runJavaScriptReturningResult('document.cookie');
      // ignore: avoid_print
      print('DIAG-SOULSYNC probe jscookies=$jar');
      final st = await controller.runJavaScriptReturningResult(
        "fetch('/soulsync/api/v1/profiles',{credentials:'same-origin'}).then(r=>r.status).catch(e=>'ERR:'+e)",
      );
      // ignore: avoid_print
      print('DIAG-SOULSYNC probe apiStatus=$st');
    } catch (e) {
      // ignore: avoid_print
      print('DIAG-SOULSYNC probe failed: $e');
    }
  }

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
        controller.loadRequest(_startUrl);
      }
    });
    // In-app actions (profile pick, SPA navigation) don't reload the
    // page, so onPageFinished never fires for them. Poll the jar instead:
    // the proxy sets the session cookie on login without navigating.
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _checkCookies();
    });
    // One in-page probe shortly after load settles (guarded: no-op once
    // finished or disposed).
    Future.delayed(const Duration(seconds: 10), () => _probePage());
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
