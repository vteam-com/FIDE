import 'dart:io';

import 'package:fide/providers/app_update_notifier.dart';
import 'package:fide/providers/open_documents_notifier.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_app_updater.dart';

/// Open documents logging their saves to [log].
class _LoggingDocuments extends OpenDocumentsNotifier {
  _LoggingDocuments(this.log);

  final List<String> log;

  @override
  Future<void> saveAll() async => log.add('save');
}

void main() {
  late List<String> log;
  late FakeAppUpdater updater;

  setUp(() {
    log = [];
    updater = FakeAppUpdater(log);
  });

  /// A container running version [running], updating with [updater].
  ProviderContainer updating({String running = '1.0.2'}) {
    final container = ProviderContainer(
      overrides: [
        appUpdaterProvider.overrideWithValue(updater),
        appVersionProvider.overrideWith((_) async => running),
        openDocumentsProvider.overrideWith((_) => _LoggingDocuments(log)),
        quitAppProvider.overrideWithValue(() async => log.add('quit')),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('a newer release is the update', () async {
    updater.latest = releaseOf('1.1.0');

    expect(await updating().read(appUpdateProvider.future), updater.latest);
  });

  test('no update while the latest release is no newer', () async {
    for (final latest in ['1.0.2', '1.0.1']) {
      updater.latest = releaseOf(latest);

      expect(
        await updating(running: '1.0.2').read(appUpdateProvider.future),
        isNull,
        reason: latest,
      );
    }
  });

  test('a build that cannot update itself never checks', () async {
    final container = ProviderContainer(
      overrides: [
        appUpdaterProvider.overrideWithValue(null),
        appVersionProvider.overrideWith((_) => throw StateError('read')),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(appUpdateProvider.future), isNull);
  });

  test('check asks GitHub again', () async {
    final container = updating();
    await container.read(appUpdateProvider.future);
    updater.latest = releaseOf('1.1.0');

    container.read(appUpdateProvider.notifier).check();

    expect(await container.read(appUpdateProvider.future), updater.latest);
    expect(log, ['check', 'check']);
  });

  test('install stages the release, saves, then quits FIDE', () async {
    updater.latest = releaseOf('1.1.0');
    final container = updating();
    await container.read(appUpdateProvider.future);
    final installing = <bool>[];
    container.listen(
      appUpdateInstallingProvider,
      (_, running) => installing.add(running),
    );

    await container.read(appUpdateProvider.notifier).install();

    expect(log, ['check', 'stage 1.1.0', 'save', 'quit']);
    expect(installing, [true, false]);
  });

  test('a failed install keeps FIDE running', () async {
    updater.latest = releaseOf('1.1.0');
    final container = updating();
    await container.read(appUpdateProvider.future);
    updater.failure = const HttpException('github.com answered 404');

    await expectLater(
      container.read(appUpdateProvider.notifier).install(),
      throwsA(isA<HttpException>()),
    );

    expect(log, ['check']);
    expect(container.read(appUpdateInstallingProvider), isFalse);
  });

  test('install does nothing while FIDE is up to date', () async {
    final container = updating();
    await container.read(appUpdateProvider.future);

    await container.read(appUpdateProvider.notifier).install();

    expect(log, ['check']);
  });
}
