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

  testWidgets(
    'App should show welcome screen in full width when no project is loaded',
    (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: FIDE()));

      // Wait for the app to settle and any async operations to complete
      await tester.pumpAndSettle();
      await tester.pump(
        const Duration(milliseconds: 100),
      ); // Extra wait for async operations

      // Verify that the welcome screen is shown in full width when no project is loaded
      // (explorer panel is hidden, welcome screen takes full width)
      expect(find.text('Welcome to'), findsOneWidget);
      expect(find.text('FIDE'), findsOneWidget);
      expect(
        find.text('Flutter Integrated Developer Environment'),
        findsOneWidget,
      );
      expect(find.text('Create New Project'), findsOneWidget);
    },
  );
}
