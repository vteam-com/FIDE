part of 'desktop_shell.dart';

/// The Linux (freedesktop) [DesktopShell]: the desktop's defaults through
/// `xdg-open`.
class LinuxDesktopShell extends DesktopShell {
  /// Creates the Linux shell launching `xdg-open` with [runner].
  const LinuxDesktopShell(super.runner);

  @override
  String get fileManagerName => 'File Manager';

  @override
  Future<void> openWithDefaultApp(String file) =>
      runner.run('xdg-open', [file]);

  /// Opens the folder holding [file]: there is no common way to select it.
  @override
  Future<void> revealFile(String file) => revealInFileManager(p.dirname(file));

  @override
  Future<void> revealInFileManager(String directory) =>
      runner.run('xdg-open', [directory]);
}
