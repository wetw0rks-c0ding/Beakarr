import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seekarr/features/settings/data/settings_provider.dart';
import 'package:seekarr/features/wizarr/data/wizarr_client.dart';
import 'package:seekarr/features/wizarr/data/wizarr_service.dart';
import 'package:seekarr/features/wizarr/domain/models/wizarr_invitation.dart';
import 'package:seekarr/features/wizarr/domain/models/wizarr_library.dart';
import 'package:seekarr/features/wizarr/domain/models/wizarr_server.dart';
import 'package:seekarr/features/wizarr/domain/models/wizarr_user.dart';

final wizarrClientProvider = Provider<WizarrClient>((ref) {
  final s = ref.watch(currentSettingsProvider);
  if (s.wizarrUrl.isEmpty || s.wizarrApiKey.isEmpty) {
    throw Exception('Wizarr not configured');
  }
  return WizarrClient(url: s.wizarrUrl, apiKey: s.wizarrApiKey);
});

final wizarrServiceProvider = Provider<WizarrService>((ref) {
  final client = ref.watch(wizarrClientProvider);
  ref.onDispose(client.close);
  return WizarrService(client);
});

final wizarrInvitationsProvider =
    FutureProvider.autoDispose<List<WizarrInvitation>>((ref) async {
      final service = ref.watch(wizarrServiceProvider);
      return service.getInvitations();
    });

final wizarrUsersProvider = FutureProvider.autoDispose<List<WizarrUser>>((
  ref,
) async {
  final service = ref.watch(wizarrServiceProvider);
  return service.getUsers();
});

final wizarrServersProvider =
    FutureProvider.autoDispose<List<WizarrServer>>((ref) async {
      final service = ref.watch(wizarrServiceProvider);
      return service.getServers();
    });

final wizarrLibrariesProvider =
    FutureProvider.autoDispose<List<WizarrLibrary>>((ref) async {
      final service = ref.watch(wizarrServiceProvider);
      return service.getLibraries();
    });
