import 'package:fide/models/commit_digest.dart';
import 'package:flutter_test/flutter_test.dart';

/// A change adding a documented class and test, a README line, and a
/// file renamed, as `git diff --stat` then `git diff` print it.
const String _changes = '''
 README.md                     |  2 ++
 lib/services/file_mover.dart  | 12 ++++++++++++
 test/file_mover_test.dart     |  6 ++++++
 3 files changed, 20 insertions(+)
diff --git a/README.md b/README.md
--- a/README.md
+++ b/README.md
@@ -1,1 +1,3 @@
 # FIDE
+
+- **Move** moves a file and points every import at it
diff --git a/lib/services/file_mover.dart b/lib/services/file_mover.dart
new file mode 100644
--- /dev/null
+++ b/lib/services/file_mover.dart
@@ -0,0 +1,12 @@
+import 'package:path/path.dart' as p;
+
+/// Moves Dart files within a project. Planning writes nothing.
+class FileMover {
+  /// Creates a mover.
+  const FileMover();
+
+  /// The files to write to make [moves], by path.
+  Map<String, String> plan(Map<String, String> moves) => {};
+
+  static int _count = 0;
+}
diff --git a/test/file_mover_test.dart b/test/file_mover_test.dart
new file mode 100644
--- /dev/null
+++ b/test/file_mover_test.dart
@@ -0,0 +1,6 @@
+void main() {
+  test('a package import of the moved file points at '
+      'its new place', () {});
+  testWidgets('Move moves the file', (tester) async {});
+}
''';

void main() {
  /// The digest of [_changes] within [maxChars].
  String digest({int maxChars = 4000}) =>
      CommitDigest(_changes, maxChars: maxChars).text;

  test('lists the files changed, without the bar graph', () {
    expect(
      digest(),
      contains(
        'Files changed:\n'
        ' README.md                     |  2\n'
        ' lib/services/file_mover.dart  | 12\n',
      ),
    );
  });

  test('quotes the documentation added', () {
    expect(
      digest(),
      contains(
        'Documentation added:\n'
        '- **Move** moves a file and points every import at it\n',
      ),
    );
  });

  test('names each documented declaration added with its first sentence, '
      'leaving out constructors and private members', () {
    expect(
      digest(),
      contains(
        'Declarations added, with the first sentence of their '
        'documentation:\n'
        'lib/services/file_mover.dart\n'
        '- FileMover: Moves Dart files within a project.\n'
        '- plan: The files to write to make moves, by path.\n\n',
      ),
    );
  });

  test('names the tests added, a name written on two lines joined', () {
    expect(
      digest(),
      contains(
        'Tests added:\n'
        '- a package import of the moved file points at its new place\n'
        '- Move moves the file\n',
      ),
    );
  });

  test('shows the code changed, leaving out directives and comments', () {
    final changes = digest().split('Changes:\n').last;

    expect(changes, startsWith('lib/services/file_mover.dart\n'));
    expect(changes, contains('+class FileMover {'));
    expect(changes, isNot(contains('import ')));
    expect(changes, isNot(contains('///')));
  });

  test('stays within its budget', () {
    const maxChars = 300;

    expect(digest(maxChars: maxChars).length, lessThanOrEqualTo(maxChars + 1));
  });

  test('a text with no diff is read as the list of files', () {
    expect(CommitDigest('diff', maxChars: 100).text, 'Files changed:\ndiff');
  });

  test('an edited documentation line gives way to the lines added anew', () {
    const changes =
        'diff --git a/README.md b/README.md\n'
        '@@ -1,2 +1,3 @@\n'
        '-today the Color contrast check\n'
        '+today the File Layout and the Color contrast check\n'
        ' \n'
        '+- **Move** moves a file\n';

    expect(
      CommitDigest(changes, maxChars: 1000).text,
      'Documentation added:\n- **Move** moves a file',
    );
  });
}
