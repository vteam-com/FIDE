import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fide/services/login_shell_environment.dart';

/// Receives the output of a streamed process, one trimmed non-empty chunk at a time.
typedef ProcessOutputCallback = void Function(String text);

/// Single seam for launching external commands (git, flutter, pod, ollama...).
///
/// Services take a [ProcessRunner] instead of calling [Process] directly so
/// tests can substitute a fake that records commands and returns canned
/// results.
class ProcessRunner {
  /// Creates a runner that executes real system processes.
  const ProcessRunner();

  /// Runs [executable] to completion and returns its collected output.
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool runInShell = false,
  }) async {
    return Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: await LoginShellEnvironment.overrides,
      runInShell: runInShell,
    );
  }

  /// Runs [executable] with [input] written to its stdin, then collects its
  /// UTF-8 output like [run].
  Future<ProcessResult> runWithInput(
    String executable,
    List<String> arguments,
    String input, {
    String? workingDirectory,
  }) async {
    final process = await start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
    );
    final stdout = process.stdout.transform(utf8.decoder).join();
    final stderr = process.stderr.transform(utf8.decoder).join();
    process.stdin.add(utf8.encode(input));
    await process.stdin.close();
    return ProcessResult(
      process.pid,
      await process.exitCode,
      await stdout,
      await stderr,
    );
  }

  /// Runs [executable] and returns its raw stdout bytes when it exits 0,
  /// or null when it fails or can't be started: for binary output such as
  /// `git show` of an image.
  Future<Uint8List?> bytesOf(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    try {
      final result = await Process.run(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        environment: await LoginShellEnvironment.overrides,
        stdoutEncoding: null,
      );
      if (result.exitCode != 0) return null;
      return Uint8List.fromList(result.stdout as List<int>);
    } catch (_) {
      return null;
    }
  }

  /// Runs [executable] and returns its stdout when it exits 0, or null when
  /// it fails or can't be started (for example, when it isn't installed).
  Future<String?> outputOf(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool runInShell = false,
  }) async {
    try {
      final result = await run(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        runInShell: runInShell,
      );
      return result.exitCode == 0 ? result.stdout.toString() : null;
    } catch (_) {
      return null;
    }
  }

  /// Whether [executable] runs and exits 0; false when it can't be started.
  Future<bool> succeeds(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    return await outputOf(
          executable,
          arguments,
          workingDirectory: workingDirectory,
        ) !=
        null;
  }

  /// Starts [executable] and returns the live process handle.
  Future<Process> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool runInShell = false,
    ProcessStartMode mode = ProcessStartMode.normal,
  }) async {
    return Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: await LoginShellEnvironment.overrides,
      runInShell: runInShell,
      mode: mode,
    );
  }

  /// Starts [executable], forwards each trimmed non-empty stdout/stderr chunk
  /// to [onStdout]/[onStderr], and completes with the exit code once both
  /// streams are drained.
  ///
  /// [onStarted] receives the process handle so callers can kill it.
  Future<int> stream(
    String executable,
    List<String> arguments, {
    required ProcessOutputCallback onStdout,
    required ProcessOutputCallback onStderr,
    String? workingDirectory,
    bool runInShell = true,
    void Function(Process)? onStarted,
  }) async {
    final process = await start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: runInShell,
    );
    onStarted?.call(process);

    Future<void> pipe(Stream<List<int>> source, ProcessOutputCallback sink) {
      return source.transform(const SystemEncoding().decoder).forEach((data) {
        final text = data.trim();
        if (text.isNotEmpty) {
          sink(text);
        }
      });
    }

    final drained = Future.wait([
      pipe(process.stdout, onStdout),
      pipe(process.stderr, onStderr),
    ]);
    final exitCode = await process.exitCode;
    await drained;
    return exitCode;
  }
}
