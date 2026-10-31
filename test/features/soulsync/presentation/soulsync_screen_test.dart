import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seekarr/features/soulsync/domain/models/soulsync_wishlist_item.dart';
import 'package:seekarr/features/soulsync/presentation/soulsync_providers.dart';
import 'package:seekarr/features/soulsync/presentation/soulsync_screen.dart';

void main() {
  testWidgets('SoulSyncScreen shows wishlist tab content', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          soulsyncWishlistProvider.overrideWith(
            (ref) async => const [
              SoulSyncWishlistItem(id: '1', title: 'Wish One'),
            ],
          ),
          soulsyncDownloadsProvider.overrideWith(
            (ref) async => const [],
          ),
        ],
        child: const MaterialApp(home: SoulSyncScreen()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('SoulSync'), findsOneWidget);
    expect(find.text('Wishlist'), findsOneWidget);
    expect(find.text('Downloads'), findsOneWidget);
    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('Wish One'), findsOneWidget);
  });
}
