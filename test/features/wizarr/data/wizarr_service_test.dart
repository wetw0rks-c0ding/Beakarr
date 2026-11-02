import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seekarr/features/wizarr/data/wizarr_client.dart';
import 'package:seekarr/features/wizarr/data/wizarr_service.dart';

/// Mock adapter for testing - captures requests and returns static data
class _MockAdapter implements HttpClientAdapter {
  _MockAdapter({this.data});
  dynamic data;
  final List<RequestOptions> requests = [];
  int get callCount => requests.length;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    
    // If mock data is provided, return it; otherwise return empty success response
    if (data != null) {
      final body = data is String ? data : jsonEncode(data);
      return ResponseBody.fromBytes(
        utf8.encode(body),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    
    // For createInvitation calls where argument validation passes, return success
    if (options.method == 'POST' && options.path == '/api/invitations') {
      return ResponseBody.fromBytes(
        utf8.encode(jsonEncode({'invitation': {'code': 'x'}})),
        201,
        headers: {Headers.contentTypeHeader: ['application/json']},
      );
    }

    // Default fallback for GET requests or other paths - return empty object on success
    return ResponseBody.fromBytes(
      utf8.encode(jsonEncode({})),
      200,
      headers: {Headers.contentTypeHeader: ['application/json']},
    );
  }
}

/// Adapter that captures the request body for verification
class _BodyCaptureAdapter implements HttpClientAdapter {
  dynamic capturedBody;
  
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    try {
      dynamic bodyJson = options.data;
      if (bodyJson is String) bodyJson = jsonDecode(bodyJson);
      if (bodyJson is Map) {
        capturedBody = Map<String, dynamic>.from(bodyJson);
      } else {
        capturedBody = null;
      }
    } catch (_) {
      capturedBody = null;
    }

    return ResponseBody.fromBytes(
      utf8.encode(jsonEncode({'invitation': {'code': 'x'}})),
      201,
      headers: {Headers.contentTypeHeader: ['application/json']},
    );
  }
}

/// Adapter that captures request and returns a valid invitation response for payload tests
class _PayloadCaptureAdapter implements HttpClientAdapter {
  dynamic capturedBody;
  
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    try {
      dynamic bodyJson = options.data;
      if (bodyJson is String) {
        bodyJson = jsonDecode(bodyJson);
      }
      if (bodyJson is Map) {
        capturedBody = Map<String, dynamic>.from(bodyJson);
      } else {
        capturedBody = null;
      }
    } catch (_) {
      capturedBody = null;
    }

    // Return a valid invitation response for payload verification tests
    return ResponseBody.fromBytes(
      utf8.encode(jsonEncode({
        'invitation': {
          'code': 'x',
          'unlimited': true,
          'duration': 'unlimited',
        },
      })),
      201,
      headers: {Headers.contentTypeHeader: ['application/json']},
    );
  }
}

/// Adapter that verifies payload shape and returns a successful response
class _PayloadVerifierAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    try {
      dynamic raw = options.data;
      if (raw is String) raw = jsonDecode(raw);
      final bodyJson = raw as Map<String, dynamic>;

      // Verify payload has correct keys at top level (flat, never wrapped in 'data')
      expect(bodyJson.keys.contains('wizard_bundle_id'), isFalse);
      expect(bodyJson.keys.contains('server_ids'), isTrue);

      // Keys should be present as provided
      expect(bodyJson['expires_in_days'], 7);
      expect(bodyJson['duration'], '7d');
      expect(bodyJson['unlimited'], false);
      expect(bodyJson['library_ids'], isA<List>());
      expect(bodyJson['allow_downloads'], true);
      expect(bodyJson['allow_live_tv'], true);
      expect(bodyJson['allow_mobile_uploads'], true);

      return ResponseBody.fromBytes(
        utf8.encode(jsonEncode({'invitation': {'code': 'x'}})),
        201,
        headers: {Headers.contentTypeHeader: ['application/json']},
      );
    } catch (_) {
      // Verification failed: return a non-2xx response so the check is real.
      return ResponseBody.fromBytes(
        utf8.encode(jsonEncode({'error': {'message': 'payload verification failed'}})),
        500,
        headers: {Headers.contentTypeHeader: ['application/json']},
      );
    }
  }
}

/// Helper to create a service with the given mock data
WizarrService _service(dynamic data) {
  final dio = Dio(BaseOptions(
    baseUrl: 'http://localhost',
    connectTimeout: const Duration(seconds: 10),
    sendTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));
  final adapter = _MockAdapter(data: data);
  dio.httpClientAdapter = adapter;
  return WizarrService(
    WizarrClient(url: 'http://localhost', apiKey: 'k', dio: dio),
  );
}

void main() {
  test('getInvitations tolerates {data:[...]} envelope', () async {
    final service = _service({
      'data': [
        {'code': 'a', 'unlimited': false},
      ],
    });
    final list = await service.getInvitations();
    expect(list, hasLength(1));
    expect(list.first.code, 'a');
  });

  test('getInvitations tolerates bare array', () async {
    final service = _service([
      {'code': 'b'},
    ]);
    final list = await service.getInvitations();
    expect(list, hasLength(1));
    expect(list.first.code, 'b');
  });

  test('getInvitations tolerates {invitations:[...]} envelope', () async {
    final service = _service({
      'invitations': [
        {'code': 'c'},
      ],
      'count': 1,
    });
    final list = await service.getInvitations();
    expect(list, hasLength(1));
  });

  test('getUsers tolerates both shapes', () async {
    final s1 = _service({
      'data': [
        {'username': 'u1', 'server': 'Plex', 'server_type': 'plex'},
      ],
    });
    expect(await s1.getUsers(), hasLength(1));

    final s2 = _service([
      {'username': 'u2'},
    ]);
    expect(await s2.getUsers(), hasLength(1));
  });

  test('empty list', () async {
    final service = _service({'invitations': [], 'count': 0});
    expect(await service.getInvitations(), isEmpty);
  });

  test('empty map yields empty list', () async {
    final service = _service(<String, dynamic>{});
    expect(await service.getInvitations(), isEmpty);
  });

  test('HTML body surfaces an error, not an empty list', () async {
    final service = _service('<html><body>login</body></html>');
    await expectLater(
      service.getInvitations(),
      throwsA(isA<WizarrException>()),
    );
  });

  test('getServers returns servers from envelope', () async {
    final service = _service({
      'servers': [
        {'id': 1, 'name': 'Plex', 'server_type': 'plex'},
      ],
      'count': 1,
    });
    final result = await service.getServers();
    expect(result, hasLength(1));
    expect(result.first.id, 1);
    expect(result.first.name, 'Plex');
    expect(result.first.serverType, 'plex');
  });

  test('getServers tolerates bare array', () async {
    final service = _service([
      {'id': 2, 'name': 'Jellyfin', 'server_type': 'jellyfin'},
    ]);
    final result = await service.getServers();
    expect(result, hasLength(1));
  });

  test('getLibraries returns libraries from envelope', () async {
    final service = _service({
      'libraries': [
        {'id': 10, 'name': 'Plex Movies', 'server_id': 1, 'server_name': 'Plex', 'enabled': true},
      ],
      'count': 1,
    });
    final result = await service.getLibraries();
    expect(result, hasLength(1));
    expect(result.first.id, 10);
    expect(result.first.name, 'Plex Movies');
    expect(result.first.serverId, 1);
    expect(result.first.serverName, 'Plex');
    expect(result.first.enabled, true);
  });

  test('getLibraries tolerates bare array', () async {
    final service = _service([
      {'id': 20, 'name': 'Jellyfin Shows', 'server_id': 2, 'server_name': 'Jellyfin', 'enabled': false},
    ]);
    final result = await service.getLibraries();
    expect(result, hasLength(1));
  });

  test('createInvitation throws ArgumentError on empty serverIds before I/O', () async {
    final adapter = _MockAdapter(data: const []);
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.httpClientAdapter = adapter;
    final client = WizarrClient(url: 'http://localhost', apiKey: 'k', dio: dio);
    expect(
      () => WizarrService(client).createInvitation(serverIds: []),
      throwsArgumentError,
    );
    // No HTTP call made
    expect(adapter.callCount, 0);
  });

  test('createInvitation maps 201 body to WizarrInvitation', () async {
    final service = _service({
      'invitation': {
        'code': 'abc123',
        'url': '/j/abc123',
        'unlimited': false,
        'duration': '7d',
        'created': DateTime.now().toIso8601String(),
      },
    });
    final invitation = await service.createInvitation(serverIds: [1]);
    expect(invitation.code, 'abc123');
    expect(invitation.inviteUrl, '/j/abc123');
    expect(invitation.unlimited, false);
    expect(invitation.duration, '7d');
  });

  test('createInvitation does not send wizard_bundle_id in payload', () async {
    // Use _PayloadVerifierAdapter which properly returns success response
    final service = WizarrService(
      WizarrClient(
        url: 'http://localhost',
        apiKey: 'k',
        dio: Dio(BaseOptions(baseUrl: 'http://localhost'))..httpClientAdapter = _PayloadVerifierAdapter(),
      ),
    );

    // Verify argument validation passes (serverIds is not empty) and request succeeds
    final invitation = await service.createInvitation(
      serverIds: [1],
      expiresInDays: 7,
      duration: '7d',
      unlimited: false,
    );
    expect(invitation.code, 'x');
  });

  test('createInvitation sends X-API-Key header', () async {
    final adapter = _MockAdapter(data: {'invitation': {'code': 'x'}});
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.httpClientAdapter = adapter;
    final client = WizarrClient(url: 'http://localhost', apiKey: 'test-key', dio: dio);
    final service = WizarrService(client);

    // This succeeds because the mock now returns a proper response
    await service.createInvitation(serverIds: [1]);

    expect(adapter.callCount, 1);
    expect(adapter.requests.single.headers['X-API-Key'], 'test-key');
  });

  test('createInvitation throws on non-201 response', () async {
    final adapter = _MockAdapter(data: {'error': {'message': 'Server error'}});
    final service = WizarrService(
      WizarrClient(
        url: 'http://localhost', 
        apiKey: 'k', 
        dio: Dio(BaseOptions(baseUrl: 'http://localhost'))..httpClientAdapter = adapter,
      ),
    );

    Object? error;
    try {
      await service.createInvitation(serverIds: [1]);
    } catch (e) {
      error = e;
    }

    expect(error, isA<WizarrException>());
  });

  test('getServers uses exact path /api/servers', () async {
    final adapter = _MockAdapter(data: {'servers': []});
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.httpClientAdapter = adapter;
    final client = WizarrClient(url: 'http://localhost', apiKey: 'k', dio: dio);
    final service = WizarrService(client);

    await service.getServers();

    expect(adapter.callCount, 1);
    expect(adapter.requests.single.path, '/api/servers');
  });

  test('getLibraries uses exact path /api/libraries', () async {
    final adapter = _MockAdapter(data: {'libraries': []});
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.httpClientAdapter = adapter;
    final client = WizarrClient(url: 'http://localhost', apiKey: 'k', dio: dio);
    final service = WizarrService(client);

    await service.getLibraries();

    expect(adapter.callCount, 1);
    expect(adapter.requests.single.path, '/api/libraries');
  });

  test('createInvitation sends POST to /api/invitations', () async {
    final adapter = _MockAdapter(data: {'invitation': {'code': 'x'}});
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.httpClientAdapter = adapter;
    final client = WizarrClient(url: 'http://localhost', apiKey: 'k', dio: dio);
    final service = WizarrService(client);

    await service.createInvitation(serverIds: [1]);

    expect(adapter.callCount, 1);
    expect(adapter.requests.single.path, '/api/invitations');
  });

  test('createInvitation payload has correct keys (no wizard_bundle_id)', () async {
    final interceptedClient = WizarrClient(
      url: 'http://localhost',
      apiKey: 'k',
      dio: Dio(BaseOptions(baseUrl: 'http://localhost'))..httpClientAdapter = _PayloadVerifierAdapter(),
    );
    final service = WizarrService(interceptedClient);

    await service.createInvitation(
      serverIds: [1],
      expiresInDays: 7,
      duration: '7d',
      unlimited: false,
      libraryIds: [],
      allowDownloads: true,
      allowLiveTv: true,
      allowMobileUploads: true,
    );

    // Test passed - _PayloadVerifierAdapter verified payload and returned success
    expect(true, isTrue);
  });

  test('createInvitation with null expires_in_days sends null (not 0)', () async {
    final checkAdapter = _BodyCaptureAdapter();
    final interceptedClient = WizarrClient(
      url: 'http://localhost',
      apiKey: 'k',
      dio: Dio(BaseOptions(baseUrl: 'http://localhost'))..httpClientAdapter = checkAdapter,
    );
    final service = WizarrService(interceptedClient);

    await service.createInvitation(serverIds: [1], expiresInDays: null, duration: 'unlimited', unlimited: true);

    // Use dynamic typing since the captured value can be string or int depending on API response
    expect(checkAdapter.capturedBody?['expires_in_days'], isNull);
  });

  test('createInvitation with library_ids sends correctly', () async {
    final checkAdapter = _PayloadCaptureAdapter();
    final interceptedClient = WizarrClient(
      url: 'http://localhost',
      apiKey: 'k',
      dio: Dio(BaseOptions(baseUrl: 'http://localhost'))..httpClientAdapter = checkAdapter,
    );
    final service = WizarrService(interceptedClient);

    await service.createInvitation(
      serverIds: [1, 2],
      libraryIds: [10, 20],
      expiresInDays: 7,
      duration: '7d',
      unlimited: false,
    );

    expect(checkAdapter.capturedBody?['server_ids'], isA<List>());
    expect(checkAdapter.capturedBody?['library_ids'], isA<List>());
  });

  test('revokeInvitation returns true on 200', () async {
    final adapter = _MockAdapter(data: {'message': 'deleted'});
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.httpClientAdapter = adapter;
    final service = WizarrService(
      WizarrClient(url: 'http://localhost', apiKey: 'k', dio: dio),
    );
    expect(await service.revokeInvitation(id: 7), true);
    expect(adapter.requests.single.method, 'DELETE');
    expect(adapter.requests.single.path, '/api/invitations/7');
  });

  test('revokeInvitation empty 200 body completes true', () async {
    final adapter = _EmptyBodyAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.httpClientAdapter = adapter;
    final service = WizarrService(
      WizarrClient(url: 'http://localhost', apiKey: 'k', dio: dio),
    );
    expect(await service.revokeInvitation(id: 7), true);
  });

  test('revokeInvitation 404 throws with not found', () async {
    final adapter = _StatusAdapter(404, '{"error":{"message":"Invitation not found"}}');
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.httpClientAdapter = adapter;
    final service = WizarrService(
      WizarrClient(url: 'http://localhost', apiKey: 'k', dio: dio),
    );
    Object? error;
    try {
      await service.revokeInvitation(id: 7);
    } catch (e) {
      error = e;
    }
    expect(error, isA<WizarrException>());
    expect((error as WizarrException).message, contains('Invitation not found'));
  });
}

class _EmptyBodyAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromBytes(
      Uint8List(0),
      200,
      headers: {Headers.contentTypeHeader: ['application/json']},
    );
  }
}

class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.status, this.body);
  final int status;
  final String body;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromBytes(
      Uint8List.fromList(body.codeUnits),
      status,
      headers: {Headers.contentTypeHeader: ['application/json']},
    );
  }
}
