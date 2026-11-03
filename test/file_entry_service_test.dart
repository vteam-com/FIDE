import 'dart:io';

import 'package:fide/services/file_entry_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  const files = FileEntryService();

  setUp(() => root = Directory.systemTemp.createTempSync('fide_entries_'));
  tearDown(() => root.deleteSync(recursive: true));

  test('creates, renames and deletes files and folders', () async {
    final folder = '${root.path}/a/b';
    final file = '$folder/x.dart';

    await files.create(folder, isDirectory: true);
    await files.create(file, isDirectory: false);
    expect(files.exists(file), true);
    expect(files.folderExists(folder), true);
    expect(files.folderExists(file), false);

    await files.rename(file, '$folder/y.dart', isDirectory: false);
    expect(files.exists(file), false);
    expect(files.exists('$folder/y.dart'), true);

    await files.delete('${root.path}/a', isDirectory: true);
    expect(files.exists(folder), false);
    expect(files.folderExists(folder), false);
  });

  test('lists every file below a folder, none for a missing one', () async {
    final folder = '${root.path}/tree';
    await files.create('$folder/a.dart', isDirectory: false);
    await files.create('$folder/sub/b.dart', isDirectory: false);
    await files.create('$folder/sub/empty', isDirectory: true);

    final listed = await files.listFiles(folder);

    expect(listed..sort(), ['$folder/a.dart', '$folder/sub/b.dart']);
    expect(await files.listFiles('${root.path}/missing'), isEmpty);
  });
}
