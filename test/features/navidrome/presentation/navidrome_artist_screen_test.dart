import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seekarr/features/navidrome/domain/models/navidrome_album.dart';
import 'package:seekarr/features/navidrome/domain/models/navidrome_track.dart';
import 'package:seekarr/core/widgets/not_configured_placeholder.dart';
import 'package:seekarr/features/navidrome/presentation/navidrome_artist_screen.dart';
import 'package:seekarr/features/navidrome/presentation/navidrome_providers.dart';

void main() {
  testWidgets('NavidromeArtistScreen renders albums from a fake', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          navidromeArtistAlbumsProvider.overrideWith(
            (ref, artistId) async => const [
              NavidromeAlbum(id: '10', name: 'Album One', songCount: 2),
            ],
          ),
          navidromeAlbumTracksProvider.overrideWith(
            (ref, albumId) async => const [
              NavidromeTrack(
                id: '20',
                title: 'Track One',
                trackNumber: 1,
                durationSeconds: 180,
              ),
            ],
          ),
        ],
        child: const MaterialApp(
          home: NavidromeArtistScreen(
            artistId: 'a1',
            artistName: 'Artist One',
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Artist One'), findsWidgets);
    expect(find.text('Album One'), findsOneWidget);

    // Expand album to show tracks.
    await tester.tap(find.text('Album One'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Track One'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
  });

  testWidgets('NavidromeArtistScreen shows empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          navidromeArtistAlbumsProvider.overrideWith(
            (ref, artistId) async => const <NavidromeAlbum>[],
          ),
        ],
        child: const MaterialApp(
          home: NavidromeArtistScreen(
            artistId: 'a1',
            artistName: 'Artist One',
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('No albums found'), findsOneWidget);
  });

  testWidgets('NavidromeArtistScreen shows loading spinner', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          navidromeArtistAlbumsProvider.overrideWith(
            (ref, artistId) => Completer<List<NavidromeAlbum>>().future,
          ),
        ],
        child: const MaterialApp(
          home: NavidromeArtistScreen(
            artistId: 'a1',
            artistName: 'Artist One',
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('NavidromeArtistScreen shows error text', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          navidromeArtistAlbumsProvider.overrideWith(
            (ref, artistId) => Future<List<NavidromeAlbum>>.error(
              Exception('boom'),
            ),
          ),
        ],
        child: const MaterialApp(
          home: NavidromeArtistScreen(
            artistId: 'a1',
            artistName: 'Artist One',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Error:'), findsOneWidget);
  });

  testWidgets('NavidromeArtistScreen shows not configured placeholder',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          navidromeArtistAlbumsProvider.overrideWith(
            (ref, artistId) => Future<List<NavidromeAlbum>>.error(
              Exception('Navidrome not configured'),
            ),
          ),
        ],
        child: const MaterialApp(
          home: NavidromeArtistScreen(
            artistId: 'a1',
            artistName: 'Artist One',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(NotConfiguredPlaceholder), findsOneWidget);
  });
}