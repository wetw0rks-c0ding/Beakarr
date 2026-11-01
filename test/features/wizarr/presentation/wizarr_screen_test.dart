import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seekarr/features/wizarr/data/wizarr_client.dart';
import 'package:seekarr/features/wizarr/data/wizarr_providers.dart';
import 'package:seekarr/features/wizarr/data/wizarr_service.dart';
import 'package:seekarr/features/wizarr/domain/models/wizarr_invitation.dart';
import 'package:seekarr/features/wizarr/domain/models/wizarr_user.dart';
import 'package:seekarr/features/wizarr/presentation/wizarr_screen.dart';
import 'package:seekarr/features/wizarr/presentation/widgets/wizarr_invite_tile.dart';
import 'package:seekarr/features/wizarr/presentation/widgets/wizarr_user_tile.dart';
import 'package:seekarr/core/widgets/not_configured_placeholder.dart';

WizarrInvitation _liveInvite() => WizarrInvitation.fromJson({
  'id': 7,
  'code': 'code-123',
  'url': 'https://example.com/j/code-123',
  'status': 'active',
  'display_name': 'Weekend Guest',
  'server_names': ['Plex'],
  'unlimited': false,
  'expires': '2026-11-20T10:00:00Z',
  'created': '2026-10-20T10:00:00Z',
});

WizarrUser _liveUser() => WizarrUser.fromJson({
  'id': 3,
  'username': 'alice',
  'email': 'alice@example.com',
  'server': 'Plex',
  'server_type': 'plex',
  'expires': '2026-11-20T10:00:00Z',
  'created_at': '2026-10-20T10:00:00Z',
});

void main() {
  testWidgets('WizarrScreen renders tabs', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wizarrServiceProvider.overrideWith(
            (ref) => WizarrService(
              WizarrClient(url: 'https://wizarr.example.com', apiKey: 'k'),
            ),
          ),
          wizarrInvitationsProvider.overrideWith((ref) async => const []),
          wizarrUsersProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: WizarrScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Invitations'), findsOneWidget);
    expect(find.text('Users'), findsOneWidget);
  });

  testWidgets('empty state per tab', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wizarrServiceProvider.overrideWith(
            (ref) => WizarrService(
              WizarrClient(url: 'https://wizarr.example.com', apiKey: 'k'),
            ),
          ),
          wizarrInvitationsProvider.overrideWith((ref) async => const []),
          wizarrUsersProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: WizarrScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('No invitations'), findsOneWidget);

    await tester.tap(find.text('Users'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('No users'), findsOneWidget);
  });

  testWidgets('tab switch renders both tabs', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wizarrServiceProvider.overrideWith(
            (ref) => WizarrService(
              WizarrClient(url: 'https://wizarr.example.com', apiKey: 'k'),
            ),
          ),
          wizarrInvitationsProvider.overrideWith(
            (ref) async => [_liveInvite()],
          ),
          wizarrUsersProvider.overrideWith((ref) async => [_liveUser()]),
        ],
        child: const MaterialApp(home: WizarrScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(WizarrInviteTile), findsOneWidget);

    await tester.tap(find.text('Users'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(WizarrUserTile), findsOneWidget);

    await tester.tap(find.text('Invitations'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(WizarrInviteTile), findsOneWidget);
  });

  testWidgets('live-shaped populated models render', (tester) async {
    // Live v3 shapes (verified 2026-11-01 against real swagger).
    final liveInvite = WizarrInvitation.fromJson(const {
      'id': 9,
      'code': 'live-code',
      'url': 'https://wizarr.example.com/j/live-code',
      'status': 'active',
      'display_name': 'Live Guest',
      'server_names': ['Jellyfin'],
      'unlimited': false,
      'expires': '2030-01-01T00:00:00.000Z',
      'created': '2024-01-01T00:00:00.000Z',
    });
    final liveUser = WizarrUser.fromJson(const {
      'id': 4,
      'username': 'bob',
      'email': 'bob@example.com',
      'server': 'Jellyfin',
      'server_type': 'jellyfin',
      'expires': '2030-06-01T00:00:00.000Z',
      'created_at': '2024-01-01T00:00:00.000Z',
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wizarrServiceProvider.overrideWith(
            (ref) => WizarrService(
              WizarrClient(url: 'https://wizarr.example.com', apiKey: 'k'),
            ),
          ),
          wizarrInvitationsProvider.overrideWith((ref) async => [liveInvite]),
          wizarrUsersProvider.overrideWith((ref) async => [liveUser]),
        ],
        child: const MaterialApp(home: WizarrScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(WizarrInviteTile), findsOneWidget);
    expect(find.text('live-code'), findsOneWidget);

    await tester.tap(find.text('Users'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(WizarrUserTile), findsOneWidget);
    expect(find.text('bob'), findsOneWidget);
  });

  testWidgets('unconfigured service shows placeholder, not a crash', (
    tester,
  ) async {
    // Mirror production: the sync client provider throws when no URL or
    // key is configured, which puts the list providers in AsyncError.
    // (Overriding the FutureProviders to throw instead would linger in
    // AsyncLoading-with-error and never reach the error branch.)
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wizarrClientProvider.overrideWith(
            (ref) => throw Exception('Wizarr not configured'),
          ),
        ],
        child: const MaterialApp(home: WizarrScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Must render the friendly placeholder — a synchronous provider throw
    // escaping the tab build would fail the test with an exception.
    expect(find.byType(NotConfiguredPlaceholder), findsWidgets);
  });

  testWidgets('revoke hidden when id is null', (tester) async {
    final noIdInvite = WizarrInvitation.fromJson({
      'code': 'no-id',
      'url': 'https://example.com/j/no-id',
      'status': 'active',
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wizarrServiceProvider.overrideWith(
            (ref) => WizarrService(
              WizarrClient(url: 'https://wizarr.example.com', apiKey: 'k'),
            ),
          ),
          wizarrInvitationsProvider.overrideWith((ref) async => [noIdInvite]),
          wizarrUsersProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: WizarrScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(WizarrInviteTile), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
  });

  testWidgets('Cancel performs zero DELETEs', (tester) async {
    final adapter = _CountingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://wizarr.example.com'));
    dio.httpClientAdapter = adapter;
    final service = WizarrService(
      WizarrClient(url: 'https://wizarr.example.com', apiKey: 'k', dio: dio),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wizarrServiceProvider.overrideWith((ref) => service),
          wizarrInvitationsProvider.overrideWith((ref) async => [_liveInvite()]),
          wizarrUsersProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: WizarrScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // open confirm dialog
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Cancel'), findsOneWidget);

    // tap Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(adapter.deleteCount, 0);
  });

  testWidgets('confirm revokes and row disappears', (tester) async {
    final adapter = _RevokeFlowAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://wizarr.example.com'));
    dio.httpClientAdapter = adapter;
    final service = WizarrService(
      WizarrClient(url: 'https://wizarr.example.com', apiKey: 'k', dio: dio),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wizarrServiceProvider.overrideWith((ref) => service),
          wizarrInvitationsProvider.overrideWith((ref) async {
            if (adapter.deleted) return <WizarrInvitation>[];
            return [_liveInvite()];
          }),
          wizarrUsersProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: WizarrScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(WizarrInviteTile), findsOneWidget);

    // open confirm dialog
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // confirm revoke
    await tester.tap(find.text('Revoke'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(WizarrInviteTile), findsNothing);
  });

  testWidgets('in-flight revoke blocks dismissal until done', (tester) async {
    final adapter = _HangingDeleteAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://wizarr.example.com'));
    dio.httpClientAdapter = adapter;
    final service = WizarrService(
      WizarrClient(url: 'https://wizarr.example.com', apiKey: 'k', dio: dio),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wizarrServiceProvider.overrideWith((ref) => service),
          wizarrInvitationsProvider.overrideWith((ref) async {
            if (adapter.deleted) return <WizarrInvitation>[];
            return [_liveInvite()];
          }),
          wizarrUsersProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: WizarrScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // open confirm dialog
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // start revoke; the DELETE hangs so the dialog stays in-flight
    await tester.tap(find.text('Revoke'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // barrier tap must not dismiss while submitting
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('Revoke invite'), findsOneWidget);

    // system back must not dismiss while submitting
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('Revoke invite'), findsOneWidget);

    // finish the DELETE: dialog closes, row disappears
    adapter.completeDelete();
    await tester.pumpAndSettle();
    expect(find.textContaining('Revoke invite'), findsNothing);
    expect(find.byType(WizarrInviteTile), findsNothing);
  });
}

class _CountingAdapter implements HttpClientAdapter {
  int deleteCount = 0;
  final List<RequestOptions> requests = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.method == 'DELETE') deleteCount++;
    if (options.method == 'GET') {
      return ResponseBody.fromBytes(
        Uint8List.fromList('{"invitations":[{"id":7,"code":"code-123","url":"https://example.com/j/code-123","status":"active"}]}'.codeUnits),
        200,
        headers: {Headers.contentTypeHeader: ['application/json']},
      );
    }
    return ResponseBody.fromBytes(
      Uint8List.fromList('{"message":"deleted"}'.codeUnits),
      200,
      headers: {Headers.contentTypeHeader: ['application/json']},
    );
  }
}

class _RevokeFlowAdapter implements HttpClientAdapter {
  bool deleted = false;
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'DELETE') {
      deleted = true;
      return ResponseBody.fromBytes(
        Uint8List.fromList('{"message":"deleted"}'.codeUnits),
        200,
        headers: {Headers.contentTypeHeader: ['application/json']},
      );
    }
    // GET
    if (deleted) {
      return ResponseBody.fromBytes(
        Uint8List.fromList('{"invitations":[]}'.codeUnits),
        200,
        headers: {Headers.contentTypeHeader: ['application/json']},
      );
    }
    return ResponseBody.fromBytes(
      Uint8List.fromList('{"invitations":[{"id":7,"code":"code-123","url":"https://example.com/j/code-123","status":"active"}]}'.codeUnits),
      200,
      headers: {Headers.contentTypeHeader: ['application/json']},
    );
  }
}

class _HangingDeleteAdapter implements HttpClientAdapter {
  bool deleted = false;
  Completer<ResponseBody>? _gate;

  void completeDelete() {
    deleted = true;
    _gate?.complete(
      ResponseBody.fromBytes(
        Uint8List.fromList('{"message":"deleted"}'.codeUnits),
        200,
        headers: {Headers.contentTypeHeader: ['application/json']},
      ),
    );
  }

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'DELETE') {
      _gate ??= Completer<ResponseBody>();
      return _gate!.future;
    }
    if (deleted) {
      return ResponseBody.fromBytes(
        Uint8List.fromList('{"invitations":[]}'.codeUnits),
        200,
        headers: {Headers.contentTypeHeader: ['application/json']},
      );
    }
    return ResponseBody.fromBytes(
      Uint8List.fromList('{"invitations":[{"id":7,"code":"code-123","url":"https://example.com/j/code-123","status":"active"}]}'.codeUnits),
      200,
      headers: {Headers.contentTypeHeader: ['application/json']},
    );
  }
}
