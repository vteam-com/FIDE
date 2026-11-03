import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/services/file_content_reader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'notifier_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory project;
  late List<FileSystemItem> selected;
  late LastOpenedFileNotifier notifier;

  /// Creates [name] in the project and returns its path.
  String file(String name) {
    final path = p.join(project.path, name);
    File(path).writeAsStringSync('void main() {}');
    return path;
  }

  setUp(() {
    project = Directory.systemTemp.createTempSync('fide_last_file_');
    SharedPreferences.setMockInitialValues({});
    selected = [];
    notifier = LastOpenedFileNotifier(
      SharedPreferences.getInstance(),
      reader: const FileContentReader(),
      select: selected.add,
    );
  });

  tearDown(() => project.deleteSync(recursive: true));

  test('save remembers the file and tryReopen selects it', () async {
    final path = file('main.dart');

    await notifier.save(path);
    await notifier.tryReopen(project.path);

    expect(stateOf(notifier), path);
    expect(selected.single.path, path);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PrefKeys.lastOpenedFile), path);
  });

  test('skips a file outside the project, missing or unsupported', () async {
    final elsewhere = Directory.systemTemp.createTempSync('fide_other_');
    addTearDown(() => elsewhere.deleteSync(recursive: true));
    final outside = p.join(elsewhere.path, 'main.dart');
    File(outside).writeAsStringSync('');

    for (final path in [outside, p.join(project.path, 'gone.dart')]) {
      SharedPreferences.setMockInitialValues({PrefKeys.lastOpenedFile: path});
      await notifier.tryReopen(project.path);
    }
    SharedPreferences.setMockInitialValues({
      PrefKeys.lastOpenedFile: file('app.bin'),
    });
    await notifier.tryReopen(project.path);

    expect(selected, isEmpty);
  });

  test('the provider selects the reopened file', () async {
    final path = file('main.dart');
    SharedPreferences.setMockInitialValues({PrefKeys.lastOpenedFile: path});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(lastOpenedFileProvider.notifier)
        .tryReopen(project.path);

    expect(container.read(selectedFileProvider)?.path, path);
  });
}
