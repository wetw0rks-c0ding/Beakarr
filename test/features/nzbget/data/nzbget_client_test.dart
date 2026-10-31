import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seekarr/features/nzbget/data/nzbget_client.dart';

import '../../../test_helpers/fake_api_client.dart';

/// [FakeApiClient] that also records every JSON-RPC body and whether the
/// client was closed.
class _RecordingApiClient extends FakeApiClient {
  final List<dynamic> postBodies = [];
  bool closed = false;

  @override
  Future<Response<dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) {
    postBodies.add(data);
    return super.post(
      path,
      data: data,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
    );
  }

  @override
  void close({bool force = false}) {
    closed = true;
  }
}

Map<String, dynamic> _ok(dynamic result) => {
  'version': '1.1',
  'id': 1,
  'result': result,
  'error': null,
};

Map<String, dynamic> _rpcError(int code, String message) => {
  'version': '1.1',
  'id': 1,
  'result': null,
  'error': {'code': code, 'message': message},
};

NzbgetClient _client(_RecordingApiClient api) => NzbgetClient(
  url: 'http://nzbget.local:6789',
  username: 'user',
  password: 'pass',
  apiClient: api,
);

void main() {
  group('NzbgetClient', () {
    test('posts a JSON-RPC envelope to /jsonrpc', () async {
      final api = _RecordingApiClient()..postResponseData = _ok('24.3');
      final client = _client(api);

      await client.call('version');

      expect(api.lastPostPath, '/jsonrpc');
      final body = api.lastPostData as Map<String, dynamic>;
      expect(body['version'], '1.1');
      expect(body['method'], 'version');
      expect(body['params'], isEmpty);
      expect(body['id'], isA<int>());
    });

    test('increments the JSON-RPC id monotonically', () async {
      final api = _RecordingApiClient()..postResponseData = _ok(true);
      final client = _client(api);

      await client.call('status');
      await client.call('status');

      final ids = api.postBodies
          .map((body) => (body as Map<String, dynamic>)['id'] as int)
          .toList();
      expect(ids, hasLength(2));
      expect(ids[1], greaterThan(ids[0]));
    });

    test('forwards positional params untouched', () async {
      final api = _RecordingApiClient()..postResponseData = _ok(true);
      final client = _client(api);

      await client.call('editqueue', [
        'GroupPause',
        '',
        [4, 5],
      ]);

      final body = api.lastPostData as Map<String, dynamic>;
      expect(body['method'], 'editqueue');
      expect(body['params'], [
        'GroupPause',
        '',
        [4, 5],
      ]);
    });

    test('unwraps result from the envelope', () async {
      final api = _RecordingApiClient()
        ..postResponseData = _ok({'DownloadRate': 5});
      final client = _client(api);

      final result = await client.call('status');

      expect(result, {'DownloadRate': 5});
    });

    test('maps an RPC error object to NzbgetRpcException', () async {
      final api = _RecordingApiClient()
        ..postResponseData = _rpcError(-32602, 'Invalid params');
      final client = _client(api);

      await expectLater(
        client.call('append', const []),
        throwsA(
          isA<NzbgetRpcException>()
              .having((e) => e.code, 'code', -32602)
              .having((e) => e.message, 'message', 'Invalid params'),
        ),
      );
    });

    test('maps HTTP 401 to NzbgetAuthException', () async {
      final api = _RecordingApiClient()
        ..postException = DioException(
          requestOptions: RequestOptions(path: '/jsonrpc'),
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: '/jsonrpc'),
            statusCode: 401,
          ),
        );
      final client = _client(api);

      await expectLater(
        client.call('version'),
        throwsA(
          isA<NzbgetAuthException>().having(
            (e) => e.message,
            'message',
            'HTTP 401',
          ),
        ),
      );
    });

    test('propagates non-auth transport errors untouched', () async {
      final api = _RecordingApiClient()
        ..postException = DioException(
          requestOptions: RequestOptions(path: '/jsonrpc'),
          type: DioExceptionType.connectionError,
        );
      final client = _client(api);

      await expectLater(client.call('version'), throwsA(isA<DioException>()));
    });

    test('getVersion returns the trimmed version string', () async {
      final api = _RecordingApiClient()..postResponseData = _ok('24.3');
      final client = _client(api);

      expect(await client.getVersion(), '24.3');
      expect((api.lastPostData as Map<String, dynamic>)['method'], 'version');
    });

    test('close closes the underlying ApiClient', () {
      final api = _RecordingApiClient();
      final client = _client(api);

      client.close();

      expect(api.closed, isTrue);
    });
  });
}
