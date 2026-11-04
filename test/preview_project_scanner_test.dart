import 'dart:io';

import 'package:fide/services/preview_project_scanner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory project;

  setUp(() {
    project = Directory.systemTemp.createTempSync('preview_project_');
    void write(String path, String content) => File(p.join(project.path, path))
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
    write('lib/a.dart', '''
@Preview(name: 'One')
Widget one() => const SizedBox();

@Preview(name: 'Two')
Widget two() => const SizedBox();
''');
    write('lib/src/b.dart', '@Preview()\nWidget b() => const SizedBox();\n');
    write('lib/plain.dart', 'Widget plain() => const SizedBox();\n');
    write('lib/part.dart', "part of 'a.dart';\n@Preview()\nWidget c() => x;\n");
    write('test/t.dart', '@Preview()\nWidget t() => const SizedBox();\n');
  });

  tearDown(() => project.deleteSync(recursive: true));

  test("lists the lib files with previews, sorted, skipping parts", () async {
    final files = await const PreviewProjectScanner().scan(project.path);
    expect(files.map((f) => p.relative(f.path, from: project.path)), [
      p.join('lib', 'a.dart'),
      p.join('lib', 'src', 'b.dart'),
    ]);
    expect(files.first.scan.previews.map((d) => d.label), ['one', 'two']);
  });

  test('only keeps the one preview expanded', () async {
    final files = await const PreviewProjectScanner().scan(project.path);
    final scan = files.first.scan.only('two');
    expect(scan.previews.map((d) => d.label), ['two']);
  });

  test('finds nothing in a project without lib', () async {
    Directory(p.join(project.path, 'lib')).deleteSync(recursive: true);
    expect(await const PreviewProjectScanner().scan(project.path), isEmpty);
  });
}
