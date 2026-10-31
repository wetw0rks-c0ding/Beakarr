import 'dart:convert';
import 'dart:io';
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
import 'package:seekarr/features/settings/domain/oidc_preset.dart';
import 'package:seekarr/features/settings/domain/oidc_preset_validator.dart';

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
  late final TextEditingController _presetOriginController;
  late final TextEditingController _presetSlugController;
  late final TextEditingController _presetNameController;
  late final TextEditingController _presetClientIdController;
  bool _validating = false;
  String? _originErrorText;
  String? _slugErrorText;
  bool _presetClientEdited = false;
  bool _showSuccessPanel = false;
  String? _validatedIssuerHost;

  @override
  void initState() {
    super.initState();
    _presetOriginController = TextEditingController();
    _presetSlugController = TextEditingController();
    _presetNameController = TextEditingController();
    _presetClientIdController = TextEditingController();
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
    _presetOriginController.dispose();
    _presetSlugController.dispose();
    _presetNameController.dispose();
    _presetClientIdController.dispose();
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
                      _issuerController.text =
                          OidcSessionService.arrstackIssuer;
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
              const Text(
                'Saved presets',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildPresetsSection(context, settings),
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
                            content: Text(
                              'Please configure OIDC settings first',
                            ),
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
                        final authUrl =
                            disc['authorization_endpoint'] as String?;
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
                          color:
                              (settings.soulsyncUrl.isNotEmpty &&
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
                                final result = await Navigator.of(context)
                                    .push<String?>(
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

  Widget _buildPresetsSection(BuildContext context, dynamic settings) {
    final presets = (settings.oidcPresets as List<dynamic>?) ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Origin + slug + Validate
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _presetOriginController,
                decoration: InputDecoration(
                  labelText: 'Server origin',
                  errorText: _originErrorText,
                  helperText: 'e.g. https://auth.example.com',
                ),
                onChanged: (_) {
                  setState(() {
                    _originErrorText = null;
                    // Inputs changed → prior validation is stale.
                    _showSuccessPanel = false;
                    _validatedIssuerHost = null;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _presetSlugController,
                decoration: InputDecoration(
                  labelText: 'Provider slug',
                  errorText: _slugErrorText,
                ),
                onChanged: (_) {
                  setState(() {
                    _slugErrorText = null;
                    // New slug → new client_id default; user-edit flag resets.
                    _presetClientEdited = false;
                    // Inputs changed → prior validation is stale.
                    _showSuccessPanel = false;
                    _validatedIssuerHost = null;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _validating
              ? null
              : () async {
                  setState(() {
                    _validating = true;
                    _originErrorText = null;
                    _slugErrorText = null;
                    _showSuccessPanel = false;
                  });
                  final validator = OidcPresetValidator(
                    fetch: (url) async {
                      // Contract: decoded JSON Map on HTTP 200, coded
                      // throw otherwise (validator maps 404→slug404,
                      // anything else→unreachable). A 200-with-non-JSON
                      // body is returned raw so the validator reports
                      // notOidc instead of a transport error.
                      final client = HttpClient();
                      try {
                        final req = await client.getUrl(Uri.parse(url));
                        final resp = await req.close();
                        final body = await resp.transform(utf8.decoder).join();
                        if (resp.statusCode == 404) {
                          throw Exception('404 Not Found');
                        }
                        if (resp.statusCode != 200) {
                          throw Exception('HTTP ${resp.statusCode}');
                        }
                        try {
                          return jsonDecode(body);
                        } catch (_) {
                          return body;
                        }
                      } finally {
                        client.close(force: true);
                      }
                    },
                  );
                  final res = await validator.validate(
                    origin: _presetOriginController.text,
                    slug: _presetSlugController.text,
                  );
                  if (!context.mounted) return;
                  setState(() {
                    _validating = false;
                    if (res.valid) {
                      _showSuccessPanel = true;
                      _validatedIssuerHost = res.canonicalIssuer;
                      // Prefill client_id from slug unless the user already
                      // overrode it (spec: stops overwriting once edited).
                      if (!_presetClientEdited) {
                        _presetClientIdController.text = _presetSlugController
                            .text
                            .trim()
                            .toLowerCase();
                      }
                      _presetNameController.clear();
                    } else {
                      _showSuccessPanel = false;
                      if (res.errorType == OidcValidationError.badOrigin) {
                        _originErrorText = res.error ?? 'Invalid origin';
                      } else if (res.errorType ==
                          OidcValidationError.unreachable) {
                        _originErrorText = res.error ?? 'Unreachable';
                      } else if (res.errorType == OidcValidationError.slug404) {
                        _slugErrorText = res.error ?? 'Slug not found';
                      } else if (res.errorType == OidcValidationError.notOidc) {
                        _originErrorText = res.error ?? 'Not OIDC metadata';
                      } else if (res.errorType ==
                          OidcValidationError.missingEndpoints) {
                        _originErrorText = res.error ?? 'Missing endpoints';
                      } else {
                        _originErrorText = res.error ?? 'Validation failed';
                      }
                    }
                  });
                },
          child: _validating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Validate'),
        ),
        // 3. Success panel: readable issuer + editable client_id + name + save
        if (_showSuccessPanel && _validatedIssuerHost != null) ...[
          const SizedBox(height: 12),
          TextFormField(
            enabled: false,
            initialValue: _validatedIssuerHost,
            decoration: const InputDecoration(
              labelText: 'Validated issuer host',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _presetClientIdController,
            decoration: InputDecoration(
              labelText: 'Client ID',
              helperText: 'Edit if different from slug',
            ),
            onChanged: (_) {
              setState(() => _presetClientEdited = true);
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _presetNameController,
            decoration: const InputDecoration(labelText: 'Preset name'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () async {
              final name = _presetNameController.text.trim();
              final clientId = _presetClientIdController.text.trim();
              final issuer = (_validatedIssuerHost ?? '').trim().replaceAll(
                RegExp(r'/+$'),
                '',
              );
              if (name.isEmpty) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Name required')));
                return;
              }
              if (clientId.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Client ID required')),
                );
                return;
              }
              final current = List<OidcPreset>.from(presets);
              final existing = current.cast<OidcPreset?>().firstWhere(
                (p) =>
                    p != null &&
                    p.name.trim().toLowerCase() == name.toLowerCase(),
                orElse: () => null,
              );
              if (existing != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Preset name already exists')),
                );
                return;
              }
              if (current.length >= 10) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Preset cap (10) reached')),
                );
                return;
              }
              final updated = [
                ...current,
                OidcPreset(name: name, issuer: issuer, clientId: clientId),
              ];
              final latest = ref.read(settingsProvider);
              await ref
                  .read(settingsProvider.notifier)
                  .updateSettings(latest.copyWith(oidcPresets: updated));
              _presetOriginController.clear();
              _presetSlugController.clear();
              _presetNameController.clear();
              _presetClientIdController.clear();
              _presetClientEdited = false;
              setState(() {
                _showSuccessPanel = false;
                _validatedIssuerHost = null;
              });
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Preset saved')));
              }
            },
            child: const Text('Save preset'),
          ),
        ],
        // 4. Rows
        ...presets.cast<OidcPreset>().map((p) {
          final isActive =
              p.issuer.trim().replaceAll(RegExp(r'/+$'), '') ==
                  (settings.oidcIssuer ?? '').trim().replaceAll(
                    RegExp(r'/+$'),
                    '',
                  ) &&
              p.clientId.trim() == (settings.oidcClientId ?? '').trim();
          return ListTile(
            leading: isActive
                ? const Icon(Icons.circle, color: Colors.green, size: 12)
                : null,
            title: Text(p.name),
            subtitle: Text(p.issuer.replaceAll(RegExp(r'/+$'), '')),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () async {
                final updated = presets
                    .cast<OidcPreset>()
                    .where(
                      (x) =>
                          x.name != p.name ||
                          x.issuer != p.issuer ||
                          x.clientId != p.clientId,
                    )
                    .toList();
                final latest = ref.read(settingsProvider);
                await ref
                    .read(settingsProvider.notifier)
                    .updateSettings(latest.copyWith(oidcPresets: updated));
              },
            ),
            onTap: () async {
              final settingsIssuer = (settings.oidcIssuer ?? '')
                  .trim()
                  .replaceAll(RegExp(r'/+$'), '');
              final presetIssuer = p.issuer.trim().replaceAll(
                RegExp(r'/+$'),
                '',
              );
              if (settingsIssuer == presetIssuer &&
                  (settings.oidcClientId ?? '').trim() == p.clientId.trim()) {
                return; // no-op
              }
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Switch provider?'),
                  content: const Text(
                    'Switching providers wipes login sessions — continue?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Continue'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                SonarrOidcSessionProvider.clearAll();
                final latest = ref.read(settingsProvider);
                // Client-only switches don't trip updateSettings' issuer
                // wipe, so clear OIDC pairs explicitly whenever anything
                // changed (no-op already returned above).
                await ref.read(settingsServiceProvider).clearOidcSessions();
                await ref
                    .read(settingsProvider.notifier)
                    .updateSettings(
                      latest.copyWith(
                        oidcIssuer: p.issuer,
                        oidcClientId: p.clientId,
                      ),
                    );
                _issuerController.text = p.issuer;
                _clientIdController.text = p.clientId;
                await _loadStatuses();
              }
            },
          );
        }),
        // 5. Empty placeholder
        if (presets.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No saved presets. Validate a provider above to save one.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
      ],
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
        : (serviceKey == 'sonarr' ? _sonarrStatus : SessionStatus.disabled);
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
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text('$label — $statusText')),
        ],
      ),
    );
  }
}
