import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:seekarr/features/auth/data/pkce.dart';
import 'package:seekarr/features/auth/data/oidc_session_service.dart';
import 'package:seekarr/features/settings/data/settings_provider.dart';
import 'package:seekarr/features/settings/data/settings_service.dart';

class AuthSettingsScreen extends ConsumerWidget {
  const AuthSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final flowReady = settings.oidcIssuer.isNotEmpty && settings.oidcClientId.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('OIDC / Authentik')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: TextEditingController(text: settings.oidcIssuer),
              decoration: const InputDecoration(labelText: 'Authentik Issuer URL'),
              onChanged: (v) {
                final latest = ref.read(settingsProvider);
                ref.read(settingsProvider.notifier).updateSettings(latest.copyWith(oidcIssuer: v));
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: TextEditingController(text: settings.oidcClientId),
              decoration: const InputDecoration(labelText: 'Client ID'),
              onChanged: (v) {
                final latest = ref.read(settingsProvider);
                ref.read(settingsProvider.notifier).updateSettings(latest.copyWith(oidcClientId: v));
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton(
                  onPressed: flowReady ? () async {
                    final sess = OidcSessionService(FlutterSecureSettingsStore(FlutterSecureStorage()));
                    final pkce = generatePkce();
                    final v = pkce.codeVerifier.replaceAll('=', '');
                    await sess.saveTokens(access: '', refresh: '', expiryEpoch: 0, pkceVerifier: v);
                    try {
                      final disc = await sess.discover(settings.oidcIssuer);
                      final authUrl = disc['authorization_endpoint'] as String?;
                      if (authUrl != null) {
                        final url = Uri.parse(authUrl).replace(queryParameters: {
                          'client_id': settings.oidcClientId,
                          'response_type': 'code',
                          'scope': 'openid profile email',
                          'redirect_uri': 'seekarr://oauth/callback',
                          'code_challenge': pkce.codeChallenge,
                          'code_challenge_method': 'S256',
                        });
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    } catch (_) {}
                  } : null,
                  child: const Text('Login'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () async {
                    final sess = OidcSessionService(FlutterSecureSettingsStore(FlutterSecureStorage()));
                    await sess.clear();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session cleared')));
                    }
                  },
                  child: const Text('Logout'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Status: ${settings.oidcIssuer.isEmpty ? 'Disabled' : 'Configured'}'),
          ],
        ),
      ),
    );
  }
}
