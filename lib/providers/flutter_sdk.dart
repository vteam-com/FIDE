import 'dart:convert';

import 'package:fide/providers/process_runner.dart';
import 'package:path/path.dart' as p;

/// Versions of the installed Flutter SDK, read from `flutter --version`.
class FlutterSdk {
  final ProcessRunner _runner;

  /// Creates an SDK probe that launches `flutter` through [_runner].
  const FlutterSdk([this._runner = const ProcessRunner()]);

  /// Root of the Dart SDK bundled with Flutter, from
  /// `flutter --version --machine`; null when Flutter isn't available or
  /// doesn't report its root.
  Future<String?> dartSdkPath() async {
    final output = await _runner.outputOf('flutter', [
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

  /// Flutter and Dart versions (e.g. `3.24.0`), or null when Flutter isn't
  /// available. Either version is null when the output doesn't show it.
  Future<({String? flutter, String? dart})?> versions() async {
    final output = await _runner.outputOf('flutter', [
      '--version',
    ], runInShell: true);
    if (output == null) return null;

    // e.g. "Flutter 3.24.0 • channel stable" ... "Dart 3.5.0 • DevTools 2.37.2"
    String? versionAfter(String name) =>
        RegExp('$name (\\d+\\.\\d+\\.\\d+)').firstMatch(output)?.group(1);
    return (flutter: versionAfter('Flutter'), dart: versionAfter('Dart'));
  }
}
