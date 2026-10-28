import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seekarr/features/auth/data/pkce.dart';
import 'package:seekarr/features/auth/data/oidc_session_service.dart';
import 'package:seekarr/features/auth/data/oidc_link_handler.dart';
import 'package:seekarr/features/auth/data/oidc_loopback_listener.dart';
import 'package:seekarr/features/auth/presentation/oidc_webview_screen.dart';
import 'package:seekarr/features/settings/data/settings_provider.dart';
import 'package:seekarr/features/settings/data/settings_service.dart';

class AuthSettingsScreen extends ConsumerStatefulWidget {
  const AuthSettingsScreen({super.key});

  @override
  ConsumerState<AuthSettingsScreen> createState() => _AuthSettingsScreenState();
}

class _AuthSettingsScreenState extends ConsumerState<AuthSettingsScreen> {
  SessionStatus _sessionStatus = SessionStatus.disabled;
  late final TextEditingController _issuerController;
  late final TextEditingController _clientIdController;
  bool _controllersSeeded = false;

  @override
  void dispose() {
    _issuerController.dispose();
    _clientIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    if (!_controllersSeeded) {
      _issuerController = TextEditingController(text: settings.oidcIssuer);
      _clientIdController = TextEditingController(text: settings.oidcClientId);
      _controllersSeeded = true;
    }
    ref.listen<String?>(oidcLinkResultProvider, (_, result) {
      if (result != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result)),
        );
        ref.read(oidcLinkResultProvider.notifier).state = null;
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('OIDC / Authentik')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _issuerController,
              decoration: const InputDecoration(labelText: 'Authentik Issuer URL'),
              onChanged: (v) {
                final latest = ref.read(settingsProvider);
                ref.read(settingsProvider.notifier).updateSettings(latest.copyWith(oidcIssuer: v));
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _clientIdController,
              decoration: const InputDecoration(labelText: 'Client ID'),
              onChanged: (v) {
                final latest = ref.read(settingsProvider);
                ref.read(settingsProvider.notifier).updateSettings(latest.copyWith(oidcClientId: v));
              },
            ),
            const SizedBox(height: 24),
            Text(_sessionStatus.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () async {
                    if (settings.oidcIssuer.isEmpty || settings.oidcClientId.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please configure OIDC settings first')),
                      );
                      return;
                    }
                    try {
                      final sess = OidcSessionService(createSecureSettingsStore());
                      final pkce = generatePkce();
                      final v = pkce.codeVerifier.replaceAll('=', '');
                      await sess.saveTokens(
                        access: '',
                        refresh: '',
                        expiryEpoch: 0,
                        pkceVerifier: v,
                      );

                      final disc = await sess.discover(settings.oidcIssuer);
                      final authUrl = disc['authorization_endpoint'] as String?;
                      if (authUrl == null) {
                        throw Exception('No authorization endpoint in discovery');
                      }
                      // Build authorize URL with redirect_uri matching Authentik's registered
                      // loopback URI (unchanged from original config). The WebView will intercept
                      // both http://127.0.0.1:8765/callback and seekarr://oauth/callback redirects,
                      // extracting ?code= or ?error= before the navigation completes.
                      final url = Uri.parse(authUrl).replace(queryParameters: <String, String>{
                        'client_id': settings.oidcClientId,
                        'response_type': 'code',
                        'scope': 'openid profile email offline_access',
                        'redirect_uri': OidcLoopbackListener.redirectUri, // registered Authentik value
                        'code_challenge': pkce.codeChallenge,
                        'code_challenge_method': 'S256',
                      });

                      // Push the WebView screen for in-app login.
                      await Navigator.of(context).push<String>(
                        MaterialPageRoute(
                          builder: (context) => OidcWebViewScreen(authorizeUrl: url),
                        ),
                      );

                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Login failed: ${e.toString()}')),
                        );
                      }
                    }
                  },
                  child: const Text('Login'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () async {
                    final sess = OidcSessionService(createSecureSettingsStore());
                    await sess.clear();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session cleared')));
                    }
                  },
                  child: const Text('Logout'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
