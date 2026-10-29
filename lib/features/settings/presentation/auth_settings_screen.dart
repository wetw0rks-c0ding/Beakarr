import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seekarr/features/auth/data/pkce.dart';
import 'package:seekarr/features/auth/data/oidc_session_service.dart';
import 'package:seekarr/features/auth/data/sonarr_oidc_session_provider.dart';
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
            Text(
              'Sonarr (pilot)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (OidcSessionService.isArrstackMode(settings.oidcIssuer))
              const Text('Single-tile mode: covered by the main login above.'),
            Text(
              (OidcSessionService.isArrstackMode(settings.oidcIssuer)
                      ? _sessionStatus
                      : _sonarrStatus)
                  .toString(),
            ),
            if (!OidcSessionService.isArrstackMode(settings.oidcIssuer))
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      if (settings.oidcIssuer.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please configure OIDC issuer first'),
                          ),
                        );
                        return;
                      }
                      try {
                        final sess = OidcSessionService(
                          createSecureSettingsStore(),
                        );
                        final sonarrIssuer =
                            OidcSessionService.perServiceIssuer(
                              settings.oidcIssuer,
                              'sonarr',
                            );
                        final sonarrClient =
                            OidcSessionService.perServiceClientId(
                              'sonarr',
                              settings.oidcIssuer,
                            );
                        final pkce = generatePkce();
                        final v = pkce.codeVerifier.replaceAll('=', '');
                        // Verifier only: a cancelled login must not wipe the
                        // existing Sonarr token pair.
                        await sess.savePkceVerifierFor('sonarr', v);

                        final disc = await sess.discover(sonarrIssuer);
                        final authUrl =
                            disc['authorization_endpoint'] as String?;
                        if (authUrl == null) {
                          throw Exception(
                            'No authorization endpoint in discovery',
                          );
                        }
                        final url = Uri.parse(authUrl).replace(
                          queryParameters: <String, String>{
                            'client_id': sonarrClient,
                            'response_type': 'code',
                            'scope': 'openid profile email offline_access',
                            'redirect_uri': OidcLoopbackListener.redirectUri,
                            'code_challenge': pkce.codeChallenge,
                            'code_challenge_method': 'S256',
                          },
                        );

                        final result = await Navigator.of(context).push<String>(
                          MaterialPageRoute(
                            builder: (context) =>
                                OidcWebViewScreen(authorizeUrl: url),
                          ),
                        );
                        if (result == null || result.isEmpty) {
                          await sess.deletePkceVerifierFor('sonarr');
                          return;
                        }
                        if (result.startsWith('error:')) {
                          await sess.deletePkceVerifierFor('sonarr');
                          throw Exception(
                            'Login failed: ${result.substring('error:'.length)}',
                          );
                        }
                        final ok = await sess.exchangeTokenFor(
                          service: 'sonarr',
                          issuerUrl: sonarrIssuer,
                          clientId: sonarrClient,
                          authorizationCode: result,
                          pkceVerifier: v,
                          redirectUri: OidcLoopbackListener.redirectUri,
                        );
                        if (context.mounted) {
                          setState(() {
                            _sonarrStatus = ok
                                ? SessionStatus.active
                                : SessionStatus.error;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok
                                    ? 'Sonarr login successful'
                                    : 'Sonarr login failed',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        await OidcSessionService(
                          createSecureSettingsStore(),
                        ).deletePkceVerifierFor('sonarr');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Sonarr login failed: ${e.toString()}',
                              ),
                            ),
                          );
                        }
                      }
                    },
                    child: const Text('Sonarr login'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      final sess = OidcSessionService(
                        createSecureSettingsStore(),
                      );
                      await sess.clearFor('sonarr');
                      SonarrOidcSessionProvider.clearAll();
                      if (context.mounted) {
                        setState(() => _sonarrStatus = SessionStatus.disabled);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Sonarr session cleared'),
                          ),
                        );
                      }
                    },
                    child: const Text('Sonarr logout'),
                  ),
                ],
              ),
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
    // + /me, per the Sonarr/Radarr/Prowlarr fork contract). Orange = SSO
    // identity exists but this host has no service token yet (exchange
    // pending/failed, or fork endpoints missing as with Prowlarr pre-land).
    // Red = no SSO identity at all.
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

    Color dotColor;
    String statusText;
    if (hasValidSession) {
      dotColor = Colors.green;
      statusText = 'Connected (SSO)';
    } else if (identityStatus == SessionStatus.active ||
        identityStatus == SessionStatus.error) {
      dotColor = Colors.orange;
      statusText = 'Connecting / error';
    } else {
      dotColor = Colors.red;
      statusText = 'No connection';
    }

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
