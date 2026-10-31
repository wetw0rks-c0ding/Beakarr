import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seekarr/core/utils/dynamic_map_utils.dart';
import 'package:seekarr/features/nzbget/data/nzbget_client.dart';
import 'package:seekarr/features/nzbget/domain/models/nzbget_history_item.dart';
import 'package:seekarr/features/nzbget/domain/models/nzbget_queue_item.dart';
import 'package:seekarr/features/nzbget/domain/models/nzbget_status.dart';
import 'package:seekarr/features/settings/data/settings_provider.dart';

/// NZBGet's `append` parameter order (v17+):
/// `NZBFilename, URL, Category, Priority, AddToTop, AddPaused, DupeKey,
/// DupeScore, DupeMode, AutoCategory, PPParameters`.
///
/// Pre-v17 servers lack `AutoCategory`, pre-v16 lack `PPParameters`; the arity
/// fallback in [NzbgetService.addUrl] retries without those trailing params.
const List<dynamic> _appendDupeDefaults = ['', 0, 'SCORE'];

final nzbgetServiceProvider = Provider<NzbgetService>((ref) {
  final settings = ref.watch(currentSettingsProvider);
  if (settings.nzbgetUrl.isEmpty ||
      settings.nzbgetUsername.isEmpty ||
      settings.nzbgetPassword.isEmpty) {
    throw Exception('NZBGet not configured');
  }
  final client = NzbgetClient(
    url: settings.nzbgetUrl,
    username: settings.nzbgetUsername,
    password: settings.nzbgetPassword,
  );
  ref.onDispose(client.close);
  return NzbgetService(client);
});

class NzbgetService {
  final NzbgetClient _client;

  NzbgetService(this._client);

  /// Server version without the leading `v` (e.g. `24.3`).
  Future<String> getVersion() => _client.getVersion();

  Future<NzbgetStatus> getStatus() async {
    final result = await _client.call('status');
    return NzbgetStatus.fromJson(_asMap(result));
  }

  Future<List<NzbgetQueueItem>> getQueue() async {
    final result = await _client.call('listgroups', [0]);
    return _items(result, NzbgetQueueItem.fromJson);
  }

  /// Finished downloads. [includeHidden] asks for hidden entries too
  /// (`history(true)`); the default matches the WebUI's visible list.
  Future<List<NzbgetHistoryItem>> getHistory({
    bool includeHidden = false,
  }) async {
    final result = await _client.call('history', [includeHidden]);
    return _items(result, NzbgetHistoryItem.fromJson);
  }

  Future<void> pauseQueue() => _expectAccepted('pausedownload');

  Future<void> resumeQueue() => _expectAccepted('resumedownload');

  Future<void> pauseItems(List<int> ids) => _editQueue('GroupPause', ids);

  Future<void> resumeItems(List<int> ids) => _editQueue('GroupResume', ids);

  /// Removes queue items and moves them to history (`GroupDelete`).
  Future<void> deleteQueueItems(List<int> ids) =>
      _editQueue('GroupDelete', ids);

  /// Final-deletes history items (`HistoryFinalDelete`).
  Future<void> deleteHistoryItems(List<int> ids) =>
      _editQueue('HistoryFinalDelete', ids);

  /// Adds an NZB by URL.
  ///
  /// Sends the full 11-element `append` list. Older servers reject the newer
  /// trailing params with `-32602`; retry once without the last param and once
  /// more without the last two, then surface the server message verbatim.
  Future<void> addUrl(
    String url, {
    String category = '',
    int priority = 0,
    bool paused = false,
    bool addToTop = true,
  }) async {
    final full = <dynamic>[
      '',
      url,
      category,
      priority,
      addToTop,
      paused,
      ..._appendDupeDefaults,
      false,
      <dynamic>[],
    ];
    var params = full;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await _client.call('append', params);
        return;
      } on NzbgetRpcException catch (e) {
        if (e.code != -32602 || params.length <= full.length - 2) rethrow;
        params = params.sublist(0, params.length - 1);
      }
    }
  }

  Future<void> _editQueue(String command, List<int> ids) async {
    final result = await _client.call('editqueue', [command, '', ids]);
    if (result == false) {
      throw StateError('NZBGet rejected $command');
    }
  }

  Future<void> _expectAccepted(String method) async {
    final result = await _client.call(method);
    if (result == false) {
      throw StateError('NZBGet rejected $method');
    }
  }

  static Map<String, dynamic> _asMap(dynamic value) => mapOrNull(value) ?? {};

  static List<T> _items<T>(
    dynamic result,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (result is! List) return const [];
    final items = <T>[];
    for (final item in result) {
      final map = mapOrNull(item);
      if (map != null) items.add(fromJson(map));
    }
    return items;
  }
}
