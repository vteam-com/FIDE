import 'dart:io';

import 'package:fide/providers/flutter_build_service.dart';
import 'package:fide/providers/process_runner.dart';
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
  late int resets;
  late BuildOutput sink;

  setUp(() {
    output = [];
    errors = [];
    resets = 0;
    sink = BuildOutput(
      onOutput: output.add,
      onError: errors.add,
      onResetErrors: () => resets++,
    );
  });

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
            .build('/p', 'macos', sink);

        expect(exitCode, 0);
        expect(runner.commands, [
          'flutter build macos',
          'pod repo update',
          'flutter build macos',
        ]);
        expect(resets, 1);
      },
    );

    test('retries at most once when the repo is still stale', () async {
      final runner = FakeProcessRunner([
        const FakeReply(1, stderr: [_podRepoError]),
        const FakeReply(0),
        const FakeReply(1, stderr: [_podRepoError]),
      ]);

      final exitCode = await FlutterBuildService(runner)
          .build('/p', 'macos', sink);

      expect(exitCode, 1);
      expect(runner.commands, hasLength(3));
    });

    test('does not repair CocoaPods for non-macOS targets', () async {
      final runner = FakeProcessRunner([
        const FakeReply(1, stderr: [_podRepoError]),
      ]);

      final exitCode = await FlutterBuildService(runner)
          .build('/p', 'apk', sink);

      expect(exitCode, 1);
      expect(runner.commands, ['flutter build apk']);
    });

    test('adds the wasm dry-run opt-out for web builds', () async {
      final runner = FakeProcessRunner([const FakeReply(0)]);

      await FlutterBuildService(runner).build('/p', 'web', sink);

      expect(runner.commands, ['flutter build web --no-wasm-dry-run']);
    });
  });

  group('FlutterBuildService.clean', () {
    test('throws when flutter clean fails', () async {
      final runner = FakeProcessRunner([const FakeReply(1)]);

      expect(
        FlutterBuildService(runner).clean('/p', sink),
        throwsA(contains('exit code 1')),
      );
    });
  });

  group('FlutterBuildService.deepCleanMacOS', () {
    test('tolerates CocoaPods failures and runs every Flutter step', () async {
      final runner = FakeProcessRunner([
        const FakeReply(1),
        const FakeReply(1),
        const FakeReply(0),
        const FakeReply(0),
        const FakeReply(0),
      ]);

      await FlutterBuildService(runner).deepCleanMacOS('/p', sink);

      expect(runner.commands, [
        'pod repo update',
        'pod install --repo-update',
        'flutter clean',
        'flutter pub get',
        'flutter build macos',
      ]);
    });

    test('stops and names the Flutter step that failed', () async {
      final runner = FakeProcessRunner([
        const FakeReply(0),
        const FakeReply(0),
        const FakeReply(0),
        const FakeReply(1),
      ]);

      expect(
        FlutterBuildService(runner).deepCleanMacOS('/p', sink),
        throwsA(contains('pub get')),
      );
    });
  });

  test('isCocoaPodsRepoError recognises the out-of-date repo message', () {
    expect(FlutterBuildService.isCocoaPodsRepoError(_podRepoError), true);
    expect(FlutterBuildService.isCocoaPodsRepoError('Compiling...'), false);
  });
}
