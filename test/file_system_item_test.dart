import 'package:fide/models/file_system_item.dart';
import 'package:fide/models/project_node.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromNode copies the node\'s type, date, size and Git status', () {
    final modified = DateTime(2026, 1, 2);
    final node = ProjectNode(
      name: 'main.dart',
      path: '/p/lib/main.dart',
      type: ProjectNodeType.file,
      modified: modified,
      size: 42,
      gitStatus: GitFileStatus.modified,
    );

    final item = FileSystemItem.fromNode(node, warning: 'careful');

    expect(item.name, 'main.dart');
    expect(item.path, '/p/lib/main.dart');
    expect(item.isDirectory, false);
    expect(item.modified, modified);
    expect(item.size, 42);
    expect(item.gitStatus, GitFileStatus.modified);
    expect(item.warning, 'careful');
  });

  test('fromNode keeps a directory a directory', () {
    final node = ProjectNode(
      name: 'lib',
      path: '/p/lib',
      type: ProjectNodeType.directory,
    );

    expect(FileSystemItem.fromNode(node).isDirectory, true);
  });

  test('fromPath builds a file or folder without reading the disk', () {
    final file = FileSystemItem.fromPath(
      '/p/new.txt',
      gitStatus: GitFileStatus.untracked,
    );
    expect(file.name, 'new.txt');
    expect(file.isDirectory, false);
    expect(file.size, isNull);
    expect(file.gitStatus, GitFileStatus.untracked);

    expect(
      FileSystemItem.fromPath('/p/gen/', isDirectory: true).isDirectory,
      true,
    );
  });
}
