import 'package:fide/models/project_files.dart';
import 'package:fide/models/project_node.dart';
import 'package:fide/models/quick_open_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

const root = '/p';

const limit = 10;

List<String> rank(List<String> paths, String query) =>
    QuickOpenMatcher.rank(paths, query, rootPath: root, limit: limit);

ProjectNode file(String path) => ProjectNode(
  name: path.split('/').last,
  path: path,
  type: ProjectNodeType.file,
);

ProjectNode folder(String path, List<ProjectNode> children) => ProjectNode(
  name: path.split('/').last,
  path: path,
  type: ProjectNodeType.directory,
  children: children,
);

void main() {
  group('QuickOpenMatcher', () {
    test('needs every letter in order', () {
      expect(QuickOpenMatcher.score('lib/main.dart', 'mnd'), isNotNull);
      expect(QuickOpenMatcher.score('lib/main.dart', 'dnm'), isNull);
    });

    test('ignores case and spaces', () {
      expect(
        QuickOpenMatcher.score('lib/MainLayout.dart', 'main l'),
        isNotNull,
      );
    });

    test('matches across folders', () {
      expect(
        QuickOpenMatcher.score('lib/widgets/tree_row.dart', 'wtr'),
        isNotNull,
      );
    });

    test('ranks a file-name prefix above a scattered match', () {
      final paths = ['/p/lib/my_awesome_info.dart', '/p/lib/main.dart'];
      expect(rank(paths, 'main').first, '/p/lib/main.dart');
    });

    test('ranks word starts above inner letters', () {
      final paths = ['/p/lib/fortress.dart', '/p/lib/tree_row.dart'];
      expect(rank(paths, 'tr').first, '/p/lib/tree_row.dart');
    });

    test('breaks ties with the shorter path', () {
      final paths = ['/p/lib/deep/main.dart', '/p/main.dart'];
      expect(rank(paths, 'main.dart'), [
        '/p/main.dart',
        '/p/lib/deep/main.dart',
      ]);
    });

    test('keeps the given order for an empty query, up to the limit', () {
      final paths = [for (var i = 0; i < limit + 1; i++) '/p/f$i.dart'];
      expect(rank(paths, ' '), paths.take(limit));
    });

    test('leaves out files that do not match', () {
      expect(rank(['/p/a.dart', '/p/b.dart'], 'b'), ['/p/b.dart']);
    });
  });

  group('ProjectFiles', () {
    test('lists files, skipping build output and hidden entries', () {
      final tree = folder('/p', [
        folder('/p/.git', [file('/p/.git/HEAD')]),
        folder('/p/build', [file('/p/build/app')]),
        folder('/p/lib', [file('/p/lib/main.dart')]),
        file('/p/.env'),
        file('/p/pubspec.yaml'),
      ]);
      expect(ProjectFiles.under(tree), ['/p/lib/main.dart', '/p/pubspec.yaml']);
    });

    test('skips paths inside skipped folders', () {
      expect(ProjectFiles.isSkippedPath('.dart_tool/x.json'), isTrue);
      expect(ProjectFiles.isSkippedPath('lib/build_helper.dart'), isFalse);
    });
  });
}
