import 'package:fide/models/action_outcome.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/message_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MessageHelper', () {
    test('MessageHelper methods exist and are callable', () {
      // This test verifies that the MessageHelper class has the expected methods
      // and that they can be called without throwing errors during compilation
      expect(MessageBox.showSuccess, isNotNull);
      expect(MessageBox.showWarning, isNotNull);
      expect(MessageBox.showError, isNotNull);
      expect(MessageBox.showInfo, isNotNull);
    });

    testWidgets('MessageWidget is properly integrated', (
      WidgetTester tester,
    ) async {
      // Test that MessageWidget can be instantiated and displays correctly
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MessageWidget(message: 'Test message', type: StatusTone.info),
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
                MessageWidget(message: 'Success', type: StatusTone.success),
                MessageWidget(message: 'Warning', type: StatusTone.warning),
                MessageWidget(message: 'Error', type: StatusTone.error),
                MessageWidget(message: 'Info', type: StatusTone.info),
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

    testWidgets('MessageWidget always shows a close button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MessageWidget(message: 'Test message', type: StatusTone.info),
          ),
        ),
      );

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('MessageWidget offers to copy error messages', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MessageWidget(
              message: 'Test message',
              type: StatusTone.error,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.copy), findsOneWidget);
    });

    testWidgets('MessageWidget does not offer to copy info messages', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MessageWidget(message: 'Test message', type: StatusTone.info),
          ),
        ),
      );

      expect(find.byIcon(Icons.copy), findsNothing);
    });

    testWidgets('MessageWidget reports closing once', (
      WidgetTester tester,
    ) async {
      var closed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageWidget(
              message: 'Test message',
              onClose: () => closed++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.tap(find.byIcon(Icons.close), warnIfMissed: false);
      await tester.pump(StatusTone.info.messageDuration);
      await tester.pumpAndSettle();

      expect(closed, 1);
    });

    testWidgets('MessageWidget can be closed manually', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MessageWidget(message: 'Test message', type: StatusTone.info),
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
              type: StatusTone.success,
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
      MessageBox.showSuccess(context, 'Test success message');

      // Pump to allow overlay to be inserted
      await tester.pump();

      // Verify the overlay message is displayed
      expect(find.text('Test success message'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      // Pump to advance time and allow auto-removal
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('MessageBox.show displays a message in the given tone', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Placeholder())),
      );
      final context = tester.element(find.byType(Placeholder));

      MessageBox.show(context, 'Shown in a tone', StatusTone.warning);
      await tester.pump();

      expect(find.text('Shown in a tone'), findsOneWidget);
      expect(
        tester.widget<MessageWidget>(find.byType(MessageWidget)).type,
        StatusTone.warning,
      );
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('MessageBox.showOutcome shows the outcome in its tone', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Placeholder())),
      );
      final context = tester.element(find.byType(Placeholder));

      MessageBox.showOutcome(context, const ActionOutcome.success('Done'));
      await tester.pump();

      expect(find.text('Done'), findsOneWidget);
      expect(
        tester.widget<MessageWidget>(find.byType(MessageWidget)).type,
        StatusTone.success,
      );
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
      MessageBox.showError(context, 'Test error message');

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
      MessageBox.showWarning(context, 'Test warning message');

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
      MessageBox.showInfo(context, 'Test info message');

      // Pump to allow overlay to be inserted
      await tester.pump();

      // Verify the overlay message is displayed
      expect(find.text('Test info message'), findsOneWidget);
      expect(find.byIcon(Icons.info), findsOneWidget);

      // Pump to advance time and allow auto-removal
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('closing an overlay message removes it at once', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Placeholder())),
      );
      final context = tester.element(find.byType(Placeholder));

      MessageBox.showError(context, 'Test error message');
      await tester.pumpAndSettle();
      expect(find.byType(MessageWidget), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Gone well before the error's display duration, so nothing invisible
      // is left over the app to catch clicks
      expect(find.byType(MessageWidget), findsNothing);
    });

    testWidgets('an overlay message removes itself after its duration', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Placeholder())),
      );
      final context = tester.element(find.byType(Placeholder));

      MessageBox.showInfo(context, 'Test info message');
      await tester.pumpAndSettle();
      await tester.pump(StatusTone.info.messageDuration);
      await tester.pumpAndSettle();

      expect(find.byType(MessageWidget), findsNothing);
    });
  });
}
