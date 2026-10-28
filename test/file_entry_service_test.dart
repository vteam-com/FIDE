import 'dart:io';

import 'package:fide/providers/file_entry_service.dart';
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

    await files.rename(file, '$folder/y.dart', isDirectory: false);
    expect(files.exists(file), false);
    expect(files.exists('$folder/y.dart'), true);

    await files.delete('${root.path}/a', isDirectory: true);
    expect(files.exists(folder), false);
  });
}
