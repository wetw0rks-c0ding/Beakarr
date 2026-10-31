import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seekarr/features/qbittorrent/presentation/qbittorrent_provider.dart';
import 'package:seekarr/features/qbittorrent/presentation/widgets/torrent_selection_bar.dart';

void main() {
  testWidgets('selection bar shows Delete without overflow', (tester) async {
    // Narrow phone-width surface: the old fixed Row clipped the Delete
    // action here; the scrollable bar must lay out cleanly.
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          selectedTorrentHashesProvider.overrideWith((ref) => {'aaa'}),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: TorrentSelectionBar(onConfirmDelete: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 selected'), findsOneWidget);
    expect(find.byTooltip('Delete'), findsOneWidget);
    // Fails with a RenderFlex overflow if the bar clips its actions.
    expect(tester.takeException(), isNull);
  });
}
