import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// In-app WebView screen for OIDC login.
///
/// Displays the authorization page in a WebView and intercepts both
/// http://127.0.0.1:8765/callback (loopback server) and seekarr://oauth/callback
/// (custom scheme) redirects. Extracts ?code= or ?error= via URI parsing,
/// pops the screen returning the code (or error), and blocks navigation to prevent
/// any further redirects. The app_links custom-scheme listener remains active as
/// a fallback for cold-start scenarios.
class OidcWebViewScreen extends StatefulWidget {
  final Uri authorizeUrl;

  const OidcWebViewScreen({super.key, required this.authorizeUrl});

  @override
  State<OidcWebViewScreen> createState() => _OidcWebViewScreenState();
}

class _OidcWebViewScreenState extends State<OidcWebViewScreen> {
  late final WebViewController controller;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) async {
            // Block all navigation to prevent redirects from leaving the WebView
            // or reaching the loopback server. We parse the redirect here and
            // handle the code/error extraction before popping.
            final url = request.url;
            final requestUri = Uri.tryParse(url);

            if (requestUri != null && (requestUri.queryParameters.containsKey('code') || requestUri.queryParameters.containsKey('error'))) {
              // Extract query parameters by parsing manually since webview_flutter
              // doesn't expose them directly on WebResourceRequest
              final code = requestUri.queryParameters['code'];
              final error = requestUri.queryParameters['error'];

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  if (error != null && error.isNotEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Login failed: $error')),
                    );
                  } else if (code != null && code.isNotEmpty) {
                    Navigator.of(context).pop(code);
                  }
                }
              });
            }
            // Block the navigation by returning prevent
            return NavigationDecision.prevent;
          },
          onPageFinished: (String url) async {
            // If page finished without triggering onNavigationRequest (rare),
            // check for code/error in the final URL.
            final uri = Uri.parse(url);
            final code = uri.queryParameters['code'];
            final error = uri.queryParameters['error'];

            if (code != null || error != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Navigator.of(context).pop(code ?? error ?? '');
                }
              });
            }
          },
        ),
      )
      ..setBackgroundColor(const Color(0x00000000))
      ..loadRequest(Uri.parse(widget.authorizeUrl.toString()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFF121212),
        child: WebViewWidget(
          controller: controller,
        ),
      ),
    );
  }
}
