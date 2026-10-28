import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seekarr/features/navidrome/domain/models/navidrome_artist.dart';
import 'package:seekarr/features/navidrome/domain/models/navidrome_album.dart';
import 'package:seekarr/features/navidrome/presentation/navidrome_providers.dart';
import 'package:seekarr/features/navidrome/presentation/navidrome_screen.dart';

void main() {
  testWidgets('NavidromeScreen shows artists tab content', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          navidromeArtistsProvider.overrideWith(
            (ref) async => const [
              NavidromeArtist(id: '1', name: 'Artist One', albumCount: 2),
            ],
          ),
          navidromeAlbumsProvider.overrideWith(
            (ref) async => const [
              NavidromeAlbum(id: '10', name: 'Album One'),
            ],
          ),
        ],
        child: const MaterialApp(home: NavidromeScreen()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Navidrome'), findsOneWidget);
    expect(find.text('Artists'), findsOneWidget);
    expect(find.text('Albums'), findsOneWidget);
    expect(find.text('Artist One'), findsOneWidget);
  });
}