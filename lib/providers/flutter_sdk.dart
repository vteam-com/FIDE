import 'package:fide/providers/process_runner.dart';

/// Versions of the installed Flutter SDK, read from `flutter --version`.
class FlutterSdk {
  final ProcessRunner _runner;

  /// Creates an SDK probe that launches `flutter` through [_runner].
  const FlutterSdk([this._runner = const ProcessRunner()]);

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
