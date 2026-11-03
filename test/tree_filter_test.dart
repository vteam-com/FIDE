import 'package:fide/models/project_node.dart';
import 'package:fide/panels/left/tree_filter.dart';
import 'package:flutter_test/flutter_test.dart';

/// A folder node at [path] holding [children].
ProjectNode _folder(String path, List<ProjectNode> children) => ProjectNode(
  name: path.split('/').last,
  path: path,
  type: ProjectNodeType.directory,
  children: children,
);

/// A file node at [path].
ProjectNode _file(String path) => ProjectNode(
  name: path.split('/').last,
  path: path,
  type: ProjectNodeType.file,
);

void main() {
  late ProjectNode root;
  late int changes;
  late TreeFilter filter;

  setUp(() {
    root = _folder('/p', [
      _folder('/p/lib', [
        _file('/p/lib/main.dart'),
        _folder('/p/lib/widgets', [_file('/p/lib/widgets/button.dart')]),
      ]),
      _folder('/p/test', [_file('/p/test/main_test.dart')]),
      _file('/p/README.md'),
    ]);
    changes = 0;
    filter = TreeFilter(onChanged: () => changes++);
  });
  tearDown(() => filter.dispose());

  test('without a query everything matches and nothing expands', () {
    expect(filter.isActive, isFalse);
    expect(filter.matches(root.children.last), isTrue);
    expect(filter.foldersToExpand(root), isEmpty);
  });

  test('a query keeps the nodes matching by name, case apart', () {
    filter.controller.text = 'MAIN';

    expect(changes, 1);
    expect(filter.isActive, isTrue);
    expect(
      [
        for (final node in root.children)
          if (filter.hasMatchingDescendant(node)) node.name,
      ],
      ['lib', 'test'],
    );
    expect(filter.matches(root.children.first), isFalse);
  });

  test('the folders holding a match are the ones to expand', () {
    filter.controller.text = 'button';

    expect(filter.foldersToExpand(root), ['/p', '/p/lib', '/p/lib/widgets']);
  });

  test('clearing reports the change and stops filtering', () {
    filter.controller.text = 'x';
    filter.clear();

    expect(changes, 2);
    expect(filter.isActive, isFalse);
  });
}
