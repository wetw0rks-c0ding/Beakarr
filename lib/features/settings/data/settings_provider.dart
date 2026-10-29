import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seekarr/features/auth/data/sonarr_oidc_session_provider.dart';
import 'package:seekarr/features/settings/data/settings_service.dart';
import 'package:seekarr/features/settings/domain/settings_model.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize this in main.dart');
});

final secureSettingsStoreProvider = Provider<SecureSettingsStore>((ref) {
  return createSecureSettingsStore();
});

final initialSettingsProvider = Provider<SettingsModel>((ref) {
  throw UnimplementedError('Initialize this in main.dart');
});

final settingsServiceProvider = Provider<SettingsService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final secureStore = ref.watch(secureSettingsStoreProvider);
  return SettingsService(prefs, secureStore);
});

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsModel>(
  SettingsNotifier.new,
);

final currentSettingsProvider = Provider<SettingsModel>((ref) {
  return ref.watch(settingsProvider);
});

final regionProvider = Provider<String>((ref) {
  return ref.watch(currentSettingsProvider).region;
});

final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(currentSettingsProvider).resolvedThemeMode;
});

class SettingsNotifier extends Notifier<SettingsModel> {
  late final SettingsService _service;

  @override
  SettingsModel build() {
    _service = ref.watch(settingsServiceProvider);
    return ref.watch(initialSettingsProvider);
  }

  /// Serializes persistence work so overlapping calls (one per keystroke)
  /// cannot save out of order.
  Future<void> _pending = Future.value();

  Future<void> updateSettings(SettingsModel newSettings) async {
    // Issuer switch invalidates every stored token: the old Authentik
    // pairs were minted under the old issuer and every *arr fork rejects
    // them with 401 invalid_token (exact ValidIssuer match, fail closed).
    // Compare normalized (trimmed, no trailing slash) so a cosmetic edit
    // does not wipe sessions. State assigns before the awaits so a second
    // keystroke reads fresh state instead of overwriting the first change.
    String norm(String s) => s.trim().replaceAll(RegExp(r'/+$'), '');
    final issuerChanged = norm(state.oidcIssuer) != norm(newSettings.oidcIssuer);
    state = newSettings;
    final work = _pending.then((_) async {
      if (issuerChanged) {
        await _service.clearOidcSessions();
        SonarrOidcSessionProvider.clearAll();
      }
      // Persist the latest state, not the captured snapshot: a newer call
      // may have updated state while this work was queued.
      await _service.saveSettings(state);
    });
    // Keep the chain alive on failure, but still surface the error here.
    _pending = work.then((_) {}, onError: (_) {});
    await work;
  }

  Future<void> resetSettings() async {
    await _service.clearAll();
    state = const SettingsModel();
  }
}
