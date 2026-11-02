import 'package:seekarr/features/openmediavault/data/openmediavault_client.dart';
import 'package:seekarr/features/openmediavault/domain/models/omv_disk.dart';
import 'package:seekarr/features/openmediavault/domain/models/omv_filesystem.dart';
import 'package:seekarr/features/openmediavault/domain/models/omv_service_status.dart';
import 'package:seekarr/features/openmediavault/domain/models/omv_smart_device.dart';
import 'package:seekarr/features/openmediavault/domain/models/omv_system_info.dart';

class OpenMediaVaultService {
  final OpenMediaVaultClient client;

  OpenMediaVaultService(this.client);

  static const _listParams = <String, dynamic>{
    'start': 0,
    'limit': -1,
    'sortfield': null,
    'sortdir': 'ASC',
  };

  Future<OmvSystemInfo> getSystemInfo() async {
    final response = await client.rpc('System', 'getInformation', const {});
    final map = response is Map<String, dynamic>
        ? response
        : (response is Map ? Map<String, dynamic>.from(response) : <String, dynamic>{});
    return OmvSystemInfo.fromJson(map);
  }

  Future<List<OmvFilesystem>> getFilesystems() async {
    final response = await client.rpc('FileSystemMgmt', 'getList', _listParams);
    return _items(response, OmvFilesystem.fromJson);
  }

  Future<List<OmvDisk>> getDisks() async {
    final response = await client.rpc('DiskMgmt', 'getList', _listParams);
    return _items(response, OmvDisk.fromJson);
  }

  Future<List<OmvSmartDevice>> getSmartDevices() async {
    final response = await client.rpc('Smart', 'getList', _listParams);
    return _items(response, OmvSmartDevice.fromJson);
  }

  Future<List<OmvServiceStatus>> getServices() async {
    final response = await client.rpc('Services', 'getStatus', const {});
    if (response is Map) {
      final data = response['data'];
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => OmvServiceStatus.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    }
    if (response is List) {
      return response
          .whereType<Map>()
          .map((e) => OmvServiceStatus.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  static List<T> _items<T>(
    dynamic response,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    dynamic data = response;
    if (response is Map) {
      data = response['data'];
    }
    if (data is! List) return const [];
    final items = <T>[];
    for (final item in data) {
      final map = item is Map<String, dynamic>
          ? item
          : (item is Map ? Map<String, dynamic>.from(item) : null);
      if (map != null) items.add(fromJson(map));
    }
    return items;
  }
}