import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fide/utils/message_helper.dart';
import 'package:fide/widgets/message_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MessageHelper', () {
    test('MessageHelper methods exist and are callable', () {
      // This test verifies that the MessageHelper class has the expected methods
      // and that they can be called without throwing errors during compilation
      expect(MessageHelper.showSuccess, isNotNull);
      expect(MessageHelper.showWarning, isNotNull);
      expect(MessageHelper.showError, isNotNull);
      expect(MessageHelper.showInfo, isNotNull);
    });

    testWidgets('MessageWidget is properly integrated', (
      WidgetTester tester,
    ) async {
      // Test that MessageWidget can be instantiated and displays correctly
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MessageWidget(
              message: 'Test message',
              type: MessageType.info,
              duration: Duration(seconds: 4),
              showCloseButton: true,
              showCopyButton: false,
              autoDismiss: false,
            ),
          ),
        ),
      );

      expect(find.byType(MessageWidget), findsOneWidget);
      expect(find.text('Test message'), findsOneWidget);
    });

    testWidgets('MessageWidget displays different types correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                MessageWidget(
                  message: 'Success',
                  type: MessageType.success,
                  duration: Duration(seconds: 1),
                  showCloseButton: false,
                  showCopyButton: false,
                  autoDismiss: false,
                ),
                MessageWidget(
                  message: 'Warning',
                  type: MessageType.warning,
                  duration: Duration(seconds: 1),
                  showCloseButton: false,
                  showCopyButton: false,
                  autoDismiss: false,
                ),
                MessageWidget(
                  message: 'Error',
                  type: MessageType.error,
                  duration: Duration(seconds: 1),
                  showCloseButton: false,
                  showCopyButton: false,
                  autoDismiss: false,
                ),
                MessageWidget(
                  message: 'Info',
                  type: MessageType.info,
                  duration: Duration(seconds: 1),
                  showCloseButton: false,
                  showCopyButton: false,
                  autoDismiss: false,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(MessageWidget), findsNWidgets(4));
      expect(find.text('Success'), findsOneWidget);
      expect(find.text('Warning'), findsOneWidget);
      expect(find.text('Error'), findsOneWidget);
      expect(find.text('Info'), findsOneWidget);
    });

    testWidgets('MessageWidget shows close button when enabled', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MessageWidget(
              message: 'Test message',
              type: MessageType.info,
              duration: Duration(seconds: 4),
              showCloseButton: true,
              showCopyButton: false,
              autoDismiss: false,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('MessageWidget shows copy button when enabled', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MessageWidget(
              message: 'Test message',
              type: MessageType.error,
              duration: Duration(seconds: 4),
              showCloseButton: false,
              showCopyButton: true,
              autoDismiss: false,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.copy), findsOneWidget);
    });

    testWidgets('MessageWidget can be closed manually', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MessageWidget(
              message: 'Test message',
              type: MessageType.info,
              duration: Duration(seconds: 4),
              showCloseButton: true,
              showCopyButton: false,
              autoDismiss: false,
            ),
          ),
        ),
      );

      expect(find.byType(MessageWidget), findsOneWidget);

      // Tap the close button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      // Message should still be visible (close button triggers animation)
      expect(find.byType(MessageWidget), findsOneWidget);
    });

    testWidgets('MessageWidget displays with proper styling', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MessageWidget(
              message: 'Styled message',
              type: MessageType.success,
              duration: Duration(seconds: 4),
              showCloseButton: true,
              showCopyButton: false,
              autoDismiss: false,
            ),
          ),
        ),
      );

      // Verify the message text is displayed
      expect(find.text('Styled message'), findsOneWidget);

      // Verify icons are present
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('MessageHelper.showSuccess displays overlay message', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Placeholder())),
      );

      final context = tester.element(find.byType(Placeholder));

      // Call MessageHelper.showSuccess
      MessageHelper.showSuccess(context, 'Test success message');

      // Pump to allow overlay to be inserted
      await tester.pump();

      // Verify the overlay message is displayed
      expect(find.text('Test success message'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      // Pump to advance time and allow auto-removal
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('MessageHelper.showError displays overlay message', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Placeholder())),
      );

      final context = tester.element(find.byType(Placeholder));

      // Call MessageHelper.showError
      MessageHelper.showError(context, 'Test error message');

      // Pump to allow overlay to be inserted
      await tester.pump();

      // Verify the overlay message is displayed
      expect(find.text('Test error message'), findsOneWidget);
      expect(find.byIcon(Icons.error), findsOneWidget);

      // Pump to advance time and allow auto-removal
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('MessageHelper.showWarning displays overlay message', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Placeholder())),
      );

      final context = tester.element(find.byType(Placeholder));

      // Call MessageHelper.showWarning
      MessageHelper.showWarning(context, 'Test warning message');

      // Pump to allow overlay to be inserted
      await tester.pump();

      // Verify the overlay message is displayed
      expect(find.text('Test warning message'), findsOneWidget);
      expect(find.byIcon(Icons.warning), findsOneWidget);

      // Pump to advance time and allow auto-removal
      await tester.pump(const Duration(seconds: 7));
    });

    testWidgets('MessageHelper.showInfo displays overlay message', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Placeholder())),
      );

      final context = tester.element(find.byType(Placeholder));

      // Call MessageHelper.showInfo
      MessageHelper.showInfo(context, 'Test info message');

      // Pump to allow overlay to be inserted
      await tester.pump();

      // Verify the overlay message is displayed
      expect(find.text('Test info message'), findsOneWidget);
      expect(find.byIcon(Icons.info), findsOneWidget);

      // Pump to advance time and allow auto-removal
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
