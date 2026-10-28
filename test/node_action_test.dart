import 'package:fide/models/project_node.dart';
import 'package:fide/panels/left/shared_panel_utils.dart';
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

  test('reveal is in the menu and only delete is destructive', () {
    expect(NodeAction.reveal.appliesTo(file), true);
    expect(NodeAction.values.where((a) => a.isDestructive), [
      NodeAction.delete,
    ]);
  });
}
