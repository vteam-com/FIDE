import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/screens/settings_screen.dart';
import 'package:fide/widget_services/app_title_bar.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'fake_app_updater.dart';

/// The update button's tooltip while release 1.1.0 is out.
const String _updateTooltip = 'Update to FIDE 1.1.0 and restart';

void main() {
  late List<String> log;
  late FakeAppUpdater updater;

  setUp(() {
    log = [];
    updater = FakeAppUpdater(log);
  });

  /// Pumps [child] in FIDE 1.0.2, updating with [updater] when
  /// [canUpdate], once its check for a newer release has run.
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    bool canUpdate = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appUpdaterProvider.overrideWithValue(canUpdate ? updater : null),
          appVersionProvider.overrideWith((_) async => '1.0.2'),
          quitAppProvider.overrideWithValue(() async => log.add('quit')),
        ],
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
    await tester.pump();
  }

  /// Taps the update button, past the title bar's double click.
  Future<void> tapUpdate(WidgetTester tester) async {
    await tester.tap(find.byTooltip(_updateTooltip));
    await tester.pump(kDoubleTapTimeout);
  }

  group('the title bar', () {
    const titleBar = AppTitleBar(menus: []);

    testWidgets('has no update button while FIDE is up to date', (
      tester,
    ) async {
      await pump(tester, titleBar);

      expect(log, ['check']);
      expect(find.byTooltip(_updateTooltip), findsNothing);
    });

    testWidgets('updates to the newer release, then quits', (tester) async {
      updater.latest = releaseOf('1.1.0');
      await pump(tester, titleBar);

      await tapUpdate(tester);

      expect(log, ['check', 'stage 1.1.0', 'quit']);
    });

    testWidgets('tells why an update failed', (tester) async {
      updater.latest = releaseOf('1.1.0');
      await pump(tester, titleBar);
      updater.failure = const HttpException('github.com answered 404');

      await tapUpdate(tester);

      expect(
        find.text('Update failed: github.com answered 404'),
        findsOneWidget,
      );
      expect(log, ['check']);
      // Lets the message time out
      await tester.pump(AppDuration.messageError);
      await tester.pumpAndSettle();
    });
  });

  group('the settings', () {
    final settings = SettingsScreen(menus: const [], onClose: () {});

    testWidgets('offer the newer release', (tester) async {
      updater.latest = releaseOf('1.1.0');
      await pump(tester, settings);

      expect(
        find.text('FIDE 1.0.2: version 1.1.0 is available'),
        findsOneWidget,
      );
      expect(find.byTooltip(_updateTooltip), findsOneWidget);
    });

    testWidgets('tell FIDE is up to date, and check again', (tester) async {
      await pump(tester, settings);
      expect(find.text('FIDE 1.0.2 is up to date'), findsOneWidget);

      await tester.tap(find.byTooltip('Check again'));
      await tester.pump();

      expect(log, ['check', 'check']);
    });

    testWidgets('tell why the check failed', (tester) async {
      updater.failure = const SocketException('Failed host lookup');
      await pump(tester, settings);

      expect(
        find.text(
          "FIDE 1.0.2: couldn't check for a newer version: Failed host lookup",
        ),
        findsOneWidget,
      );
    });

    testWidgets('of a build from source neither check nor update', (
      tester,
    ) async {
      await pump(tester, settings, canUpdate: false);

      expect(
        find.text('FIDE 1.0.2 runs from its source code, which Git updates'),
        findsOneWidget,
      );
      expect(find.byTooltip('Check again'), findsNothing);
      expect(log, isEmpty);
    });
  });
}
