import 'package:flutter/material.dart';
import 'package:seekarr/core/widgets/floating_bottom_nav_bar.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:seekarr/features/auth/data/callback_uri_helper.dart';
import 'package:seekarr/features/auth/data/oidc_loopback_listener.dart';

/// In-app WebView screen for OIDC login.
///
/// Loads the authorization page like a browser tab and intercepts the
/// redirect — either the loopback `http://127.0.0.1:8765/callback` or the
/// custom-scheme `seekarr://oauth/callback` — extracting `?code=`/`?error`
/// and popping with it. Returns null when the user backs out. The caller
/// performs the token exchange. The app_links custom-scheme listener stays
/// active as a fallback for external-browser flows.
class OidcWebViewScreen extends StatefulWidget {
  final Uri authorizeUrl;

  const OidcWebViewScreen({super.key, required this.authorizeUrl});

  @override
  State<OidcWebViewScreen> createState() => _OidcWebViewScreenState();
}

/// Popped result: authorization code on success, or an `error:<desc>` string.
class _OidcWebViewScreenState extends State<OidcWebViewScreen> {
  late final WebViewController controller;
  bool _done = false;

  static bool _isCallback(Uri uri) {
    if (CallbackUriHelper.isCallbackUri(uri)) return true;
    return uri.scheme == 'http' &&
        (uri.host == '127.0.0.1' || uri.host == 'localhost') &&
        uri.port == OidcLoopbackListener.port &&
        uri.path == OidcLoopbackListener.callbackPath;
  }

  void _finish(String? code, String? error) {
    if (_done || !mounted) return;
    _done = true;
    if (error != null && error.isNotEmpty) {
      Navigator.of(context).pop('error:$error');
    } else {
      Navigator.of(context).pop(code);
    }
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
            if (uri != null && _isCallback(uri)) {
              _finish(
                CallbackUriHelper.extractCode(uri),
                CallbackUriHelper.extractError(uri),
              );
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageFinished: (String url) {
            // Fallback: some engines deliver the redirect without a
            // navigation-request callback.
            final uri = Uri.tryParse(url);
            if (uri != null && _isCallback(uri)) {
              _finish(
                CallbackUriHelper.extractCode(uri),
                CallbackUriHelper.extractError(uri),
              );
            }
          },
        ),
      )
      ..loadRequest(widget.authorizeUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log in'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      // Nav clearance: the login page must stay above the floating bar.
      body: Padding(
        padding: EdgeInsets.only(bottom: FloatingNavBarMetrics.getScrollViewBottomPadding(context)),
        child: WebViewWidget(controller: controller),
      ),
    );
  }
}
