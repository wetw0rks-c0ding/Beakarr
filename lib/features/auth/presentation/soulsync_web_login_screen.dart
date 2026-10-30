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

class _SoulSyncWebLoginScreenState extends State<SoulSyncWebLoginScreen> {
  late final WebViewController controller;
  bool _done = false;

  static bool _isAppPage(Uri uri) {
    final host = uri.host.toLowerCase();
    final path = uri.path;
    // Success = left auth.* host and not inside /oauth2/
    return !host.startsWith('auth.') && !path.startsWith('/oauth2/');
  }

  void _finish(String? cookie) {
    if (_done || !mounted) return;
    _done = true;
    Navigator.of(context).pop(cookie);
  }

  @override
  void initState() {
    super.initState();
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
            if (uri != null && _isAppPage(uri)) {
              try {
                String? proxyCookie;
                try {
                  final cookies = await WebViewCookieManager()
                      .getCookies(
                        domain: Uri.parse('https://piracyhub.win'),
                      );
                  for (final c in cookies) {
                    if (c.name == '_soulsync_proxy') {
                      proxyCookie = c.value;
                      break;
                    }
                  }
                } catch (_) {
                  proxyCookie = null;
                }
                _finish(proxyCookie);
              } catch (_) {
                // If cookie manager unavailable, fall back to finish with null
                _finish(null);
              }
            }
          },
        ),
      )
      ..loadRequest(Uri.parse('https://piracyhub.win/soulsync/'));
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
