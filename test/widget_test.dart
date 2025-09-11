import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ide/main.dart';

void main() {
  testWidgets('App should render without errors', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FlutterIDE());

    // Verify that the app renders without errors
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('App should show explorer screen by default', (WidgetTester tester) async {
    await tester.pumpWidget(const FlutterIDE());
    
    // Verify that the explorer screen is shown by default
    expect(find.text('EXPLORER'), findsOneWidget);
  });
}
