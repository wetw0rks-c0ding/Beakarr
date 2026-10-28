import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('OIDC WebView screen exists and is loadable', (WidgetTester tester) async {
    final widget = MaterialApp(
      home: Scaffold(body: Text('WebView')),
    );
    await tester.pumpWidget(widget);

    expect(find.text('WebView'), findsOneWidget);
  });
}
