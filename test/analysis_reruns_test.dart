import 'dart:async';
import 'dart:io';

import 'package:fide/constants/core_constants.dart';
import 'package:fide/models/app_icon_review.dart';
import 'package:fide/models/dry_review.dart';
import 'package:fide/models/project_overview.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/architecture_orientation_notifier.dart';
import 'package:fide/providers/architecture_providers.dart';
import 'package:fide/providers/dry_review_provider.dart';
import 'package:fide/providers/app_icon_review_provider.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/app_icon_inspector.dart';
import 'package:fide/services/dry_analyzer.dart';
import 'package:fide/services/flutter_sdk.dart';
import 'package:fide/services/process_runner.dart';
import 'package:fide/services/project_overview_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_file_content_reader.dart';

/// A DRY review counting its runs.
class _CountingDryAnalyzer implements DryAnalyzer {
  int runs = 0;

  @override
  Future<DryReview> review(String projectPath, String sdkPath) async {
    runs++;
    return const DryReview(findings: [], widgetCount: 0, fileCount: 0);
  }
}

/// A Flutter SDK counting its lookups of the Dart SDK.
class _CountingFlutterSdk extends FlutterSdk {
  _CountingFlutterSdk() : super(const ProcessRunner());

  int lookups = 0;

  @override
  Future<String?> dartSdkPath() async {
    lookups++;
    return '/sdk';
  }
}

/// An app icon check counting its runs.
class _CountingIconInspector implements AppIconInspector {
  int runs = 0;

  @override
  Future<AppIconReview> review(String projectPath, {String? masterPath}) async {
    runs++;
    return const AppIconReview(platforms: [], issues: []);
  }
}

/// An overview service handing out [overview], each load held until the
/// test releases it, recording how many loads ran at once.
class _HeldOverviewService implements ProjectOverviewService {
  _HeldOverviewService(this.overview);

  final ProjectOverview overview;
  final List<Completer<void>> holds = [];
  int running = 0;
  int mostRunning = 0;

  @override
  Future<ProjectOverview> load(String projectPath) async {
    final hold = Completer<void>();
    holds.add(hold);
    if (++running > mostRunning) mostRunning = running;
    await hold.future;
    running--;
    return overview;
  }
}

void main() {
  late Directory project;

  /// Longer than a pause between saves.
  final pause = AppDuration.saveBurstPause * 2;

  /// How many saves come in a burst.
  const burst = 5;

  setUp(() {
    project = Directory.systemTemp.createTempSync('fide_reruns_');
    File('${project.path}/pubspec.yaml').writeAsStringSync('name: sample\n');
    File('${project.path}/lib/main.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('/// Main.\nvoid main() {}\n');
  });
  tearDown(() => project.deleteSync(recursive: true));

  /// A container with [project] open.
  ProviderContainer open(List<Override> overrides) {
    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);
    container.read(currentProjectPathProvider.notifier).state = project.path;
    return container;
  }

  /// Saves [burst] files in a row, counted by [revision], then lets saves
  /// pause.
  Future<void> saveBurst(
    ProviderContainer container, {
    StateProvider<int>? revision,
  }) async {
    for (var i = 0; i < burst; i++) {
      container.read((revision ?? savedFilesRevisionProvider).notifier).state++;
      await Future<void>.delayed(Duration.zero);
    }
    await Future<void>.delayed(pause);
  }

  test(
    'a burst of saves runs one DRY review, the SDK looked up once',
    () async {
      final analyzer = _CountingDryAnalyzer();
      final sdk = _CountingFlutterSdk();
      final container = open([
        dryAnalyzerProvider.overrideWithValue(analyzer),
        flutterSdkProvider.overrideWithValue(sdk),
      ]);
      container.listen(dryReviewProvider, (_, _) {});
      await container.read(dryReviewProvider.future);
      expect(analyzer.runs, 1);

      await saveBurst(container);
      await saveBurst(container);

      expect(analyzer.runs, 3);
      expect(sdk.lookups, 1);
    },
  );

  test('a burst of saves checks the app icons once', () async {
    final inspector = _CountingIconInspector();
    final container = open([
      appIconInspectorProvider.overrideWithValue(inspector),
      appIconMasterProvider.overrideWith((_) => null),
    ]);
    container.listen(appIconReviewProvider, (_, _) {});
    await container.read(appIconReviewProvider.future);

    await saveBurst(container, revision: savedAssetsRevisionProvider);

    expect(inspector.runs, 2);
  });

  test('saving only Dart files leaves the app icons unchecked', () async {
    final inspector = _CountingIconInspector();
    final reader = FakeFileContentReader();
    final container = open([
      appIconInspectorProvider.overrideWithValue(inspector),
      appIconMasterProvider.overrideWith((_) => null),
      fileContentReaderProvider.overrideWithValue(reader),
    ]);
    container.listen(appIconReviewProvider, (_, _) {});
    await container.read(appIconReviewProvider.future);
    final documents = container.read(openDocumentsProvider.notifier);

    for (var i = 0; i < burst; i++) {
      await documents.save('${project.path}/lib/main.dart', 'void main() {}');
    }
    await Future<void>.delayed(pause);
    expect(inspector.runs, 1);

    await documents.save('${project.path}/pubspec.yaml', 'name: sample\n');
    await Future<void>.delayed(pause);
    expect(inspector.runs, 2);
  });

  group('with the overview analyzed', () {
    late ProjectOverview analyzed;

    setUp(() async {
      analyzed = await ProviderContainer()
          .read(projectOverviewServiceProvider)
          .load(project.path);
    });

    test('runs one overview analysis at a time, the latest landing', () async {
      final service = _HeldOverviewService(analyzed);
      final container = open([
        projectOverviewServiceProvider.overrideWithValue(service),
      ]);
      container.listen(projectOverviewProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      expect(service.holds, hasLength(1));

      // Saves while the first analysis runs: the next one waits for it
      await saveBurst(container);
      expect(service.holds, hasLength(1));
      service.holds.first.complete();
      await Future<void>.delayed(Duration.zero);
      expect(service.holds, hasLength(2));
      service.holds.last.complete();

      expect(await container.read(projectOverviewProvider.future), analyzed);
      expect(service.mostRunning, 1);
    });

    test('the quick fixes reuse its analysis until a file changes', () async {
      final container = open([
        projectOverviewServiceProvider.overrideWithValue(
          _HeldOverviewService(analyzed),
        ),
      ]);
      container.listen(projectOverviewProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      final service = container.read(
        projectOverviewServiceProvider,
      ) as _HeldOverviewService;
      service.holds.single.complete();
      final latest = container.read(savedCodeMetricsProvider);

      expect(await latest(project.path), same(analyzed.code));
      expect(await latest('/elsewhere'), isNull);

      // Changed on disk, unknown to the editor
      File('${project.path}/lib/main.dart').writeAsStringSync('void x() {}');
      expect(await latest(project.path), isNull);
    });

    test('changing the orientation lays out the same graph again', () async {
      SharedPreferences.setMockInitialValues({});
      final container = open([
        projectOverviewProvider.overrideWith((_) => analyzed),
      ]);
      container.listen(architectureLayoutProvider, (_, _) {});
      final graph = await container.read(architectureGraphProvider.future);
      final layout = await container.read(architectureLayoutProvider.future);

      await container.read(architectureOrientationProvider.notifier).toggle();

      final turned = await container.read(architectureLayoutProvider.future);
      expect(turned, isNot(same(layout)));
      expect(turned!.graph, same(graph));
      expect(
        await container.read(architectureGraphProvider.future),
        same(graph),
      );
    });
  });
}
