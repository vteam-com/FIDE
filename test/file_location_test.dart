import 'package:fide/models/file_location.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const projectDir = '/work/app';

  List<FileLocation> find(String text, {String? baseDir = projectDir}) =>
      FileLocation.findAll(text, baseDir: baseDir, exists: (_) => true);

  test('finds a compile error location relative to the project', () {
    const text =
        "lib/services/image_service.dart:20:13: Error: 'X' isn't a type.";

    final location = find(text).single;

    expect(location.path, '/work/app/lib/services/image_service.dart');
    expect(location.line, 20);
    expect(location.column, 13);
    expect(
      text.substring(location.start, location.end),
      'lib/services/image_service.dart:20:13',
    );
  });

  test('resolves parent-relative paths and defaults the column', () {
    final location = find('../pkg/lib/a.dart:46 Context').single;

    expect(location.path, '/work/pkg/lib/a.dart');
    expect(location.line, 46);
    expect(location.column, 1);
  });

  test('keeps absolute and file:// paths', () {
    final locations = find('/tmp/a.dart:1:2 and file:///tmp/b.dart:3');

    expect(locations.map((l) => l.path), ['/tmp/a.dart', '/tmp/b.dart']);
  });

  test('ignores hosts, durations and missing files', () {
    expect(find('localhost:11434 127.0.0.1:8080 took 16.0s'), isEmpty);
    expect(
      FileLocation.findAll(
        'lib/main.dart:1',
        baseDir: projectDir,
        exists: (_) => false,
      ),
      isEmpty,
    );
  });

  test('skips relative paths when there is no project', () {
    expect(find('lib/main.dart:1', baseDir: null), isEmpty);
  });
}
