import 'dart:io';

import 'package:fide/services/process_runner.dart';
import 'package:path/path.dart' as p;

part 'desktop_shell.linux_desktop_shell.dart';
part 'desktop_shell.mac_desktop_shell.dart';
part 'desktop_shell.windows_desktop_shell.dart';

/// The desktop's own file manager and file associations: revealing files
/// and folders, and opening files with their default app.
///
/// One implementation per operating system, each launching its commands
/// through a [ProcessRunner]; [DesktopShell.forOperatingSystem] picks it.
abstract class DesktopShell {
  /// Creates a shell launching its commands with [runner].
  const DesktopShell(this.runner);

  /// The shell of [operatingSystem], as [Platform.operatingSystem] names
  /// it; other Unix desktops get the freedesktop one of Linux.
  factory DesktopShell.forOperatingSystem(
    String operatingSystem,
    ProcessRunner runner,
  ) => switch (operatingSystem) {
    macOS => MacDesktopShell(runner),
    windows => WindowsDesktopShell(runner),
    _ => LinuxDesktopShell(runner),
  };

  /// [Platform.operatingSystem] on macOS.
  static const String macOS = 'macos';

  /// [Platform.operatingSystem] on Windows.
  static const String windows = 'windows';

  /// Launches the shell's commands.
  final ProcessRunner runner;

  /// Name of the file manager, for menu labels.
  String get fileManagerName;

  /// Opens [file] with the application the OS associates with its type.
  Future<void> openWithDefaultApp(String file);

  /// Shows [file] selected in the file manager.
  Future<void> revealFile(String file);

  /// Opens [directory] in the file manager.
  Future<void> revealInFileManager(String directory);
}
