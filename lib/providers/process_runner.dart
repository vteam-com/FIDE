import 'dart:async';
import 'dart:io';

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
  }) {
    return Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: runInShell,
    );
  }

  /// Opens [directory] in the platform's file manager (Finder, Explorer,
  /// or the desktop's default via xdg-open).
  Future<void> revealInFileManager(String directory) async {
    if (Platform.isMacOS) {
      await run('open', [directory]);
    } else if (Platform.isWindows) {
      await run('explorer', [directory]);
    } else if (Platform.isLinux) {
      await run('xdg-open', [directory]);
    }
  }

  /// Starts [executable] and returns the live process handle.
  Future<Process> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool runInShell = false,
    ProcessStartMode mode = ProcessStartMode.normal,
  }) {
    return Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
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
