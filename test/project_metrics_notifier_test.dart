import 'dart:async';

import 'package:fide/models/project_metrics.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Completer<SharedPreferences> prefs;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    prefs = Completer<SharedPreferences>();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWith((_) => prefs.future)],
    );
  });

  tearDown(() => container.dispose());

  test('shows metrics while preferences load, then caches them', () async {
    container.read(currentProjectPathProvider.notifier).state = '/a';
    const metrics = ProjectMetrics(name: 'a');

    final update = container
        .read(projectMetricsProvider.notifier)
        .updateMetrics('/a', metrics);

    expect(container.read(projectMetricsProvider), same(metrics));
    prefs.complete(await SharedPreferences.getInstance());
    await update;
    expect(container.read(projectMetricsProvider), same(metrics));
  });

  test('loads the cached metrics of the project opened', () async {
    prefs.complete(await SharedPreferences.getInstance());
    container.read(currentProjectPathProvider.notifier).state = '/a';
    await container
        .read(projectMetricsProvider.notifier)
        .updateMetrics('/a', const ProjectMetrics(name: 'a'));

    container.read(currentProjectPathProvider.notifier).state = '/b';
    expect(container.read(projectMetricsProvider).name, isNull);

    container.read(currentProjectPathProvider.notifier).state = '/a';
    container.read(projectMetricsProvider);
    await pumpEventQueue();
    expect(container.read(projectMetricsProvider).name, 'a');
  });
}
