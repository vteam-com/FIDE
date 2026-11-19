import 'dart:io';

import 'package:fide/models/flutter_platform.dart';
import 'package:fide/services/process_runner.dart';
import 'package:path/path.dart' as p;

part 'desktop_shell.linux_desktop_shell.dart';
part 'desktop_shell.mac_desktop_shell.dart';
part 'desktop_shell.windows_desktop_shell.dart';

/// The desktop's own file manager, file associations and sound player:
/// revealing files and folders, opening files with their default app, and
/// playing sounds.
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
  ) => switch (FlutterPlatform.fromId(operatingSystem)) {
    FlutterPlatform.macos => MacDesktopShell(runner),
    FlutterPlatform.windows => WindowsDesktopShell(runner),
    _ => LinuxDesktopShell(runner),
  };

  /// Launches the shell's commands.
  final ProcessRunner runner;

  /// Name of the file manager, for menu labels.
  String get fileManagerName;

  /// Starts playing the WAV file [file] with the desktop's own player;
  /// the process exits when the sound ends, and killing it stops the sound.
  Future<Process> playSound(String file);

  /// Opens [file] with the application the OS associates with its type.
  Future<void> openWithDefaultApp(String file);

  /// Shows [file] selected in the file manager.
  Future<void> revealFile(String file);

  /// Opens [directory] in the file manager.
  Future<void> revealInFileManager(String directory);
}
