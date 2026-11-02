import 'dart:io';

import 'package:fide/models/project_node.dart';
import 'package:fide/services/project_tree_reader.dart';
import 'package:flutter_test/flutter_test.dart';

// Flattens a tree into indented names so trees can be compared directly
List<String> _outline(ProjectNode node, [String indent = '']) => [
  for (final child in node.children) ...[
    '$indent${child.name}${child.isDirectory ? '/' : ''}',
    ..._outline(child, '$indent  '),
  ],
];

const reader = ProjectTreeReader();

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('fide_tree_');
    for (final dir in ['lib/src', 'Assets', '.github']) {
      Directory('${root.path}/$dir').createSync(recursive: true);
    }
    for (final file in ['b.txt', 'A.md', '.env', 'lib/main.dart']) {
      File('${root.path}/$file').writeAsStringSync('');
    }
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('lists directories first, then files, case-insensitively', () async {
    final node = await reader.nodeFor(root);
    await reader.loadTree(node);

    expect(_outline(node), [
      '.github/',
      'Assets/',
      'lib/',
      '  src/',
      '  main.dart',
      '.env',
      'A.md',
      'b.txt',
    ]);
    expect(node.loadResult, LoadChildrenResult.success);
  });

  test('sync and async enumeration build the same tree', () async {
    final asyncNode = await reader.nodeFor(root);
    await reader.loadTree(asyncNode);
    final syncNode = reader.nodeForSync(root);
    reader.loadTreeSync(syncNode);

    expect(_outline(syncNode), _outline(asyncNode));
  });

  test('leaves skipped folders unread until expanded', () async {
    Directory('${root.path}/build/app').createSync(recursive: true);
    final node = await reader.nodeFor(root);
    await reader.loadTree(node);
    final syncNode = reader.nodeForSync(root);
    reader.loadTreeSync(syncNode);

    for (final loaded in [node, syncNode]) {
      final build = loaded.findNode('${root.path}/build')!;
      expect(build.isLoaded, isFalse);
      expect(build.children, isEmpty);
      expect(loaded.findNode('${root.path}/lib')!.isLoaded, isTrue);
      await reader.loadChildren(build);
      expect(_outline(build), ['app/']);
    }
  });

  test('reports a file system error for a vanished directory', () async {
    final node = ProjectNode(
      name: 'gone',
      path: '${root.path}/gone',
      type: ProjectNodeType.directory,
    );

    expect(await reader.loadChildren(node), LoadChildrenResult.fileSystemError);
    reader.loadTreeSync(node);
    expect(node.loadResult, LoadChildrenResult.fileSystemError);
  });

  test('records each entry\'s date, and its size when a file', () async {
    const content = 'hello';
    File('${root.path}/b.txt').writeAsStringSync(content);
    final node = await reader.nodeFor(root);
    await reader.loadChildren(node);
    final syncNode = reader.nodeForSync(root);
    reader.loadTreeSync(syncNode);

    for (final loaded in [node, syncNode]) {
      final file = loaded.findNode('${root.path}/b.txt')!;
      final folder = loaded.findNode('${root.path}/lib')!;
      expect(file.size, content.length);
      expect(file.modified, isNotNull);
      expect(folder.size, isNull);
      expect(folder.modified, isNotNull);
    }
  });
}
