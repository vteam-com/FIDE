import 'package:fide/models/project_node.dart';
import 'package:fide/panels/left/shared_panel_utils.dart';
import 'package:fide/widget_services/file_action.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final file = ProjectNode(
    name: 'a.dart',
    path: '/p/a.dart',
    type: ProjectNodeType.file,
  );
  final dir = ProjectNode(
    name: 'lib',
    path: '/p/lib',
    type: ProjectNodeType.directory,
  );

  test('creation actions are offered only on directories', () {
    expect(NodeAction.values.where((a) => a.appliesTo(dir)), NodeAction.values);
    expect(NodeAction.values.where((a) => !a.appliesTo(file)), [
      NodeAction.newFile,
      NodeAction.newFolder,
    ]);
  });

  test('only delete is destructive', () {
    expect(NodeAction.values.where((a) => a.isDestructive), [
      NodeAction.delete,
    ]);
  });

  test('files open; only project entries have a relative path', () {
    bool applies(FileAction action, String path, {bool isDirectory = false}) =>
        action.appliesTo(path, isDirectory: isDirectory, projectPath: '/p');

    expect(applies(FileAction.open, file.path), true);
    expect(applies(FileAction.open, dir.path, isDirectory: true), false);
    expect(
      applies(FileAction.revealInFileManager, dir.path, isDirectory: true),
      true,
    );
    expect(applies(FileAction.copyRelativePath, file.path), true);
    expect(applies(FileAction.copyRelativePath, '/elsewhere/a.dart'), false);
  });

  test('the project trees offer every file action but revealing in them', () {
    expect(FileAction.values.where((a) => !a.inProjectTrees), [
      FileAction.revealInExplorer,
    ]);
  });
}
