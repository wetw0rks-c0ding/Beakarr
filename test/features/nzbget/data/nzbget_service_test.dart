import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seekarr/features/nzbget/data/nzbget_client.dart';
import 'package:seekarr/features/nzbget/data/nzbget_service.dart';
import 'package:seekarr/features/settings/data/settings_provider.dart';
import 'package:seekarr/features/settings/domain/settings_model.dart';

import '../../../test_helpers/fake_api_client.dart';

/// [FakeApiClient] with a FIFO of JSON-RPC responses and a record of every
/// request body, so retry sequencing is observable.
class _RpcApiClient extends FakeApiClient {
  final List<dynamic> postResponses = [];
  final List<dynamic> postBodies = [];

  @override
  Future<Response<dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) {
    postBodies.add(data);
    if (postResponses.isNotEmpty) {
      postResponseData = postResponses.removeAt(0);
    }
    return super.post(
      path,
      data: data,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
    );
  }
}

Map<String, dynamic> _ok(dynamic result) => {
  'version': '1.1',
  'id': 1,
  'result': result,
  'error': null,
};

Map<String, dynamic> _arityError() => {
  'version': '1.1',
  'id': 1,
  'result': null,
  'error': {'code': -32602, 'message': 'Invalid params'},
};

NzbgetService _service(_RpcApiClient api) => NzbgetService(
  NzbgetClient(
    url: 'http://nzbget.local:6789',
    username: 'user',
    password: 'pass',
    apiClient: api,
  ),
);

Map<String, dynamic> _body(_RpcApiClient api, [int index = -1]) =>
    (index == -1 ? api.postBodies.last : api.postBodies[index])
        as Map<String, dynamic>;

void main() {
  group('nzbgetServiceProvider', () {
    test('throws when NZBGet is not configured', () {
      final container = ProviderContainer(
        overrides: [
          currentSettingsProvider.overrideWith((ref) => const SettingsModel()),
        ],
      );
      addTearDown(container.dispose);

      expect(() => container.read(nzbgetServiceProvider), throwsException);
    });

    test('throws when only the password is missing', () {
      final container = ProviderContainer(
        overrides: [
          currentSettingsProvider.overrideWith(
            (ref) => const SettingsModel(
              nzbgetUrl: 'http://nzbget:6789',
              nzbgetUsername: 'user',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(() => container.read(nzbgetServiceProvider), throwsException);
    });

    test('creates a service when configured', () {
      final container = ProviderContainer(
        overrides: [
          currentSettingsProvider.overrideWith(
            (ref) => const SettingsModel(
              nzbgetUrl: 'http://nzbget:6789',
              nzbgetUsername: 'user',
              nzbgetPassword: 'pass',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(nzbgetServiceProvider), isA<NzbgetService>());
    });
  });

  group('NzbgetService reads', () {
    test('getStatus maps the status payload', () async {
      final api = _RpcApiClient()
        ..postResponseData = _ok({
          'RemainingSizeMB': 512,
          'DownloadedSizeMB': 2048,
          'DownloadRateLo': 1024,
          'DownloadPaused': true,
          'PostJobCount': 2,
          'FreeDiskSpaceMB': 40960,
        });
      final service = _service(api);

      final status = await service.getStatus();

      expect(_body(api)['method'], 'status');
      expect(status.remainingSizeMb, 512);
      expect(status.downloadedSizeMb, 2048);
      expect(status.downloadRateBps, 1024);
      expect(status.downloadPaused, isTrue);
      expect(status.isPaused, isTrue);
      expect(status.postJobCount, 2);
      expect(status.freeDiskSpaceMb, 40960);
    });

    test('getQueue maps listgroups entries and sends the offset', () async {
      final api = _RpcApiClient()
        ..postResponseData = _ok([
          {
            'NZBID': 11,
            'NZBName': 'Ubuntu',
            'Status': 'DOWNLOADING',
            'Category': 'linux',
            'FileSizeMB': 2000,
            'RemainingSizeMB': 500,
            'Health': 1000,
          },
        ]);
      final service = _service(api);

      final queue = await service.getQueue();

      expect(_body(api)['method'], 'listgroups');
      expect(_body(api)['params'], [0]);
      expect(queue, hasLength(1));
      expect(queue.single.id, 11);
      expect(queue.single.progress, 0.75);
    });

    test('getHistory asks for visible entries by default', () async {
      final api = _RpcApiClient()
        ..postResponseData = _ok([
          {
            'NZBID': 7,
            'NZBName': 'Done',
            'Status': 'SUCCESS/ALL',
            'Kind': 'NZB',
            'FileSizeMB': 100,
            'HistoryTime': 1700000000,
          },
        ]);
      final service = _service(api);

      final history = await service.getHistory();

      expect(_body(api)['method'], 'history');
      expect(_body(api)['params'], [false]);
      expect(history.single.id, 7);
      expect(history.single.succeeded, isTrue);
      expect(
        history.single.historyTime.millisecondsSinceEpoch,
        1700000000 * 1000,
      );
    });

    test('getHistory forwards includeHidden', () async {
      final api = _RpcApiClient()..postResponseData = _ok(<dynamic>[]);
      final service = _service(api);

      await service.getHistory(includeHidden: true);

      expect(_body(api)['params'], [true]);
    });

    test('tolerates a non-list queue payload', () async {
      final api = _RpcApiClient()..postResponseData = _ok({'oops': true});
      final service = _service(api);

      expect(await service.getQueue(), isEmpty);
    });
  });

  group('NzbgetService queue control', () {
    test('pauseQueue calls pausedownload with no params', () async {
      final api = _RpcApiClient()..postResponseData = _ok(true);
      final service = _service(api);

      await service.pauseQueue();

      expect(_body(api)['method'], 'pausedownload');
      expect(_body(api)['params'], isEmpty);
    });

    test('resumeQueue calls resumedownload with no params', () async {
      final api = _RpcApiClient()..postResponseData = _ok(true);
      final service = _service(api);

      await service.resumeQueue();

      expect(_body(api)['method'], 'resumedownload');
    });

    test('pauseItems sends GroupPause with the ids', () async {
      final api = _RpcApiClient()..postResponseData = _ok(true);
      final service = _service(api);

      await service.pauseItems([3, 4]);

      expect(_body(api)['method'], 'editqueue');
      expect(_body(api)['params'], [
        'GroupPause',
        '',
        [3, 4],
      ]);
    });

    test('resumeItems sends GroupResume with the ids', () async {
      final api = _RpcApiClient()..postResponseData = _ok(true);
      final service = _service(api);

      await service.resumeItems([3]);

      expect(_body(api)['params'], [
        'GroupResume',
        '',
        [3],
      ]);
    });

    test('deleteQueueItems sends GroupDelete (moves to history)', () async {
      final api = _RpcApiClient()..postResponseData = _ok(true);
      final service = _service(api);

      await service.deleteQueueItems([9]);

      expect(_body(api)['method'], 'editqueue');
      expect(_body(api)['params'], [
        'GroupDelete',
        '',
        [9],
      ]);
    });

    test('deleteHistoryItems sends HistoryFinalDelete', () async {
      final api = _RpcApiClient()..postResponseData = _ok(true);
      final service = _service(api);

      await service.deleteHistoryItems([9]);

      expect(_body(api)['params'], [
        'HistoryFinalDelete',
        '',
        [9],
      ]);
    });

    test('a false editqueue result becomes a StateError', () async {
      final api = _RpcApiClient()..postResponseData = _ok(false);
      final service = _service(api);

      await expectLater(service.pauseItems([1]), throwsA(isA<StateError>()));
    });

    test('a false pausedownload result becomes a StateError', () async {
      final api = _RpcApiClient()..postResponseData = _ok(false);
      final service = _service(api);

      await expectLater(service.pauseQueue(), throwsA(isA<StateError>()));
    });
  });

  group('NzbgetService.addUrl', () {
    test('sends the exact 11-element append list', () async {
      final api = _RpcApiClient()..postResponseData = _ok(true);
      final service = _service(api);

      await service.addUrl(
        'https://example.com/a.nzb',
        category: 'movies',
        priority: 50,
        paused: true,
        addToTop: false,
      );

      expect(_body(api)['method'], 'append');
      expect(_body(api)['params'], [
        '',
        'https://example.com/a.nzb',
        'movies',
        50,
        false,
        true,
        '',
        0,
        'SCORE',
        false,
        <dynamic>[],
      ]);
    });

    test('defaults match the documented append call', () async {
      final api = _RpcApiClient()..postResponseData = _ok(true);
      final service = _service(api);

      await service.addUrl('http://example.com/a.nzb');

      expect(_body(api)['params'], [
        '',
        'http://example.com/a.nzb',
        '',
        0,
        true,
        false,
        '',
        0,
        'SCORE',
        false,
        <dynamic>[],
      ]);
    });

    test('retries once without the last param on -32602', () async {
      final api = _RpcApiClient()
        ..postResponses.addAll([_arityError(), _ok(true)]);
      final service = _service(api);

      await service.addUrl('http://example.com/a.nzb');

      expect(api.postBodies, hasLength(2));
      final retry = _body(api)['params'] as List<dynamic>;
      expect(retry, hasLength(10));
      expect(retry.last, false);
    });

    test('retries a second time without the last two params', () async {
      final api = _RpcApiClient()
        ..postResponses.addAll([_arityError(), _arityError(), _ok(true)]);
      final service = _service(api);

      await service.addUrl('http://example.com/a.nzb');

      expect(api.postBodies, hasLength(3));
      final retry = _body(api)['params'] as List<dynamic>;
      expect(retry, hasLength(9));
      expect(retry.last, 'SCORE');
    });

    test('surfaces the RPC message after both arity retries fail', () async {
      final api = _RpcApiClient()
        ..postResponses.addAll([_arityError(), _arityError(), _arityError()]);
      final service = _service(api);

      await expectLater(
        service.addUrl('http://example.com/a.nzb'),
        throwsA(
          isA<NzbgetRpcException>()
              .having((e) => e.code, 'code', -32602)
              .having((e) => e.message, 'message', 'Invalid params'),
        ),
      );
      expect(api.postBodies, hasLength(3));
    });

    test('does not retry other RPC errors', () async {
      final api = _RpcApiClient()
        ..postResponseData = {
          'version': '1.1',
          'id': 1,
          'result': null,
          'error': {'code': -100, 'message': 'Could not resolve host'},
        };
      final service = _service(api);

      await expectLater(
        service.addUrl('http://example.com/a.nzb'),
        throwsA(isA<NzbgetRpcException>()),
      );
      expect(api.postBodies, hasLength(1));
    });
  });
}
