import 'dart:convert';
import 'dart:io';

import 'package:fide/models/tool_version.dart';
import 'package:fide/services/process_runner.dart';
import 'package:path/path.dart' as p;

/// Resolves the command launching the Dart tool.
typedef DartCommand = Future<String> Function();

/// Versions of the installed Flutter SDK, read from `flutter --version`.
class FlutterSdk {
  /// The command running the Flutter tool, found on the login shell's
  /// `PATH`.
  static const String executable = 'flutter';

  /// The command running the Dart tool (`dart format`, `dart analyze`)
  /// found on the login shell's `PATH`, which may not be Flutter's.
  static const String dartExecutable = 'dart';

  /// The Dart tool's file name in a Dart SDK's `bin` folder on Windows.
  static const String _windowsDartFile = 'dart.exe';

  /// The folder of a Dart SDK holding its tools.
  static const String _sdkBinFolder = 'bin';

  final ProcessRunner _runner;

  /// Creates an SDK probe that launches `flutter` through [_runner].
  const FlutterSdk(this._runner);

  /// Root of the Dart SDK bundled with Flutter, from
  /// `flutter --version --machine`; null when Flutter isn't available or
  /// doesn't report its root.
  Future<String?> dartSdkPath() async {
    final output = await _runner.outputOf(executable, [
      '--version',
      '--machine',
    ], runInShell: true);
    if (output == null) return null;
    try {
      final flutterRoot = (jsonDecode(output) as Map)['flutterRoot'];
      if (flutterRoot is! String) return null;
      return p.join(flutterRoot, 'bin', 'cache', 'dart-sdk');
    } on FormatException {
      return null;
    }
  }

  /// The Dart tool bundled with Flutter, so `dart analyze` and
  /// `dart format` match the SDK projects build with; [dartExecutable] on
  /// the `PATH` when Flutter does not report one.
  Future<String> bundledDart() async => dartIn(await dartSdkPath());

  /// The Dart tool of the Dart SDK at [sdkPath], as [dartSdkPath] finds
  /// it; [dartExecutable] on the `PATH` without one.
  static Future<String> dartIn(String? sdkPath) async {
    if (sdkPath == null) return dartExecutable;
    final dart = p.join(
      sdkPath,
      _sdkBinFolder,
      Platform.isWindows ? _windowsDartFile : dartExecutable,
    );
    return await File(dart).exists() ? dart : dartExecutable;
  }

  /// [dartExecutable] on the `PATH`, for tools given no Flutter SDK.
  static Future<String> dartOnPath() async => dartExecutable;

  /// Flutter and Dart versions (e.g. `3.24.0`), or null when Flutter isn't
  /// available. Either version is null when the output doesn't show it.
  Future<({String? flutter, String? dart})?> versions() async {
    final output = await _runner.outputOf(executable, [
      '--version',
    ], runInShell: true);
    if (output == null) return null;

    // e.g. "Flutter 3.24.0 • channel stable" ... "Dart 3.5.0 • DevTools 2.37.2"
    return (
      flutter: versionAfter('Flutter', output),
      dart: versionAfter('Dart', output),
    );
  }
}
