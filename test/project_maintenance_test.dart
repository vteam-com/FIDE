import 'dart:convert';
import 'dart:io';

import 'package:fide/models/dependency_version.dart';
import 'package:fide/models/project_metrics.dart';
import 'package:fide/models/pub_outdated.dart';
import 'package:fide/services/process_runner.dart';
import 'package:fide/services/health_checker.dart';
import 'package:fide/services/project_analyzer.dart';
import 'package:fide/services/project_config_reader.dart';
import 'package:fide/services/project_maintenance_service.dart';
import 'package:fide/services/pubspec_upgrader.dart';
import 'package:flutter_test/flutter_test.dart';

const String _pubspec = '''
name: demo
version: 1.2.3
description: Demo app
dependencies:
  flutter:
    sdk: flutter
  http: ^1.0.0
dev_dependencies:
  lints: ^2.0.0
''';

// Answers `run` calls from a script keyed by the joined command line
class FakeRunRunner extends ProcessRunner {
  final Map<String, ProcessResult> results;
  final List<String> commands = [];

  FakeRunRunner(this.results);

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool runInShell = false,
    Map<String, String> environment = const {},
  }) async {
    final command = [executable, ...arguments].join(' ');
    commands.add(command);
    return results[command] ?? ProcessResult(0, 0, '', '');
  }
}

void main() {
  late Directory project;

  setUp(() {
    project = Directory.systemTemp.createTempSync('fide_maint_');
    File('${project.path}/pubspec.yaml').writeAsStringSync(_pubspec);
    Directory('${project.path}/lib').createSync();
    File('${project.path}/lib/main.dart').writeAsStringSync('void main() {}');
  });

  tearDown(() => project.deleteSync(recursive: true));

  group('ProjectAnalyzer.analyze', () {
    test('reads pubspec info and dependencies', () async {
      final metrics = await const ProjectAnalyzer(ProjectConfigReader())
          .analyze(project.path);

      expect(metrics.name, 'demo');
      expect(metrics.version, '1.2.3');
      expect(metrics.dependencies, {
        'flutter': DependencyVersion.sdk,
        'http': const DependencyVersion.hosted('^1.0.0'),
      });
      expect(metrics.devDependencies, {
        'lints': const DependencyVersion.hosted('^2.0.0'),
      });
    });

    test('counts files and tracked directories in one walk', () async {
      final metrics = await const ProjectAnalyzer(ProjectConfigReader())
          .analyze(project.path);

      expect(metrics.fileStats, {'yaml': 1, 'dart': 1});
      expect(metrics.totalFiles, 2);
      expect(metrics.directoryStructure, {'lib': 1});
    });

    test('HealthChecker reports a missing pubspec.lock', () async {
      final health = await const HealthChecker().check(project.path);

      expect(health.hasPubspecLock, false);
      expect(health.largeFiles, isEmpty);
      expect(health.issues(project.path).single.label, 'Missing pubspec.lock');
    });
  });

  test('outdatedReport reads pub\'s JSON once, as text and by name', () async {
    final runner = FakeRunRunner({
      'flutter pub outdated --json': ProcessResult(
        0,
        0,
        jsonEncode({
          'packages': [
            {
              'package': 'http',
              'kind': 'direct',
              'current': {'version': '1.0.0'},
              'upgradable': {'version': '1.1.0'},
              'resolvable': {'version': '1.1.0'},
              'latest': {'version': '2.0.0'},
            },
          ],
        }),
        '',
      ),
    });

    final report = await ProjectMaintenanceService(runner)
        .outdatedReport(project.path);

    expect(report.output, 'http 1.0.0 → 1.1.0 (latest 2.0.0)');
    final http = report.packages['http']!;
    expect((http.upgradable, http.latest), ('1.1.0', '2.0.0'));
    expect(PubOutdatedPackage.fromJson(http.toJson())!.toJson(), http.toJson());
    expect(
      ProjectMaintenanceService(
        FakeRunRunner({
          'flutter pub outdated --json': ProcessResult(0, 1, '', 'offline'),
        }),
      ).outdatedReport(project.path),
      throwsA(
        isA<MaintenanceException>().having(
          (e) => '$e',
          'message',
          contains('offline'),
        ),
      ),
    );
  });

  test('ProjectMetrics survives the JSON cache round trip', () async {
    final metrics = await const ProjectAnalyzer(ProjectConfigReader())
        .analyze(project.path);

    final restored = ProjectMetrics.fromJson(
      jsonDecode(jsonEncode(metrics.toJson())) as Map<String, dynamic>,
    );

    expect(restored.toJson(), metrics.toJson());
    expect(restored.dependencies, metrics.dependencies);
  });

  test('VersionConflictException summarizes pub and names the package', () {
    const error = '''
Resolving dependencies...
Because demo depends on both http ^0.13.0 and web ^1.0.0, version solving failed.

Because demo depends on both http ^0.13.0 and foo any, version solving failed.
* Consider downgrading your constraint on http
''';

    final conflict = VersionConflictException.fromPubError(error);

    expect(conflict.package, 'http');
    expect(conflict.summary, startsWith('Because demo depends on both http'));
    expect(VersionConflictException.isConflict(error), isTrue);
    expect(
      VersionConflictException.fromPubError('boom').summary,
      'Dependency conflict detected',
    );
    expect('${const MaintenanceException('oops')}', 'oops');
  });

  group('PubOutdated.parse', () {
    test('reads the packages and which can be upgraded', () {
      final outdated = PubOutdated.parse(
        jsonEncode({
          'packages': [
            {
              'package': 'http',
              'kind': 'direct',
              'current': {'version': '1.0.0'},
              'resolvable': {'version': '1.1.0'},
            },
            {
              'package': 'lints',
              'kind': 'dev',
              'current': {'version': '2.0.0'},
              'resolvable': {'version': '2.0.0'},
            },
            {
              'package': 'meta',
              'kind': 'transitive',
              'current': {'version': '1.0.0'},
              'resolvable': {'version': '1.9.0'},
            },
            {'kind': 'direct'},
          ],
        }),
      );

      expect(outdated.packages.map((p) => p.name), ['http', 'lints', 'meta']);
      expect(outdated.upgradable.map((p) => (p.name, p.resolvable)), [
        ('http', '1.1.0'),
      ]);
      expect(outdated.packages[1].pubspecSection, 'dev_dependencies');
      expect(outdated.packages[2].isDeclared, isFalse);
    });

    test('rejects JSON of another shape', () {
      expect(() => PubOutdated.parse('[]'), throwsFormatException);
      expect(() => PubOutdated.parse('{"packages": 1}'), throwsFormatException);
    });
  });

  test('PubspecUpgrader raises declared constraints only', () {
    final upgrade = PubspecUpgrader.upgrade(
      _pubspec,
      const PubOutdated([
        PubOutdatedPackage(
          name: 'http',
          kind: 'direct',
          current: '1.0.0',
          resolvable: '1.1.0',
        ),
        PubOutdatedPackage(
          name: 'missing',
          kind: 'dev',
          current: '1.0.0',
          resolvable: '2.0.0',
        ),
      ]),
    );

    expect(upgrade.upgraded.map((p) => p.name), ['http']);
    expect(upgrade.yaml, contains('http: 1.1.0'));
    expect(upgrade.yaml, contains('lints: ^2.0.0'));
  });

  group('ProjectMaintenanceService.upgradeToResolvable', () {
    test('raises outdated constraints and runs pub get', () async {
      final runner = FakeRunRunner({
        'flutter pub outdated --json': ProcessResult(
          0,
          0,
          jsonEncode({
            'packages': [
              {
                'package': 'http',
                'kind': 'direct',
                'current': {'version': '1.0.0'},
                'resolvable': {'version': '1.1.0'},
              },
              {
                'package': 'meta',
                'kind': 'transitive',
                'current': {'version': '1.0.0'},
                'resolvable': {'version': '1.9.0'},
              },
            ],
          }),
          '',
        ),
      });

      final updated = await ProjectMaintenanceService(runner)
          .upgradeToResolvable(project.path);

      expect(updated.map((p) => (p.name, p.current, p.resolvable)), [
        ('http', '1.0.0', '1.1.0'),
      ]);
      expect(
        File('${project.path}/pubspec.yaml').readAsStringSync(),
        contains('http: 1.1.0'),
      );
      expect(runner.commands.last, 'flutter pub get');
    });

    test('surfaces pub version-solving errors to the caller', () async {
      final runner = FakeRunRunner({
        'flutter pub outdated --json': ProcessResult(
          0,
          0,
          jsonEncode({'packages': []}),
          '',
        ),
        'flutter pub get': ProcessResult(0, 1, '', 'version solving failed.'),
      });

      expect(
        ProjectMaintenanceService(runner).upgradeToResolvable(project.path),
        throwsA(isA<VersionConflictException>()),
      );
    });
  });
}
