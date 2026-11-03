import 'package:fide/models/outdated_package.dart';
import 'package:fide/models/project_info_state.dart';
import 'package:fide/models/project_metrics.dart';
import 'package:fide/models/pub_outdated.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/project_info_controller.dart';
import 'package:fide/services/file_entry_service.dart';
import 'package:fide/services/process_runner.dart';
import 'package:fide/services/project_analyzer.dart';
import 'package:fide/services/project_config_reader.dart';
import 'package:fide/services/project_maintenance_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The project every test opens.
const String _project = '/demo';

/// Measures nothing: answers [analyze] with [metrics], or throws
/// [failure].
class FakeAnalyzer extends ProjectAnalyzer {
  const FakeAnalyzer() : super(const ProjectConfigReader());

  static ProjectMetrics metrics = const ProjectMetrics(name: 'demo');
  static Object? failure;
  static int analyses = 0;

  @override
  Future<ProjectMetrics> analyze(String projectPath) async {
    analyses++;
    if (failure case final error?) throw error;
    return metrics;
  }
}

/// Runs no command: records the chores asked for and answers them from
/// its fields.
class FakeMaintenance extends ProjectMaintenanceService {
  const FakeMaintenance() : super(const ProcessRunner());

  static final List<String> chores = [];
  static Object? failure;
  static List<PubOutdatedPackage> upgraded = const [];

  @override
  Future<void> fullCleanup(String projectPath) async {
    chores.add('cleanup');
    if (failure case final error?) throw error;
  }

  @override
  Future<({String output, Map<String, OutdatedPackage> packages})>
  outdatedReport(String projectPath) async {
    chores.add('outdated');
    if (failure case final error?) throw error;
    return (
      output: 'http 1.0.0 -> 1.1.0',
      packages: {
        'http': const OutdatedPackage(
          current: '1.0.0',
          upgradable: '1.1.0',
          resolvable: '1.1.0',
          latest: '1.1.0',
        ),
      },
    );
  }

  @override
  Future<List<PubOutdatedPackage>> upgradeToResolvable(
    String projectPath,
  ) async {
    chores.add('upgrade');
    if (failure case final error?) throw error;
    return upgraded;
  }
}

/// Knows only the files in [existing].
class FakeEntries extends FileEntryService {
  const FakeEntries();

  static Set<String> existing = {};

  @override
  bool exists(String entryPath) => existing.contains(entryPath);
}

void main() {
  late ProjectMetricsNotifier metrics;
  late ProjectInfoController controller;

  /// A controller for [projectPath], sharing the fakes' static state.
  ProjectInfoController build(String? projectPath) => ProjectInfoController(
    projectPath,
    analyzer: const FakeAnalyzer(),
    maintenance: const FakeMaintenance(),
    entries: const FakeEntries(),
    metrics: metrics,
    currentMetrics: () => metrics.state,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FakeAnalyzer.metrics = const ProjectMetrics(name: 'demo');
    FakeAnalyzer.failure = null;
    FakeAnalyzer.analyses = 0;
    FakeMaintenance.chores.clear();
    FakeMaintenance.failure = null;
    FakeMaintenance.upgraded = const [];
    FakeEntries.existing = {'$_project/pubspec.yaml'};
    metrics = ProjectMetricsNotifier(SharedPreferences.getInstance(), null);
    controller = build(_project);
  });

  tearDown(() {
    controller.dispose();
    metrics.dispose();
  });

  test('analyzing shows the metrics measured and says nothing', () async {
    final states = <ProjectInfoState>[];
    controller.addListener(states.add, fireImmediately: false);

    final outcome = await controller.analyze();

    expect(outcome, isNull);
    expect(metrics.state.name, 'demo');
    expect(states.map((state) => state.isAnalyzing), [true, false]);
  });

  test('a failed analysis is reported and ends the busy state', () async {
    FakeAnalyzer.failure = StateError('no pubspec');

    final outcome = await controller.analyze();

    expect(outcome?.tone, StatusTone.error);
    expect(outcome?.message, startsWith('Failed to analyze project'));
    expect(controller.state.isAnalyzing, isFalse);
  });

  test('without a project, actions do nothing', () async {
    final idle = build(null);
    addTearDown(idle.dispose);

    expect(await idle.analyze(), isNull);
    expect(await idle.checkOutdated(), isNull);
    expect(idle.pubspecPath, isNull);
    expect(FakeAnalyzer.analyses, 0);
  });

  test('the pubspec is offered only when it exists', () {
    expect(controller.pubspecPath, '$_project/pubspec.yaml');
    FakeEntries.existing = {};
    expect(controller.pubspecPath, isNull);
  });

  test('cleaning up measures the project again', () async {
    final outcome = await controller.fullCleanup();

    expect(outcome?.succeeded, isTrue);
    expect(FakeMaintenance.chores, ['cleanup']);
    expect(FakeAnalyzer.analyses, 1);
  });

  test('a failed cleanup is reported', () async {
    FakeMaintenance.failure = const MaintenanceException('busy');

    final outcome = await controller.fullCleanup();

    expect(outcome?.tone, StatusTone.error);
    expect(outcome?.message, startsWith('Cleanup failed'));
  });

  test('checking outdated keeps the output and flags the packages', () async {
    final outcome = await controller.checkOutdated();

    expect(outcome?.succeeded, isTrue);
    expect(controller.state.outdatedOutput, 'http 1.0.0 -> 1.1.0');
    expect(metrics.state.outdated.keys, ['http']);
    expect(controller.state.isCheckingOutdated, isFalse);
  });

  test('an upgrade says whether anything changed', () async {
    expect((await controller.upgradePackages())?.tone, StatusTone.info);

    FakeMaintenance.upgraded = const [
      PubOutdatedPackage(name: 'http', kind: 'direct'),
    ];
    expect((await controller.upgradePackages())?.tone, StatusTone.success);
    expect(FakeAnalyzer.analyses, 2);
  });

  test('a conflict is kept with the package pub blames', () async {
    FakeMaintenance.failure = const VersionConflictException(
      'http 2.0.0 conflicts',
      'http',
    );

    final outcome = await controller.upgradePackages();

    expect(outcome?.tone, StatusTone.error);
    expect(controller.state.conflictSummary, 'http 2.0.0 conflicts');
    expect(controller.state.problematicPackages, {'http'});
    expect(controller.state.isUpgrading, isFalse);

    // The next upgrade starts from a clean slate
    FakeMaintenance.failure = null;
    await controller.upgradePackages();
    expect(controller.state.conflictSummary, isNull);
    expect(controller.state.problematicPackages, isEmpty);
  });
}
