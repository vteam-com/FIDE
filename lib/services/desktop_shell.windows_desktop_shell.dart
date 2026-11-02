part of 'desktop_shell.dart';

/// The Windows [DesktopShell]: Explorer, and `start` for default apps.
class WindowsDesktopShell extends DesktopShell {
  /// Creates the Windows shell launching its commands with [runner].
  const WindowsDesktopShell(super.runner);

  @override
  String get fileManagerName => 'Explorer';

  // `start` is a shell built-in; its first quoted argument is a title
  @override
  Future<void> openWithDefaultApp(String file) =>
      runner.run('cmd', ['/c', 'start', '', file]);

  @override
  Future<void> revealFile(String file) =>
      runner.run('explorer', ['/select,$file']);

  @override
  Future<void> revealInFileManager(String directory) =>
      runner.run('explorer', [directory]);
}
