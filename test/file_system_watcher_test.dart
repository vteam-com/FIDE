import 'dart:io';

import 'package:fide/constants/core_constants.dart';
import 'package:fide/models/project_node.dart';
import 'package:fide/services/file_system_watcher.dart';
import 'package:fide/services/project_tree_reader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Long enough for file system events to arrive and the tree update after
/// them to fire.
const _settle = Duration(seconds: 1);

const _reader = ProjectTreeReader();

void main() {
  late Directory root;
  late ProjectNode tree;
  late FileSystemWatcher watcher;
  late int updates;

  setUp(() async {
    // Resolved, as event paths are
    root = Directory(
      Directory.systemTemp
          .createTempSync('fide_watch_')
          .resolveSymbolicLinksSync(),
    );
    Directory(p.join(root.path, 'lib')).createSync();
    File(p.join(root.path, 'lib', 'main.dart')).writeAsStringSync('main\n');
    tree = await _reader.nodeFor(root);
    await _reader.loadTree(tree);
    updates = 0;
    watcher = FileSystemWatcher()..initialize(tree, () => updates++);
    // Lets the watchers start before the test touches the disk
    await Future<void>.delayed(AppDuration.updateDebounce);
  });

  tearDown(() {
    watcher.dispose();
    root.deleteSync(recursive: true);
  });

  /// [tree]'s node at the path [relative] to the project, or null.
  ProjectNode? nodeAt(String relative) =>
      tree.findNode(p.join(root.path, relative));

  test('lists new build output without reading or watching it', () async {
    for (final folder in ['build', '.dart_tool']) {
      Directory(p.join(root.path, folder)).createSync();
    }
    await Future<void>.delayed(AppDuration.updateDebounce);
    for (final file in ['build/app/out.o', '.dart_tool/cache/x.json']) {
      File(p.join(root.path, file))
        ..createSync(recursive: true)
        ..writeAsStringSync('x');
    }
    await Future<void>.delayed(_settle);

    for (final folder in ['build', '.dart_tool']) {
      final node = nodeAt(folder);
      expect(node, isNotNull, reason: folder);
      expect(node!.isLoaded, isFalse);
      expect(node.children, isEmpty);
      expect(watcher.watchedPaths, isNot(contains(node.path)));
    }
    expect(updates, greaterThan(0));
  });

  test('reads and watches a new source folder', () async {
    Directory(p.join(root.path, 'lib', 'feature')).createSync();
    await Future<void>.delayed(_settle);
    File(p.join(root.path, 'lib', 'feature', 'a.dart')).writeAsStringSync('');
    await Future<void>.delayed(_settle);

    expect(nodeAt('lib/feature')!.isLoaded, isTrue);
    expect(watcher.watchedPaths, contains(p.join(root.path, 'lib', 'feature')));
    expect(nodeAt('lib/feature/a.dart'), isNotNull);
  });

  test('a modified file leaves the tree as it is', () async {
    File(p.join(root.path, 'lib', 'main.dart')).writeAsStringSync('edited\n');
    await Future<void>.delayed(_settle);

    expect(updates, 0);
    expect(nodeAt('lib')!.children, hasLength(1));
  });

  test('a deleted file updates the tree once', () async {
    File(p.join(root.path, 'lib', 'main.dart')).deleteSync();
    await Future<void>.delayed(_settle);

    expect(updates, 1);
    expect(nodeAt('lib/main.dart'), isNull);
  });
}
