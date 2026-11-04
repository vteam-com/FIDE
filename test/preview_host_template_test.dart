import 'dart:io';

import 'package:fide/services/preview_registry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// The preview host ships as an asset that FIDE's own analysis doesn't
/// see: this analyzes it against FIDE's Flutter packages, with an empty
/// registry, so a host that doesn't compile never ships.
void main() {
  test('the preview host template analyzes without errors', () async {
    final folder = Directory(
      p.join(Directory.current.path, '.dart_tool', 'fide_preview_check'),
    )..createSync(recursive: true);
    addTearDown(() => folder.deleteSync(recursive: true));
    File(p.join(folder.path, 'main.dart')).writeAsStringSync(
      File('assets/preview_host/main.dart.tmpl').readAsStringSync(),
    );
    File(p.join(folder.path, 'previews.dart'))
        .writeAsStringSync(PreviewRegistry.emptySource);

    final result = await Process.run('dart', [
      'analyze',
      '--no-fatal-warnings',
      folder.path,
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
