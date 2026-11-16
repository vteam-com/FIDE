part of 'desktop_shell.dart';

/// The Linux (freedesktop) [DesktopShell]: the desktop's defaults through
/// `xdg-open`, and sounds through PulseAudio's `paplay` (PipeWire provides
/// it too), or ALSA's `aplay` without it.
class LinuxDesktopShell extends DesktopShell {
  /// Creates the Linux shell launching `xdg-open` with [runner].
  const LinuxDesktopShell(super.runner);

  @override
  String get fileManagerName => 'File Manager';

  @override
  Future<void> openWithDefaultApp(String file) =>
      runner.run('xdg-open', [file]);

  @override
  Future<Process> playSound(String file) async {
    try {
      return await runner.start('paplay', [file]);
    } on ProcessException {
      return runner.start('aplay', [file]);
    }
  }

  /// Opens the folder holding [file]: there is no common way to select it.
  @override
  Future<void> revealFile(String file) => revealInFileManager(p.dirname(file));

  @override
  Future<void> revealInFileManager(String directory) =>
      runner.run('xdg-open', [directory]);
}
