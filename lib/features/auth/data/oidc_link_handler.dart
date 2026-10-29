import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: implementation_imports
import 'package:flutter_riverpod/legacy.dart';

import 'package:seekarr/features/auth/data/callback_uri_helper.dart';
import 'package:seekarr/features/auth/data/oidc_session_service.dart';
import 'package:seekarr/features/auth/data/sonarr_oidc_session_provider.dart';
import 'package:seekarr/features/settings/data/settings_provider.dart';

/// Latest OIDC callback result for the UI to surface. Null = nothing yet.
final oidcLinkResultProvider = StateProvider<String?>((ref) => null);

/// Subscribes to OS deep links once and completes the OIDC login loop.
///
/// Watch this once at app startup ([SeekarrApp]) so cold-start links are not
/// missed. Filters for `seekarr://oauth/callback`, exchanges `?code=` via
/// [OidcSessionService.exchangeToken], and publishes the outcome to
/// [oidcLinkResultProvider].
final oidcLinkHandlerProvider = Provider<void>((ref) {
  final store = ref.watch(secureSettingsStoreProvider);
  final appLinks = AppLinks();

  // Guard against handling the same authorization code twice (e.g. if the
  // OS redelivers the callback). Auth codes are single-use.
  String? handledCode;

  Future<void> handle(Uri uri) async {
    if (!CallbackUriHelper.isCallbackUri(uri)) return;
    final sess = OidcSessionService(store);
    final error = CallbackUriHelper.extractError(uri);
    if (error != null && error.isNotEmpty) {
      ref.read(oidcLinkResultProvider.notifier).state =
          'Login failed: $error';
      return;
    }
    final code = CallbackUriHelper.extractCode(uri);
    if (code == null || code.isEmpty || code == handledCode) return;
    handledCode = code;
    final settings = ref.read(settingsProvider);
    final verifier = await sess.pkceVerifier;
    if (verifier == null || verifier.isEmpty) {
      ref.read(oidcLinkResultProvider.notifier).state =
          'Login failed: session expired, try again';
      return;
    }
    try {
      final ok = await sess.exchangeToken(
        issuerUrl: settings.oidcIssuer,
        clientId: settings.oidcClientId,
        authorizationCode: code,
        pkceVerifier: verifier,
        redirectUri: 'seekarr://oauth/callback',
      );
      if (ok &&
          OidcSessionService.isArrstackMode(settings.oidcIssuer)) {
        // New identity owns the fleet token now: drop any cached Sonarr
        // service token from the previous identity.
        SonarrOidcSessionProvider.clearAll();
      }
      ref.read(oidcLinkResultProvider.notifier).state =
          ok ? 'Login successful' : 'Login failed: token rejected';
    } catch (e) {
      ref.read(oidcLinkResultProvider.notifier).state = 'Login failed: $e';
    }
  }

  // app_links >= 6 delivers the initial link through uriLinkStream, so no
  // separate getInitialLink call (avoids double-handling the same code).
  final sub = appLinks.uriLinkStream.listen(handle, onError: (_) {});
  ref.onDispose(sub.cancel);
});
