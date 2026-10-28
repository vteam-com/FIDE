import 'dart:io';

import 'package:fide/models/project_node.dart';
import 'package:flutter_test/flutter_test.dart';

// Flattens a tree into indented names so trees can be compared directly
List<String> _outline(ProjectNode node, [String indent = '']) => [
  for (final child in node.children) ...[
    '$indent${child.name}${child.isDirectory ? '/' : ''}',
    ..._outline(child, '$indent  '),
  ],
];

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
    final node = await ProjectNode.fromFileSystemEntity(root);
    await node.enumerateContentsRecursive();

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
    final asyncNode = await ProjectNode.fromFileSystemEntity(root);
    await asyncNode.enumerateContentsRecursive();
    final syncNode = ProjectNode.fromFileSystemEntitySync(root)
      ..enumerateContentsRecursiveSync();

    expect(_outline(syncNode), _outline(asyncNode));
  });

  test('reports a file system error for a vanished directory', () async {
    final node = ProjectNode(
      name: 'gone',
      path: '${root.path}/gone',
      type: ProjectNodeType.directory,
    );

    expect(await node.enumerateContents(), LoadChildrenResult.fileSystemError);
    node.enumerateContentsRecursiveSync();
    expect(node.loadResult, LoadChildrenResult.fileSystemError);
  });
}
