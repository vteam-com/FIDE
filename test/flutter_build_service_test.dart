import 'dart:io';

import 'package:fide/models/build_step_event.dart';
import 'package:fide/models/flutter_platform.dart';
import 'package:fide/services/flutter_build_service.dart';
import 'package:fide/services/process_runner.dart';
import 'package:flutter_test/flutter_test.dart';

const String _podRepoError =
    "CocoaPods's specs repository is too out-of-date to satisfy dependencies";

// Scripted reply for one fake command
class FakeReply {
  final int exitCode;
  final List<String> stderr;

  const FakeReply(this.exitCode, {this.stderr = const []});
}

// Records each streamed command and answers from a script, in order
class FakeProcessRunner extends ProcessRunner {
  final List<FakeReply> replies;
  final List<String> commands = [];

  FakeProcessRunner(this.replies);

  @override
  Future<int> stream(
    String executable,
    List<String> arguments, {
    required ProcessOutputCallback onStdout,
    required ProcessOutputCallback onStderr,
    String? workingDirectory,
    bool runInShell = true,
    void Function(Process process)? onStarted,
  }) async {
    commands.add([executable, ...arguments].join(' '));
    final reply = replies.removeAt(0);
    reply.stderr.forEach(onStderr);
    return reply.exitCode;
  }
}

void main() {
  late List<String> output;
  late List<String> errors;
  late List<BuildStepEvent> steps;
  late int resets;
  late BuildOutput sink;

  setUp(() {
    output = [];
    errors = [];
    steps = [];
    resets = 0;
    sink = BuildOutput(
      onOutput: output.add,
      onError: errors.add,
      onStep: steps.add,
      onResetErrors: () => resets++,
    );
  });

  /// The steps reported so far as `step/status` names.
  Iterable<String> stepNames() =>
      steps.map((e) => '${e.step.name}/${e.status.name}');

  group('FlutterBuildService.build', () {
    test(
      'repairs a stale CocoaPods repo and retries a macOS build once',
      () async {
        final runner = FakeProcessRunner([
          const FakeReply(1, stderr: [_podRepoError]),
          const FakeReply(0),
          const FakeReply(0),
        ]);

        final exitCode = await FlutterBuildService(runner)
            .build('/p', FlutterPlatform.macos, sink);

        expect(exitCode, 0);
        expect(runner.commands, [
          'flutter build macos',
          'pod repo update',
          'flutter build macos',
        ]);
        expect(resets, 1);
        expect(stepNames(), [
          'podRepoRepair/needed',
          'podRepoRepair/started',
          'podRepoRepair/succeeded',
          'flutterBuild/retrying',
        ]);
        expect(steps.first.detail, _podRepoError);
      },
    );

    test('reports a repair that fails without retrying', () async {
      final runner = FakeProcessRunner([
        const FakeReply(1, stderr: [_podRepoError]),
        const FakeReply(1),
      ]);

      final exitCode = await FlutterBuildService(runner)
          .build('/p', FlutterPlatform.macos, sink);

      expect(exitCode, 1);
      expect(stepNames().last, 'podRepoRepair/failed');
    });

    test('retries at most once when the repo is still stale', () async {
      final runner = FakeProcessRunner([
        const FakeReply(1, stderr: [_podRepoError]),
        const FakeReply(0),
        const FakeReply(1, stderr: [_podRepoError]),
      ]);

      final exitCode = await FlutterBuildService(runner)
          .build('/p', FlutterPlatform.macos, sink);

      expect(exitCode, 1);
      expect(runner.commands, hasLength(3));
    });

    test('does not repair CocoaPods for platforms without CocoaPods', () async {
      final runner = FakeProcessRunner([
        const FakeReply(1, stderr: [_podRepoError]),
      ]);

      final exitCode = await FlutterBuildService(runner)
          .build('/p', FlutterPlatform.android, sink);

      expect(exitCode, 1);
      expect(runner.commands, ['flutter build apk']);
    });

    test('adds the wasm dry-run opt-out for web builds', () async {
      final runner = FakeProcessRunner([const FakeReply(0)]);

      await FlutterBuildService(runner).build('/p', FlutterPlatform.web, sink);

      expect(runner.commands, ['flutter build web --no-wasm-dry-run']);
    });
  });

  group('FlutterBuildService.clean', () {
    test('throws when flutter clean fails', () async {
      final runner = FakeProcessRunner([const FakeReply(1)]);

      expect(
        FlutterBuildService(runner).clean('/p', sink),
        throwsA(
          isA<BuildException>()
              .having((e) => e.step, 'step', BuildStep.flutterClean)
              .having((e) => e.exitCode, 'exitCode', 1)
              .having((e) => '$e', 'text', 'flutter clean exited with 1'),
        ),
      );
    });
  });

  group('FlutterBuildService.build targets', () {
    test('repairs a stale CocoaPods repo for iOS builds too', () async {
      final runner = FakeProcessRunner([
        const FakeReply(1, stderr: [_podRepoError]),
        const FakeReply(0),
        const FakeReply(0),
      ]);

      final exitCode = await FlutterBuildService(runner)
          .build('/p', FlutterPlatform.ios, sink);

      expect(exitCode, 0);
      expect(runner.commands, [
        'flutter build ios',
        'pod repo update',
        'flutter build ios',
      ]);
    });

    test('builds an Android App Bundle with the appbundle target', () async {
      final runner = FakeProcessRunner([const FakeReply(0)]);

      await FlutterBuildService(runner).build(
        '/p',
        FlutterPlatform.android,
        sink,
        target: FlutterPlatform.appBundleTarget,
      );

      expect(runner.commands, ['flutter build appbundle']);
    });
  });

  group('FlutterBuildService.test', () {
    test('runs the given test files with coverage', () async {
      final runner = FakeProcessRunner([const FakeReply(0)]);

      final exitCode = await FlutterBuildService(runner)
          .test('/p', sink, paths: ['test/a_test.dart'], coverage: true);

      expect(exitCode, 0);
      expect(runner.commands, ['flutter test --coverage test/a_test.dart']);
    });
  });

  group('FlutterBuildService.deepClean', () {
    test('tolerates CocoaPods failures and runs every Flutter step', () async {
      final runner = FakeProcessRunner([
        const FakeReply(1),
        const FakeReply(1),
        const FakeReply(0),
        const FakeReply(0),
        const FakeReply(0),
      ]);

      await FlutterBuildService(runner)
          .deepClean('/p', FlutterPlatform.macos, sink);

      expect(runner.commands, [
        'pod repo update',
        'pod install --repo-update',
        'flutter clean',
        'flutter pub get',
        'flutter build macos',
      ]);
      expect(stepNames(), [
        'podRepoUpdate/started',
        'podRepoUpdate/failed',
        'podInstall/started',
        'podInstall/failed',
        'flutterClean/started',
        'pubGet/started',
        'flutterBuild/started',
        'deepClean/succeeded',
      ]);
      expect(steps.last.toString(), contains('deepClean'));
      expect(steps[3].exitCode, 1);
      expect(steps[6].detail, 'build macos');
    });

    test('stops and names the Flutter step that failed', () async {
      final runner = FakeProcessRunner([
        const FakeReply(0),
        const FakeReply(0),
        const FakeReply(0),
        const FakeReply(1),
      ]);

      expect(
        FlutterBuildService(runner)
            .deepClean('/p', FlutterPlatform.macos, sink),
        throwsA(
          isA<BuildException>()
              .having((e) => e.step, 'step', BuildStep.pubGet)
              .having((e) => e.arguments, 'arguments', 'pub get'),
        ),
      );
    });
  });

  test('isCocoaPodsRepoError recognises the out-of-date repo message', () {
    expect(FlutterBuildService.isCocoaPodsRepoError(_podRepoError), true);
    expect(FlutterBuildService.isCocoaPodsRepoError('Compiling...'), false);
  });
}
