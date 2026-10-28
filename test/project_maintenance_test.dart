import 'dart:convert';
import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/providers/process_runner.dart';
import 'package:fide/providers/project_analyzer.dart';
import 'package:fide/providers/project_maintenance_service.dart';
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
      final metrics = await const ProjectAnalyzer().analyze(project.path);

      expect(metrics['name'], 'demo');
      expect(metrics['version'], '1.2.3');
      expect(metrics['dependencies'], {
        'flutter': 'Flutter SDK',
        'http': '^1.0.0',
      });
      expect(metrics['devDependencies'], {'lints': '^2.0.0'});
    });

    test('counts files and tracked directories in one walk', () async {
      final metrics = await const ProjectAnalyzer().analyze(project.path);

      expect(metrics['fileStats'], {'yaml': 1, 'dart': 1});
      expect(metrics['totalFiles'], 2);
      expect(metrics['directoryStructure'], {'lib': 1});
    });

    test('deducts for a missing pubspec.lock', () async {
      final metrics = await const ProjectAnalyzer().analyze(project.path);

      expect(metrics['healthIndicators']['hasPubspecLock'], false);
      expect(
        metrics['qualityScore'],
        AppMetric.maxScore - AppMetric.missingLockDeduction,
      );
    });
  });

  test('parseOutdated reads package rows and skips headers', () {
    final parsed = ProjectMaintenanceService.parseOutdated('''
Package  Current  Upgradable  Resolvable  Latest
http     1.0.0    1.1.0       1.1.0       2.0.0
''');

    expect(parsed, {
      'http': {
        'current': '1.0.0',
        'upgradable': '1.1.0',
        'resolvable': '1.1.0',
        'latest': '2.0.0',
      },
    });
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

      expect(updated, ['http: 1.0.0 → 1.1.0']);
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
        throwsA(contains('version solving failed')),
      );
    });
  });
}
