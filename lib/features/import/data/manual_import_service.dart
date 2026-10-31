import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seekarr/core/api/api_client.dart';
import 'package:seekarr/core/api/service_auth.dart';
import 'package:seekarr/core/utils/dynamic_map_utils.dart';
import 'package:seekarr/features/import/domain/manual_import_models.dart';
import 'package:seekarr/features/settings/data/settings_provider.dart';
import 'package:seekarr/features/settings/domain/service_key.dart';

final manualImportServiceProvider =
    Provider.family<ManualImportService, ServiceKey>((ref, service) {
      if (!service.supportsManualImport) {
        throw Exception('${service.title} does not support manual import');
      }

      final settings = ref.watch(currentSettingsProvider);
      final baseUrl = settings.urlFor(service);
      final apiKey = settings.apiKeyFor(service);
      if (baseUrl.isEmpty || apiKey.isEmpty) {
        throw Exception('${service.title} not configured');
      }

      return ManualImportService(
        client: ApiClient(baseUrl: baseUrl, auth: ApiKeyHeaderAuth(apiKey)),
        service: service,
      );
    });

class ManualImportService {
  final ApiClient client;
  final ServiceKey service;

  const ManualImportService({required this.client, required this.service});

  String get _prefix => '/api/${service.apiVersion}';

  Future<List<ManualImportRootFolder>> getRootFolders() async {
    final response = await client.get('$_prefix/rootfolder');
    return _mappedList(
      response.data,
      ManualImportRootFolder.fromJson,
      where: (folder) => folder.path.isNotEmpty,
    );
  }

  Future<ManualImportFileSystemResult> getFileSystem(String path) async {
    final response = await client.get(
      '$_prefix/filesystem',
      queryParameters: {
        'path': path,
        'includeFiles': false,
        'allowFoldersWithoutTrailingSlashes': true,
      },
    );
    return ManualImportFileSystemResult.fromJson(stringKeyMap(response.data));
  }

  Future<List<ManualImportItem>> getManualImportItems({
    required String folder,
  }) async {
    final response = await client.get(
      '$_prefix/manualimport',
      queryParameters: {
        'folder': folder,
        'filterExistingFiles': true,
        if (service == ServiceKey.lidarr) 'replaceExistingFiles': false,
      },
    );
    return _mappedList(response.data, ManualImportItem.fromJson);
  }

  Future<List<ManualImportLookupResult>> lookup(String term) async {
    final normalized = term.trim();
    if (normalized.isEmpty) return const [];

    final response = await client.get(
      '$_prefix/${_lookupEndpoint()}',
      queryParameters: {'term': normalized},
    );
    return _mappedList(
      response.data,
      (item) => ManualImportLookupResult.fromJson(service, item),
      where: (item) => item.id > 0,
    );
  }

  Future<List<ManualImportLookupResult>> getLibraryMatches() async {
    final response = await client.get('$_prefix/${_libraryEndpoint()}');
    return _mappedList(
      response.data,
      (item) => ManualImportLookupResult.fromJson(service, item),
      where: (item) => item.id > 0,
    );
  }

  Future<ManualImportCommandStatus> importItem(
    ManualImportItem item, {
    required ManualImportMode importMode,
  }) async {
    final response = await client.post(
      '$_prefix/command',
      data: {
        'name': 'ManualImport',
        'importMode': importMode.apiValue,
        if (service == ServiceKey.lidarr) 'replaceExistingFiles': false,
        'files': [item.toCommandFileJson(service)],
      },
    );
    return ManualImportCommandStatus.fromJson(stringKeyMap(response.data));
  }

  Future<List<ManualImportEpisode>> getEpisodes({
    required int seriesId,
    int? seasonNumber,
  }) async {
    final response = await client.get(
      '$_prefix/episode',
      queryParameters: {
        'seriesId': seriesId,
        if (seasonNumber != null) 'seasonNumber': seasonNumber,
      },
    );
    return _mappedList(
      response.data,
      ManualImportEpisode.fromJson,
      where: (item) => item.id > 0,
    );
  }

  Future<List<ManualImportAlbum>> getAlbums(int artistId) async {
    final response = await client.get(
      '$_prefix/album',
      queryParameters: {'artistId': artistId},
    );
    return _mappedList(
      response.data,
      ManualImportAlbum.fromJson,
      where: (item) => item.id > 0,
    );
  }

  Future<List<ManualImportTrack>> getTracks({required int albumId}) async {
    final response = await client.get(
      '$_prefix/track',
      queryParameters: {'albumId': albumId},
    );
    return _mappedList(
      response.data,
      ManualImportTrack.fromJson,
      where: (item) => item.id > 0,
    );
  }

  Future<List<ManualImportQualityOption>> getQualityOptions() async {
    final response = await client.get('$_prefix/qualitydefinition');
    return _mappedList(
      response.data,
      ManualImportQualityOption.fromJson,
      where: (item) => item.id > 0,
    );
  }

  Future<List<ManualImportLanguageOption>> getLanguageOptions() async {
    final response = await client.get('$_prefix/language');
    return _mappedList(
      response.data,
      ManualImportLanguageOption.fromJson,
      where: (item) => item.id > 0,
    );
  }

  Future<ManualImportCommandStatus> startManualImport(
    List<ManualImportItem> files, {
    required ManualImportMode importMode,
  }) async {
    final response = await client.post(
      '$_prefix/command',
      data: {
        'name': 'ManualImport',
        'importMode': importMode.apiValue,
        if (service == ServiceKey.lidarr) 'replaceExistingFiles': false,
        'files': files
            .map((item) => item.toCommandFileJson(service))
            .toList(growable: false),
      },
    );
    return ManualImportCommandStatus.fromJson(stringKeyMap(response.data));
  }

  Future<ManualImportCommandStatus> getCommand(int commandId) async {
    final response = await client.get('$_prefix/command/$commandId');
    return ManualImportCommandStatus.fromJson(stringKeyMap(response.data));
  }

  String _lookupEndpoint() {
    return switch (service) {
      ServiceKey.radarr => 'movie/lookup',
      ServiceKey.sonarr => 'series/lookup',
      ServiceKey.lidarr => 'artist/lookup',
      _ => throw ArgumentError('${service.title} does not support lookup'),
    };
  }

  String _libraryEndpoint() {
    return switch (service) {
      ServiceKey.radarr => 'movie',
      ServiceKey.sonarr => 'series',
      ServiceKey.lidarr => 'artist',
      _ => throw ArgumentError('${service.title} does not support lookup'),
    };
  }
}

List<Map<String, dynamic>> _listData(dynamic data) {
  final list = data is List ? data : const [];
  return list
      .map(mapOrNull)
      .whereType<Map<String, dynamic>>()
      .toList(growable: false);
}

List<T> _mappedList<T>(
  dynamic data,
  T Function(Map<String, dynamic>) fromJson, {
  bool Function(T item)? where,
}) {
  final items = _listData(data).map(fromJson);
  return (where == null ? items : items.where(where)).toList(growable: false);
}
