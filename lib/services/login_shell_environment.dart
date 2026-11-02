import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fide/constants/core_constants.dart';

/// The `PATH` of the user's login shell, for launching tools like `flutter`.
///
/// A macOS app opened from the Dock or Finder inherits launchd's minimal
/// `PATH` (`/usr/bin:/bin:/usr/sbin:/sbin`), not the one the user's shell
/// profile builds, so commands such as `flutter`, `pod` or `ollama` are not
/// found. [load] asks the login shell for its `PATH` once, and [overrides]
/// hands it to every launched process.
class LoginShellEnvironment {
  static const String _pathKey = 'PATH';
  static const String _marker = '__FIDE_PATH__';
  static const String _defaultShell = '/bin/zsh';
  static const int _timedOutExitCode = -1;

  static Future<Map<String, String>>? _overrides;

  const LoginShellEnvironment._();

  /// Starts reading the login shell's `PATH`; safe to call more than once.
  ///
  /// A failed read is not kept, so the next call tries again: the profile
  /// may have been waiting on a macOS privacy prompt (for example, a
  /// `.zshrc` sourcing a file from `~/Downloads`) that the user answered
  /// since.
  static Future<Map<String, String>> load() {
    return _overrides ??= _readOverrides().then((overrides) {
      if (overrides.isEmpty) _overrides = null;
      return overrides;
    });
  }

  /// Environment variables to set on launched processes: the login shell's
  /// `PATH`, or nothing when it couldn't be read or isn't needed.
  static Future<Map<String, String>> get overrides => load();

  static Future<Map<String, String>> _readOverrides() async {
    if (!Platform.isMacOS && !Platform.isLinux) return const {};
    final path = await _readLoginShellPath();
    return path == null ? const {} : {_pathKey: path};
  }

  /// Runs the user's shell as an interactive login shell, so every profile
  /// file that edits `PATH` is sourced, and prints `PATH` between markers to
  /// skip any banner the profile prints.
  static Future<String?> _readLoginShellPath() async {
    final shell = Platform.environment['SHELL'] ?? _defaultShell;
    try {
      final process = await Process.start(shell, [
        '-l',
        '-i',
        '-c',
        'printf "%s" "$_marker\${$_pathKey}$_marker"',
      ]);
      unawaited(process.stdin.close());
      unawaited(process.stderr.drain<void>());
      final output = process.stdout.transform(utf8.decoder).join();
      final exitCode = await process.exitCode.timeout(
        AppDuration.loginShellTimeout,
        onTimeout: () {
          process.kill(ProcessSignal.sigkill);
          return _timedOutExitCode;
        },
      );
      if (exitCode != 0) return null;
      final match = RegExp('$_marker(.*)$_marker').firstMatch(await output);
      final path = match?.group(1)?.trim() ?? '';
      return path.isEmpty ? null : path;
    } catch (_) {
      return null;
    }
  }
}
