import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

// This looks up one level and finds your actual app code
import '../lib/main.dart';

void main() {
  testWidgets('App load test', (WidgetTester tester) async {
    // We provide 'false' and 'null' so the app starts at the Login Screen
    // and the red error under MyApp disappears.
    await tester.pumpWidget(const MyApp(hasToken: false, role: null));

    // We verify that the app starts up without crashing.
    // The old counter code is removed because it doesn't match your app anymore.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
