import 'package:fide/models/project_node.dart';
import 'package:fide/panels/left/tree_filter.dart';
import 'package:flutter_test/flutter_test.dart';

/// A filter counting the names it tests.
class _CountingFilter extends TreeFilter {
  _CountingFilter() : super(onChanged: () {});

  int tests = 0;

  @override
  bool matches(ProjectNode node) {
    tests++;
    return super.matches(node);
  }
}

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
    final kept = filter.keptPaths(root);
    expect(
      [
        for (final node in root.children)
          if (kept.contains(node.path)) node.name,
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

  test('a query tests each name once, however deep the tree', () {
    // A chain of folders, each holding one file, the match at the bottom
    const depth = 200;
    var node = _folder('/p/d$depth', [_file('/p/d$depth/needle.dart')]);
    for (var level = depth - 1; level >= 0; level--) {
      node = _folder('/p/d$level', [node, _file('/p/d$level/f.dart')]);
    }
    final deep = _CountingFilter();
    addTearDown(deep.dispose);
    deep.controller.text = 'needle';
    deep.tests = 0;

    final kept = deep.keptPaths(node);
    final folders = deep.foldersToExpand(node).toList();

    // depth + 1 folders, each holding one file; one test per node in each
    // of the two calls, where walking the subtree again at each level
    // would test about nodeCount * depth / 2 names
    const nodeCount = (depth + 1) * 2;
    const calls = 2;
    expect(deep.tests, nodeCount * calls);
    expect(folders, hasLength(depth + 1));
    expect(kept, hasLength(depth + 2));
    expect(kept, isNot(contains('/p/d0/f.dart')));
  });
}
