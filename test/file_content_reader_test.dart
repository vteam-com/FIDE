import 'dart:io';

import 'package:fide/services/file_content_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  const reader = FileContentReader();

  setUp(() => root = Directory.systemTemp.createTempSync('fide_reader_'));
  tearDown(() => root.deleteSync(recursive: true));

  test('reads a file up to the size limit', () async {
    final path = '${root.path}/small.dart';
    File(path).writeAsStringSync('void main() {}');

    expect(await reader.isWithinMaxSize(path), true);
    expect(await reader.tryRead(path), 'void main() {}');
    expect(await reader.read(path), 'void main() {}');
  });

  test('refuses a file over the size limit', () async {
    final path = '${root.path}/big.txt';
    File(path).writeAsStringSync('x' * (FileContentReader.maxFileSize + 1));

    expect(await reader.isWithinMaxSize(path), false);
    expect(await reader.tryRead(path), isNull);
    expect(await reader.read(path), FileContentReader.tooBigMessage);
  });

  test('writes text, creating folders, and reads bytes back', () async {
    final path = '${root.path}/a/b/new.dart';

    expect(await reader.exists(path), false);
    await reader.write(path, 'class A {}');
    expect(await reader.exists(path), true);
    expect(await reader.readBytes(path), 'class A {}'.codeUnits);

    reader.writeSync('${root.path}/c/sync.dart', 'class B {}');
    expect(await reader.read('${root.path}/c/sync.dart'), 'class B {}');
  });
}
