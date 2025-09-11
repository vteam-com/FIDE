import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fide/main.dart';

void main() {
  testWidgets('App should render without errors', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: FIDE()));

    // Verify that the app renders without errors
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('App should show explorer screen by default', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: FIDE()));

    // Wait for the app to settle
    await tester.pumpAndSettle();

    // Verify that the explorer screen is shown by default
    // The screen shows "No project opened" text when no project is loaded
    expect(find.text('No project opened'), findsOneWidget);
  });
}
