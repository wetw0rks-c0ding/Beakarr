import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seekarr/features/auth/data/sonarr_oidc_session_provider.dart';
import 'package:seekarr/features/settings/data/settings_provider.dart';

/// Host settings provider for Sonarr (base URL from settings).
final sonarrHostProvider = Provider<Object?>((ref) {
  final settings = ref.watch(currentSettingsProvider);
  if (settings.sonarrUrl.isEmpty) return null;
  return settings;
});

/// Permission cache state for Sonarr UI affordance gating.
class SonarrSessionState {
  final String baseUrl;
  final List<String> permissions;
  final String role;
  final bool hasValidSession;

  const SonarrSessionState({
    required this.baseUrl,
    this.permissions = const <String>[],
    this.role = 'ReadOnly',
    this.hasValidSession = false,
  });

  static SonarrSessionState fromCache(String baseUrl) {
    final session = SonarrOidcSessionProvider.getSonarrSession(baseUrl);
    if (session == null) {
      return const SonarrSessionState(
        baseUrl: '',
        permissions: <String>[],
        role: 'ReadOnly',
        hasValidSession: false,
      );
    }
    return SonarrSessionState(
      baseUrl: baseUrl,
      permissions: session.permissions,
      role: session.role,
      hasValidSession: true,
    );
  }

  static void clear(String baseUrl) {
    SonarrOidcSessionProvider.clear(baseUrl);
  }

  static SonarrSessionState? getOrNull(String baseUrl) {
    final session = SonarrOidcSessionProvider.getSonarrSession(baseUrl);
    if (session == null) return null;
    return SonarrSessionState(
      baseUrl: baseUrl,
      permissions: session.permissions,
      role: session.role,
      hasValidSession: true,
    );
  }

  @override
  String toString() => 'SonarrSessionState(baseUrl: $baseUrl, hasValidSession: $hasValidSession, '
      'role: $role, permissions: ${permissions.join(", ")})';
}

/// Per-host token cache in a Riverpod provider (in-memory only).
final sonarrOidcCacheProvider = Provider<Map<String, Map<String, dynamic>>>((ref) {
  final cache = <String, Map<String, dynamic>>{};
  for (final host in SonarrOidcSessionProvider.cachedHostKeys) {
    final session = SonarrOidcSessionProvider.getSonarrSession(host);
    if (session != null) {
      cache[host] = <String, dynamic>{
        'token': session.serviceToken,
        'permissions': session.permissions,
        'role': session.role,
        'expiresAtMs': session.expiresAtEpoch * 1000,
      };
    }
  }
  return cache;
});

/// Permission provider for Sonarr UI affordance gating (ONE button: Add Series / Manage).
/// Gates on permission 'UI.Add' for the add-series affordance.
final sonarrPermissionsProvider = FutureProvider<List<String>>((ref) async {
  final settings = ref.watch(currentSettingsProvider);
  if (settings.sonarrUrl.isEmpty) return <String>[];
  final state = SonarrSessionState.fromCache(settings.sonarrUrl);
  return Future.value(state.permissions);
});

/// Provider to check if user can add series (ONE UI affordance gate).
/// Requires 'UI.Add' permission string.
final useCanAdd = FutureProvider<bool>((ref) async {
  final settings = ref.watch(currentSettingsProvider);
  if (settings.sonarrUrl.isEmpty) return false;
  final permissions = await ref.read(sonarrPermissionsProvider.future);
  return permissions.contains('UI.Add');
});

/// Provider to get Sonarr session state for ONE UI affordance gating.
final sonarrSessionStateProvider = FutureProvider<SonarrSessionState>((ref) async {
  final settings = ref.watch(currentSettingsProvider);
  if (settings.sonarrUrl.isEmpty) {
    return const SonarrSessionState(baseUrl: '', hasValidSession: false);
  }
  return Future.value(SonarrSessionState.fromCache(settings.sonarrUrl));
});

/// Function to update Sonarr session state from exchange response.
void updateSonarrSessionState(String baseUrl, dynamic exchangeResponse) {
  if (exchangeResponse != null && exchangeResponse is Map<String, dynamic>) {
    SonarrOidcSessionProvider.update(baseUrl, exchangeResponse);
  } else {
    SonarrOidcSessionProvider.clear(baseUrl);
  }
}

/// Function to clear Sonarr session state.
void clearSonarrSessionState(String? baseUrl) {
  SonarrOidcSessionProvider.clear(baseUrl);
}
