import 'dart:io';

import 'package:fide/services/desktop_shell.dart';
import 'package:fide/services/process_runner.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records each command line instead of running it.
class RecordingRunner extends ProcessRunner {
  final List<String> commands = [];

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool runInShell = false,
  }) async {
    commands.add([executable, ...arguments].join(' '));
    return ProcessResult(0, 0, '', '');
  }
}

void main() {
  late RecordingRunner runner;

  setUp(() => runner = RecordingRunner());

  /// Runs every shell action of [operatingSystem]'s shell on sample paths.
  Future<DesktopShell> exercise(String operatingSystem) async {
    final shell = DesktopShell.forOperatingSystem(operatingSystem, runner);
    await shell.openWithDefaultApp('/p/a.png');
    await shell.revealFile('/p/a.png');
    await shell.revealInFileManager('/p');
    return shell;
  }

  test('macOS uses Finder through open', () async {
    final shell = await exercise('macos');
    expect(shell, isA<MacDesktopShell>());
    expect(shell.fileManagerName, 'Finder');
    expect(runner.commands, ['open /p/a.png', 'open -R /p/a.png', 'open /p']);
  });

  test('Windows uses Explorer and start', () async {
    final shell = await exercise('windows');
    expect(shell, isA<WindowsDesktopShell>());
    expect(shell.fileManagerName, 'Explorer');
    expect(runner.commands, [
      'cmd /c start  /p/a.png',
      'explorer /select,/p/a.png',
      'explorer /p',
    ]);
  });

  test('Linux and other desktops use xdg-open, revealing the folder', () async {
    for (final os in ['linux', 'fuchsia']) {
      runner.commands.clear();
      final shell = await exercise(os);
      expect(shell, isA<LinuxDesktopShell>());
      expect(shell.fileManagerName, 'File Manager');
      expect(runner.commands, [
        'xdg-open /p/a.png',
        'xdg-open /p',
        'xdg-open /p',
      ]);
    }
  });
}
