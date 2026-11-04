import 'dart:io';

import 'package:fide/models/flutter_platform.dart';
import 'package:fide/services/flutter_build_service.dart';
import 'package:fide/services/process_runner.dart';
import 'package:flutter_test/flutter_test.dart';

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
  late BuildOutput sink;

  setUp(() {
    output = [];
    errors = [];
    sink = BuildOutput(onOutput: output.add, onError: errors.add);
  });

  group('FlutterBuildService.build', () {
    test('runs flutter build once and returns its exit code', () async {
      final runner = FakeProcessRunner([
        const FakeReply(1, stderr: ['failed']),
      ]);

      final exitCode = await FlutterBuildService(runner)
          .build('/p', FlutterPlatform.ios, sink);

      expect(exitCode, 1);
      expect(runner.commands, ['flutter build ios']);
      expect(errors, ['failed']);
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
              .having((e) => e.exitCode, 'exitCode', 1)
              .having((e) => '$e', 'text', 'flutter clean exited with 1'),
        ),
      );
    });
  });

  group('FlutterBuildService.build targets', () {
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
}
