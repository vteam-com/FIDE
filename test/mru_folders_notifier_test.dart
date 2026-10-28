import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late ProviderContainer container;

  // Creates [count] real folders so load() keeps them
  List<String> makeFolders(int count) => [
    for (var i = 0; i < count; i++) Directory('${root.path}/p$i')..createSync(),
  ].map((dir) => dir.path).toList();

  setUp(() {
    root = Directory.systemTemp.createTempSync('fide_mru_');
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
    root.deleteSync(recursive: true);
  });

  test('load drops folders that no longer exist', () async {
    final folders = makeFolders(1);
    SharedPreferences.setMockInitialValues({
      PrefKeys.mruFolders: [...folders, '${root.path}/gone'],
    });

    await container.read(mruFoldersProvider.notifier).load();

    expect(container.read(mruFoldersProvider), folders);
  });

  test('touch moves a folder to the front and caps the list', () async {
    final folders = makeFolders(AppMetric.mruFolderLimit + 1);
    final notifier = container.read(mruFoldersProvider.notifier);

    for (final folder in folders) {
      await notifier.touch(folder);
    }
    await notifier.touch(folders[2]);

    final mru = container.read(mruFoldersProvider);
    expect(mru.first, folders[2]);
    expect(mru, hasLength(AppMetric.mruFolderLimit));
    expect(mru.where((f) => f == folders[2]), hasLength(1));
  });

  test('remove persists the shortened list', () async {
    final folders = makeFolders(2);
    final notifier = container.read(mruFoldersProvider.notifier);
    await notifier.touch(folders[0]);
    await notifier.touch(folders[1]);

    await notifier.remove(folders[0]);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(PrefKeys.mruFolders), [folders[1]]);
  });
}
