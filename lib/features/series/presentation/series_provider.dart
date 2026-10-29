import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seekarr/features/auth/data/sonarr_permissions_provider.dart';
import 'package:seekarr/features/series/domain/models/sonarr_series.dart';
import 'package:seekarr/features/series/data/sonarr_service.dart';
import 'package:seekarr/features/settings/data/settings_provider.dart';

final seriesProvider = FutureProvider<List<SonarrSeries>>((ref) async {
  final service = ref.watch(sonarrServiceProvider);
  return service.getSeries();
});

/// ONE UI affordance gate: add series button.
final useCanAdd = FutureProvider<bool>((ref) async {
  final settings = ref.watch(currentSettingsProvider);
  if (settings.sonarrUrl.isEmpty) return false;
  final perms = await ref.read(sonarrPermissionsProvider.future);
  return perms.contains('UI.Add');
});

/// Permissions for UI from Cache (gated by configured sonarrUrl).
final sonarrPermissionsForUi = FutureProvider<List<String>>((ref) async {
  final settings = ref.watch(currentSettingsProvider);
  if (settings.sonarrUrl.isEmpty) return <String>[];
  return SonarrSessionState.fromCache(settings.sonarrUrl).permissions;
});
