import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:seekarr/features/auth/data/pkce.dart';
import 'package:seekarr/features/auth/data/oidc_session_service.dart';
import 'package:seekarr/features/auth/data/oidc_link_handler.dart';
import 'package:seekarr/features/auth/data/oidc_loopback_listener.dart';
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
                      final url = Uri.parse(authUrl).replace(queryParameters: <String, String>{
                        'client_id': settings.oidcClientId,
                        'response_type': 'code',
                        'scope': 'openid profile email offline_access',
                        // Loopback return: works in any browser (RFC 8252).
                        // The custom-scheme app_links listener stays as fallback.
                        'redirect_uri': OidcLoopbackListener.redirectUri,
                        'code_challenge': pkce.codeChallenge,
                        'code_challenge_method': 'S256',
                      });
                      // Bind loopback BEFORE launching the browser so the
                      // redirect has somewhere to land.
                      final codeFuture = OidcLoopbackListener.awaitCode();
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                      final code = await codeFuture;
                      final ok = await sess.exchangeToken(
                        issuerUrl: settings.oidcIssuer,
                        clientId: settings.oidcClientId,
                        authorizationCode: code,
                        pkceVerifier: v,
                        redirectUri: OidcLoopbackListener.redirectUri,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok ? 'Login successful' : 'Login failed: token rejected',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Login failed: ${e.toString()}')),
                      );
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
