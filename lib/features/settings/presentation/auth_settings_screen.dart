import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seekarr/features/auth/data/pkce.dart';
import 'package:seekarr/features/auth/data/oidc_session_service.dart';
import 'package:seekarr/features/auth/data/sonarr_oidc_session_provider.dart';
import 'package:seekarr/features/auth/data/oidc_link_handler.dart';
import 'package:seekarr/features/auth/data/oidc_loopback_listener.dart';
import 'package:seekarr/features/auth/presentation/oidc_webview_screen.dart';
import 'package:seekarr/features/auth/presentation/soulsync_web_login_screen.dart';
import 'package:seekarr/features/settings/data/settings_provider.dart';
import 'package:seekarr/features/settings/data/settings_service.dart';

class AuthSettingsScreen extends ConsumerStatefulWidget {
  const AuthSettingsScreen({super.key});

  @override
  ConsumerState<AuthSettingsScreen> createState() => _AuthSettingsScreenState();
}

/// SSO dot truth table, extracted pure for unit testing.
///
/// A cached service token (real 200 exchange + /me) proves SSO live.
/// Otherwise an active identity plus a configured API key means the
/// service is reachable (dashboard status proves it independently) while
/// SSO idles — green, labelled honestly. Identity without key or token
/// is the only true warning state (exchange pending/failed). No
/// identity means no SSO connection, even if an API key exists.
(Color, String) ssoDotStateFor({
  required bool hasValidSession,
  required SessionStatus identity,
  required bool hasApiKey,
}) {
  if (hasValidSession) return (Colors.green, 'Connected (SSO)');
  final identityUp =
      identity == SessionStatus.active || identity == SessionStatus.error;
  if (identityUp && hasApiKey) return (Colors.green, 'Connected (API key)');
  if (identityUp) return (Colors.orange, 'Connecting / error');
  return (Colors.red, 'No connection');
}

/// API key for an SSO row's service (dynamic settings, same pattern as
/// the row builder below).
String _apiKeyFor(dynamic settings, String serviceKey) {
  final String key;
  switch (serviceKey) {
    case 'sonarr':
      key = settings.sonarrApiKey as String;
    case 'radarr':
      key = settings.radarrApiKey as String;
    case 'prowlarr':
      key = settings.prowlarrApiKey as String;
    default:
      return '';
  }
  return key;
}

class _AuthSettingsScreenState extends ConsumerState<AuthSettingsScreen> {
  SessionStatus _sessionStatus = SessionStatus.disabled;
  SessionStatus _sonarrStatus = SessionStatus.disabled;
  late final TextEditingController _issuerController;
  late final TextEditingController _clientIdController;
  bool _controllersSeeded = false;

  @override
  void initState() {
    super.initState();
    _loadStatuses();
  }

  Future<void> _loadStatuses() async {
    final sess = OidcSessionService(createSecureSettingsStore());
    final seekarr = await sess.sessionState();
    final settings = ref.read(settingsProvider);
    // ArrStack mode: Sonarr shares the main pair, so mirror its status.
    final sonarr = OidcSessionService.isArrstackMode(settings.oidcIssuer)
        ? seekarr
        : await sess.sessionStateFor('sonarr');
    if (mounted) {
      setState(() {
        _sessionStatus = seekarr;
        _sonarrStatus = sonarr;
      });
    }
  }

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result)));
        ref.read(oidcLinkResultProvider.notifier).state = null;
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('OIDC / Authentik')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            TextField(
              controller: _issuerController,
              decoration: const InputDecoration(
                labelText: 'Authentik Issuer URL',
              ),
              onChanged: (v) async {
                final latest = ref.read(settingsProvider);
                await ref
                    .read(settingsProvider.notifier)
                    .updateSettings(latest.copyWith(oidcIssuer: v));
                await _loadStatuses();
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _clientIdController,
              decoration: const InputDecoration(labelText: 'Client ID'),
              onChanged: (v) {
                final latest = ref.read(settingsProvider);
                ref
                    .read(settingsProvider.notifier)
                    .updateSettings(latest.copyWith(oidcClientId: v));
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton(
                  onPressed: () async {
                    final latest = ref.read(settingsProvider);
                    await ref
                        .read(settingsProvider.notifier)
                        .updateSettings(
                          latest.copyWith(
                            oidcIssuer: OidcSessionService.arrstackIssuer,
                            oidcClientId: OidcSessionService.arrstackClientId,
                          ),
                        );
                    _issuerController.text = OidcSessionService.arrstackIssuer;
                    _clientIdController.text =
                        OidcSessionService.arrstackClientId;
                    // Re-tap edge: issuer unchanged means updateSettings
                    // skipped its wipe, but a cached service token from a
                    // previous identity must not survive the switch.
                    SonarrOidcSessionProvider.clearAll();
                    await _loadStatuses();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'ArrStack preset applied — please log in again',
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Use ArrStack preset'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              _sessionStatus.toString(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () async {
                    if (settings.oidcIssuer.isEmpty ||
                        settings.oidcClientId.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please configure OIDC settings first'),
                        ),
                      );
                      return;
                    }
                    try {
                      final sess = OidcSessionService(
                        createSecureSettingsStore(),
                      );
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
                        throw Exception(
                          'No authorization endpoint in discovery',
                        );
                      }
                      // Build authorize URL with redirect_uri matching Authentik's registered
                      // loopback URI (unchanged from original config). The WebView will intercept
                      // both http://127.0.0.1:8765/callback and seekarr://oauth/callback redirects,
                      // extracting ?code= or ?error= before the navigation completes.
                      final url = Uri.parse(authUrl).replace(
                        queryParameters: <String, String>{
                          'client_id': settings.oidcClientId,
                          'response_type': 'code',
                          'scope': 'openid profile email offline_access',
                          'redirect_uri': OidcLoopbackListener
                              .redirectUri, // registered Authentik value
                          'code_challenge': pkce.codeChallenge,
                          'code_challenge_method': 'S256',
                        },
                      );

                      // Push the WebView screen for in-app login. It pops
                      // with the authorization code (or 'error:<desc>').
                      final result = await Navigator.of(context).push<String>(
                        MaterialPageRoute(
                          builder: (context) =>
                              OidcWebViewScreen(authorizeUrl: url),
                        ),
                      );
                      if (result == null || result.isEmpty) return;
                      if (result.startsWith('error:')) {
                        throw Exception(
                          'Login failed: ${result.substring('error:'.length)}',
                        );
                      }
                      final ok = await sess.exchangeToken(
                        issuerUrl: settings.oidcIssuer,
                        clientId: settings.oidcClientId,
                        authorizationCode: result,
                        pkceVerifier: v,
                        redirectUri: OidcLoopbackListener.redirectUri,
                      );
                      if (context.mounted) {
                        setState(() {
                          _sessionStatus = ok
                              ? SessionStatus.active
                              : SessionStatus.error;
                          // ArrStack mode: Sonarr shares the main pair, so
                          // mirror it (and drop any cache from a previous
                          // identity — the new login owns the token now).
                          if (OidcSessionService.isArrstackMode(
                            settings.oidcIssuer,
                          )) {
                            _sonarrStatus = _sessionStatus;
                            SonarrOidcSessionProvider.clearAll();
                          }
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok
                                  ? 'Login successful'
                                  : 'Login failed: token rejected',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Login failed: ${e.toString()}'),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Login'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () async {
                    final sess = OidcSessionService(
                      createSecureSettingsStore(),
                    );
                    await sess.clear();
                    // ArrStack mode: the Sonarr service token belongs to
                    // the main identity — drop it on logout so the next
                    // login cannot reuse the previous user's token.
                    if (OidcSessionService.isArrstackMode(
                      settings.oidcIssuer,
                    )) {
                      SonarrOidcSessionProvider.clearAll();
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Session cleared')),
                      );
                    }
                  },
                  child: const Text('Logout'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: (settings.soulsyncUrl.isNotEmpty &&
                                settings.soulsyncProxyCookie.isNotEmpty)
                            ? Colors.green
                            : Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SoulSync',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        (settings.soulsyncUrl.isNotEmpty &&
                                settings.soulsyncProxyCookie.isNotEmpty)
                            ? 'Cookie session active'
                            : 'Not logged in',
                      ),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: () async {
                              final result = await Navigator.of(context).push<String?>(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const SoulSyncWebLoginScreen(),
                                ),
                              );
                              if (result != null && result.isNotEmpty) {
                                final latest = ref.read(settingsProvider);
                                await ref
                                    .read(settingsProvider.notifier)
                                    .updateSettings(
                                      latest.copyWithSoulSync(
                                        url: latest.soulsyncUrl,
                                        proxyCookie: result,
                                      ),
                                    );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('SoulSync login saved'),
                                    ),
                                  );
                                }
                              }
                            },
                            child: const Text('Login'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () async {
                              final latest = ref.read(settingsProvider);
                              await ref
                                  .read(settingsProvider.notifier)
                                  .updateSettings(
                                    latest.copyWithSoulSync(
                                      url: latest.soulsyncUrl,
                                      proxyCookie: '',
                                    ),
                                  );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('SoulSync session cleared'),
                                  ),
                                );
                              }
                            },
                            child: const Text('Logout'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(),
            const Text(
              'SSO service connections',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildSsoServiceRow(
              context,
              label: 'Sonarr',
              serviceKey: 'sonarr',
              baseUrl: settings.sonarrUrl,
              settings: settings,
            ),
            _buildSsoServiceRow(
              context,
              label: 'Radarr',
              serviceKey: 'radarr',
              baseUrl: settings.radarrUrl,
              settings: settings,
            ),
            _buildSsoServiceRow(
              context,
              label: 'Prowlarr',
              serviceKey: 'prowlarr',
              baseUrl: settings.prowlarrUrl,
              settings: settings,
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
          ],
          ),
          ),
      ),
    );
  }

  Widget _buildSsoServiceRow(
    BuildContext context, {
    required String label,
    required String serviceKey,
    required String baseUrl,
    required dynamic settings,
  }) {
    final isArrstack = OidcSessionService.isArrstackMode(settings.oidcIssuer);
    final host = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    // Green = live service token cached for this host (real 200 exchange
    // + /me, per the Sonarr/Radarr/Prowlarr fork contract), or an active
    // identity plus a configured API key (traffic succeeds on keys, so
    // no exchange ever fires — green, labelled honestly). Orange = SSO
    // identity exists but this host has neither token nor key (exchange
    // pending/failed). Red = no SSO identity at all.
    final hasValidSession =
        host.isNotEmpty && SonarrOidcSessionProvider.hasValidSession(host);
    // Identity behind this row: shared main pair in ArrStack mode, the
    // per-service sonarr pair otherwise. Other services have no SSO
    // identity outside ArrStack mode.
    final SessionStatus identityStatus = isArrstack
        ? _sessionStatus
        : (serviceKey == 'sonarr'
              ? _sonarrStatus
              : SessionStatus.disabled);
    final hasApiKey = _apiKeyFor(settings, serviceKey).isNotEmpty;

    final (dotColor, statusText) = ssoDotStateFor(
      hasValidSession: hasValidSession,
      identity: identityStatus,
      hasApiKey: hasApiKey,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text('$label — $statusText'),
          ),
        ],
      ),
    );
  }
}
