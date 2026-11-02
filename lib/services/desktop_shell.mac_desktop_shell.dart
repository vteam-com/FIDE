part of 'desktop_shell.dart';

/// The macOS [DesktopShell]: Finder, through `open`.
class MacDesktopShell extends DesktopShell {
  /// Creates the macOS shell launching `open` with [runner].
  const MacDesktopShell(super.runner);

  @override
  String get fileManagerName => 'Finder';

  @override
  Future<void> openWithDefaultApp(String file) => runner.run('open', [file]);

  @override
  Future<void> revealFile(String file) => runner.run('open', ['-R', file]);

  @override
  Future<void> revealInFileManager(String directory) =>
      runner.run('open', [directory]);
}
