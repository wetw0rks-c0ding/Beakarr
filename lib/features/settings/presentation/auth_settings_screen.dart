import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seekarr/features/settings/data/settings_provider.dart';

/// Auth settings screen — mirrors existing service settings screen patterns.
/// Dedicated Auth section (NOT a fake 8th service); issuer/clientID are plain
/// URL fields (NOT secrets) consistent with service URL fields.
class AuthSettingsScreen extends ConsumerWidget {
  const AuthSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
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
              onChanged: (v) => ref.read(settingsProvider.notifier).updateSettings(settings.copyWith(oidcIssuer: v)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: TextEditingController(text: settings.oidcClientId),
              decoration: const InputDecoration(labelText: 'Client ID'),
              onChanged: (v) => ref.read(settingsProvider.notifier).updateSettings(settings.copyWith(oidcClientId: v)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () {/* login via url_launcher + PKCE */},
                  child: const Text('Login'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {/* clear session */},
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
