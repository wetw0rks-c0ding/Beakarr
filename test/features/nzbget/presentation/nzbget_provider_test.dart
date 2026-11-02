import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seekarr/features/nzbget/data/nzbget_client.dart';
import 'package:seekarr/features/nzbget/data/nzbget_service.dart';
import 'package:seekarr/features/nzbget/presentation/nzbget_provider.dart';

import '../../../test_helpers/fake_api_client.dart';

/// [FakeApiClient] that records JSON-RPC bodies so polling traffic is
/// attributable to a method.
class _RpcApiClient extends FakeApiClient {
  final List<dynamic> postBodies = [];

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

  int countMethod(String method) => postBodies
      .where((body) => (body as Map<String, dynamic>)['method'] == method)
      .length;
}

Map<String, dynamic> _ok(dynamic result) => {
  'version': '1.1',
  'id': 1,
  'result': result,
  'error': null,
};

ProviderContainer _container(_RpcApiClient api) {
  final client = NzbgetClient(
    url: 'http://nzbget.local:6789',
    username: 'user',
    password: 'pass',
    apiClient: api,
  );
  return ProviderContainer(
    overrides: [nzbgetServiceProvider.overrideWithValue(NzbgetService(client))],
  );
}

void main() {
  test('queue provider surfaces service errors unchanged', () async {
    final api = _RpcApiClient()
      ..postException = const NzbgetRpcException(-32000, 'Access denied');
    final container = _container(api);
    addTearDown(container.dispose);

    // Riverpod 3 retries failed providers, so `.future` may not settle on the
    // first error; observe the first AsyncError instead.
    final firstError = Completer<Object>();
    final sub = container.listen(nzbgetQueueProvider, (_, next) {
      final error = next.error;
      if (error != null && !firstError.isCompleted) {
        firstError.complete(error);
      }
    });
    addTearDown(sub.close);

    final error = await firstError.future.timeout(const Duration(seconds: 5));
    expect(
      error,
      isA<NzbgetRpcException>().having(
        (e) => e.message,
        'message',
        'Access denied',
      ),
    );
  });

  test('selection set can be extended and cleared', () {
    final container = _container(_RpcApiClient());
    addTearDown(container.dispose);

    final notifier = container.read(nzbgetSelectionProvider.notifier);
    notifier.state = {1, 2, 3};
    expect(container.read(nzbgetSelectionProvider), {1, 2, 3});

    notifier.state = {};
    expect(container.read(nzbgetSelectionProvider), isEmpty);
  });

  testWidgets('polling refreshes status and queue but never history', (
    tester,
  ) async {
    final api = _RpcApiClient()..postResponseData = _ok(<dynamic>[]);
    final container = _container(api);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SizedBox.shrink(),
      ),
    );

    container.listen(nzbgetPollingProvider, (_, __) {});
    container.listen(nzbgetStatusProvider, (_, __) {});
    container.listen(nzbgetQueueProvider, (_, __) {});
    container.listen(nzbgetHistoryProvider, (_, __) {});

    await tester.pump();
    expect(api.countMethod('status'), 1);
    expect(api.countMethod('listgroups'), 1);
    expect(api.countMethod('history'), 1);

    await tester.pump(const Duration(seconds: 5));
    await tester.pump();

    expect(api.countMethod('status'), 2);
    expect(api.countMethod('listgroups'), 2);
    expect(api.countMethod('history'), 1);

    container.read(nzbgetPollingEnabledProvider.notifier).state = false;
    await tester.pump();
    final statusCalls = api.countMethod('status');
    final queueCalls = api.countMethod('listgroups');

    await tester.pump(const Duration(seconds: 10));
    await tester.pump();

    expect(api.countMethod('status'), statusCalls);
    expect(api.countMethod('listgroups'), queueCalls);
  });
}
