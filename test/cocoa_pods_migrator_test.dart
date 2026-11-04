import 'dart:io';

import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/models/cocoa_pods_migration.dart';
import 'package:fide/models/flutter_platform.dart';
import 'package:fide/models/pubspec.dart';
import 'package:fide/models/quick_fix.dart';
import 'package:fide/services/cocoa_pods_migrator.dart';
import 'package:fide/services/process_runner.dart';
import 'package:fide/services/project_maintenance_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const String _pubspec = '''
name: app
dependencies:
  flutter:
    sdk: flutter
  firebase_auth: ^4.0.0
  legacy_plugin: ^1.0.0
flutter:
  config:
    enable-swift-package-manager: false
''';

const String _podfile = '''
platform :ios, '13.0'
target 'Runner' do
  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
  # pod 'Commented'
  pod 'GoogleMaps', '~> 8.0'
end
''';

const String _debugXcconfig = '''
#include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.debug.xcconfig"
#include "Generated.xcconfig"
''';

// Records each `pod` command and answers with [exitCode]
class _FakeRunner extends ProcessRunner {
  final int exitCode;
  final List<String> commands = [];

  _FakeRunner([this.exitCode = 0]);

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool runInShell = false,
  }) async {
    commands.add(
      '${p.basename(workingDirectory!)}: $executable ${arguments.join(' ')}',
    );
    return ProcessResult(0, exitCode, '', 'pod failed');
  }
}

void main() {
  late Directory project;

  /// Writes [content] at [relative] in the project.
  void write(String relative, String content) =>
      File(p.join(project.path, relative))
        ..createSync(recursive: true)
        ..writeAsStringSync(content);

  setUp(() => project = Directory.systemTemp.createTempSync('cocoapods'));
  tearDown(() => project.deleteSync(recursive: true));

  test('Pubspec gives dependency lines and the SwiftPM switch', () {
    final pubspec = Pubspec.parse(_pubspec);
    expect(pubspec.dependencyLines['firebase_auth'], 5);
    expect(pubspec.disablesSwiftPackageManager, isTrue);
    expect(pubspec.swiftPackageManagerLine, 9);
    expect(Pubspec.parse('name: a').disablesSwiftPackageManager, isFalse);
  });

  test('handAddedPodsIn skips Flutter\'s own lines and comments', () {
    final pods = CocoaPodsMigration.handAddedPodsIn('/Podfile', _podfile);
    expect(pods.single.name, 'GoogleMaps');
    expect(pods.single.line, 5);
  });

  test('withoutPodsIncludes keeps Flutter\'s own include', () {
    expect(
      CocoaPodsMigrator.withoutPodsIncludes(_debugXcconfig),
      '#include "Generated.xcconfig"\n',
    );
  });

  group('inspect', () {
    test('lists what blocks the move, at the line to change', () {
      write('pubspec.yaml', _pubspec);
      write('ios/Podfile', _podfile);

      final migration = CocoaPodsMigrator(_FakeRunner()).inspect(
        project.path,
        {FlutterPlatform.ios, FlutterPlatform.android},
        const [
          fcheck.PackagePlatformWarning(
            packageName: 'legacy_plugin',
            version: '1.0.0',
          ),
          fcheck.PackagePlatformWarning(
            packageName: 'firebase_core',
            version: '2.0.0',
            introducedBy: 'firebase_auth',
          ),
        ],
      );

      expect(migration.podPlatforms, {FlutterPlatform.ios});
      expect(migration.blockers.map((b) => (b.description, b.line)), [
        ('legacy_plugin 1.0.0', 6),
        ('firebase_core 2.0.0, through firebase_auth', 5),
      ]);
      expect(migration.handAddedPods.single.name, 'GoogleMaps');
      expect(migration.swiftPackageManagerOffLine, 9);
      expect(migration.canRemove, isFalse);
      expect(migration.isDone, isFalse);
      expect(migration.issues.expand((issue) => issue.quickFixes), [
        QuickFix.upgradePackages,
      ]);
    });

    test('offers removal once nothing needs CocoaPods', () {
      write('pubspec.yaml', 'name: app');
      write('macos/Podfile', 'flutter_install_all_macos_pods');

      final migration = CocoaPodsMigrator(_FakeRunner())
          .inspect(project.path, {FlutterPlatform.macos}, const []);

      expect(migration.canRemove, isTrue);
      expect(migration.issues.single.quickFixes, [QuickFix.removeCocoaPods]);
    });

    test('is done without Podfiles or blockers, and for non-Apple apps', () {
      final migrator = CocoaPodsMigrator(_FakeRunner());
      expect(
        migrator.inspect(project.path, {FlutterPlatform.ios}, const []).isDone,
        isTrue,
      );
      expect(
        migrator.inspect(project.path, {FlutterPlatform.web}, const []),
        same(CocoaPodsMigration.none),
      );
    });
  });

  group('remove', () {
    test('deintegrates, deletes the pod files and cleans xcconfigs', () async {
      write('ios/Podfile', 'flutter_install_all_ios_pods');
      write('ios/Podfile.lock', '');
      write('ios/Pods/Manifest.lock', '');
      write('ios/Flutter/Debug.xcconfig', _debugXcconfig);
      write('ios/Flutter/Generated.xcconfig', 'FLUTTER_ROOT=/x\n');
      final runner = _FakeRunner();
      final migrator = CocoaPodsMigrator(runner);

      final changed = await migrator.remove(
        migrator.inspect(project.path, {FlutterPlatform.ios}, const []),
      );

      expect(runner.commands, ['ios: pod deintegrate']);
      for (final gone in ['Podfile', 'Podfile.lock', 'Pods']) {
        expect(
          FileSystemEntity.typeSync(p.join(project.path, 'ios', gone)),
          FileSystemEntityType.notFound,
        );
      }
      expect(changed.map(p.basename), ['Debug.xcconfig']);
    });

    test('leaves the files alone when pod deintegrate fails', () async {
      write('ios/Podfile', 'flutter_install_all_ios_pods');
      final migrator = CocoaPodsMigrator(_FakeRunner(1));

      await expectLater(
        migrator.remove(
          migrator.inspect(project.path, {FlutterPlatform.ios}, const []),
        ),
        throwsA(isA<MaintenanceException>()),
      );
      expect(File(p.join(project.path, 'ios/Podfile')).existsSync(), isTrue);
    });
  });
}
