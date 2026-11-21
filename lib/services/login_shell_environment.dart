import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fide/constants/core_constants.dart';

/// The `PATH` of the user's login shell, and a UTF-8 locale, for launching
/// tools like `flutter` or `pod`.
///
/// A macOS app opened from the Dock or Finder inherits launchd's minimal
/// `PATH` (`/usr/bin:/bin:/usr/sbin:/sbin`), not the one the user's shell
/// profile builds, so commands such as `flutter`, `pod` or `ollama` are not
/// found. [load] asks the login shell for its `PATH` once, and [overrides]
/// hands it to every launched process.
///
/// launchd sets no locale either, which leaves CocoaPods reading paths as
/// ASCII: `pod` warns that it requires UTF-8 and fails. [overrides] then
/// sets [utf8Locale], as Flutter does when it runs `pod`.
class LoginShellEnvironment {
  static const String _pathKey = 'PATH';
  static const String _marker = '__FIDE_PATH__';

  /// Environment variable naming the locale of whatever no `LC_*`
  /// variable names.
  static const String _langKey = 'LANG';

  /// Environment variables naming the locale of text encoding, the first
  /// set one winning.
  static const List<String> _encodingLocaleKeys = [
    'LC_ALL',
    'LC_CTYPE',
    _langKey,
  ];

  /// The locale launched processes get when the app's environment names
  /// none: the one Flutter gives `pod`, with English messages, as tools
  /// print without a locale.
  static const String utf8Locale = 'en_US.UTF-8';

  /// Environment variable naming the user's shell.
  static const String _shellKey = 'SHELL';

  /// The shell used when [_shellKey] names none: macOS's default.
  static const String _defaultShell = '/bin/zsh';
  static const int _timedOutExitCode = -1;

  static Future<Map<String, String>>? _overrides;

  /// When the last read failed; null while none did.
  static DateTime? _failedAt;

  /// Whether a read after a failure runs now.
  static bool _retrying = false;

  const LoginShellEnvironment._();

  /// The user's shell, as `$SHELL` names it, else zsh.
  static String get shell => Platform.environment[_shellKey] ?? _defaultShell;

  /// Starts reading the login shell's `PATH`; safe to call more than once.
  ///
  /// A failed read is kept, so launches don't each wait on the shell
  /// again; it is retried in the background at most once every
  /// [AppDuration.loginShellRetryInterval], while launches go on without
  /// the `PATH`: the profile may have been waiting on a macOS privacy
  /// prompt (for example, a `.zshrc` sourcing a file from `~/Downloads`)
  /// that the user answered since.
  static Future<Map<String, String>> load() {
    final failedAt = _failedAt;
    if (failedAt != null &&
        !_retrying &&
        DateTime.now().difference(failedAt) >=
            AppDuration.loginShellRetryInterval) {
      _retrying = true;
      unawaited(
        _read().then((overrides) {
          _retrying = false;
          if (overrides.containsKey(_pathKey)) {
            _overrides = Future.value(overrides);
          }
        }),
      );
    }
    return _overrides ??= _read();
  }

  /// Reads the overrides, noting when the read of `PATH` fails.
  static Future<Map<String, String>> _read() async {
    final overrides = await _readOverrides();
    _failedAt = !overrides.containsKey(_pathKey) && _needsLoginShell
        ? DateTime.now()
        : null;
    return overrides;
  }

  /// Whether this platform's apps miss the login shell's `PATH`.
  static bool get _needsLoginShell => Platform.isMacOS || Platform.isLinux;

  /// Environment variables to set on launched processes: the login shell's
  /// `PATH`, unless it couldn't be read, and [utf8Locale] when the app's
  /// environment names no locale; nothing where neither is needed.
  static Future<Map<String, String>> get overrides => load();

  static Future<Map<String, String>> _readOverrides() async {
    if (!_needsLoginShell) return const {};
    final path = await _readLoginShellPath();
    return {...localeOverrides(Platform.environment), _pathKey: ?path};
  }

  /// `LANG` set to [utf8Locale] when [environment] names no locale for
  /// text encoding, else nothing: a locale the user chose is kept.
  static Map<String, String> localeOverrides(Map<String, String> environment) {
    final named = _encodingLocaleKeys.any(
      (key) => environment[key]?.isNotEmpty ?? false,
    );
    return named ? const {} : const {_langKey: utf8Locale};
  }

  /// Runs the user's shell as an interactive login shell, so every profile
  /// file that edits `PATH` is sourced, and prints `PATH` between markers to
  /// skip any banner the profile prints.
  static Future<String?> _readLoginShellPath() async {
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
