import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seekarr/features/openmediavault/data/openmediavault_client.dart';
import 'package:seekarr/features/openmediavault/data/openmediavault_service.dart';
import 'package:seekarr/features/openmediavault/domain/models/omv_disk.dart';
import 'package:seekarr/features/openmediavault/domain/models/omv_filesystem.dart';
import 'package:seekarr/features/openmediavault/domain/models/omv_service_status.dart';
import 'package:seekarr/features/openmediavault/domain/models/omv_smart_device.dart';
import 'package:seekarr/features/openmediavault/domain/models/omv_system_info.dart';
import 'package:seekarr/features/settings/data/settings_provider.dart';

final openMediaVaultClientProvider = Provider<OpenMediaVaultClient>((ref) {
  final s = ref.watch(currentSettingsProvider);
  if (s.openmediavaultUrl.isEmpty ||
      s.openmediavaultUsername.isEmpty ||
      s.openmediavaultPassword.isEmpty) {
    throw Exception('OpenMediaVault not configured');
  }
  return OpenMediaVaultClient(
    url: s.openmediavaultUrl,
    username: s.openmediavaultUsername,
    password: s.openmediavaultPassword,
  );
});

final openMediaVaultServiceProvider = Provider<OpenMediaVaultService>((ref) {
  final client = ref.watch(openMediaVaultClientProvider);
  ref.onDispose(client.close);
  return OpenMediaVaultService(client);
});

final omvSystemInfoProvider =
    FutureProvider.autoDispose<OmvSystemInfo>((ref) async {
  final service = ref.watch(openMediaVaultServiceProvider);
  return service.getSystemInfo();
});

final omvFilesystemsProvider =
    FutureProvider.autoDispose<List<OmvFilesystem>>((ref) async {
  final service = ref.watch(openMediaVaultServiceProvider);
  return service.getFilesystems();
});

final omvDisksProvider = FutureProvider.autoDispose<List<OmvDisk>>((ref) async {
  final service = ref.watch(openMediaVaultServiceProvider);
  return service.getDisks();
});

final omvSmartDevicesProvider =
    FutureProvider.autoDispose<List<OmvSmartDevice>>((ref) async {
  final service = ref.watch(openMediaVaultServiceProvider);
  return service.getSmartDevices();
});

final omvServicesProvider =
    FutureProvider.autoDispose<List<OmvServiceStatus>>((ref) async {
  final service = ref.watch(openMediaVaultServiceProvider);
  return service.getServices();
});