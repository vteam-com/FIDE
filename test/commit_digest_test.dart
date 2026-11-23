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
    expect(changes, isNot(contains('+import ')));
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

  group('code moved', () {
    /// A State moved from its part file into its widget's, made private,
    /// a helper moved out of it, and a test reaching into it removed.
    const changes = '''
 lib/a.dart       | 12 ++++++++++
 lib/a_state.dart | 10 ----------
 2 files changed
diff --git a/lib/a.dart b/lib/a.dart
--- a/lib/a.dart
+++ b/lib/a.dart
@@ -1,5 +1,14 @@
-part 'a_state.dart';
-
 class A extends StatefulWidget {
-  AState createState() => AState();
+  State<A> createState() => _AState();
+}
+
+class _AState extends State<A> {
+  /// The corners dragged.
+  late List<Offset> corners;
+
+  void startDragging(Offset at) {
+    corners.add(at);
+    notify(corners);
+  }
 }
diff --git a/lib/a_state.dart b/lib/a_state.dart
deleted file mode 100644
--- a/lib/a_state.dart
+++ /dev/null
@@ -1,9 +0,0 @@
-part of 'a.dart';
-
-class AState extends State<A> {
-  /// The corners dragged.
-  late List<Offset> corners;
-
-  void startDragging(Offset at) {
-    corners.add(at);
-    notify(corners);
-  }
-}
diff --git a/test/a_test.dart b/test/a_test.dart
--- a/test/a_test.dart
+++ b/test/a_test.dart
@@ -1,6 +1,3 @@
 void main() {
-  test('the state starts with no corners', () {
-    expect(A().createState(), isNotNull);
-  });
   testWidgets('drags a corner', (tester) async {});
 }
''';

    final digest = CommitDigest(changes, maxChars: 4000).text;

    test('tells the lines moved to another file as moved, not added', () {
      expect(
        digest,
        contains(
          'Moved without change:\n'
          '- lib/a_state.dart (deleted) → lib/a.dart: 5 lines\n',
        ),
      );
      expect(digest, isNot(contains('+  void startDragging')));
    });

    test('tells a declaration renamed, saying when it is made private', () {
      expect(digest, contains('Renamed:\n- AState → _AState (made private)'));
      expect(digest, isNot(contains('+class _AState')));
    });

    test('names the tests removed', () {
      expect(
        digest,
        contains('Tests removed:\n- the state starts with no corners'),
      );
    });

    test('shows what is left changed', () {
      expect(
        digest.split('Changes:\n').last,
        'lib/a.dart\n'
        '-  AState createState() => AState();\n'
        '+  State<A> createState() => _AState();',
      );
    });
  });

  test('a line added back in its own run of changes, indented anew, is '
      'neither moved nor changed', () {
    const changes =
        'diff --git a/lib/a.dart b/lib/a.dart\n'
        '@@ -1,3 +1,5 @@\n'
        ' void run() {\n'
        '-  start(engine);\n'
        '-  stop(engine);\n'
        '-  report(engine);\n'
        '+  if (ready) {\n'
        '+    start(engine);\n'
        '+    stop(engine);\n'
        '+    report(engine);\n'
        '+  }\n'
        ' }\n';

    final digest = CommitDigest(changes, maxChars: 1000).text;

    expect(digest, isNot(contains('Moved')));
    expect(digest, 'Changes:\nlib/a.dart\n+  if (ready) {\n+  }');
  });

  test('a few lines alike in two files are changes, not a move', () {
    const changes =
        'diff --git a/lib/a.dart b/lib/a.dart\n'
        '@@ -1,2 +1,1 @@\n'
        '-  @override\n'
        '-  void a() {}\n'
        'diff --git a/lib/b.dart b/lib/b.dart\n'
        '@@ -1,1 +1,2 @@\n'
        '+  @override\n'
        '+  void b() {}\n';

    final digest = CommitDigest(changes, maxChars: 1000).text;

    expect(digest, isNot(contains('Moved')));
    expect(digest, contains('+  @override'));
  });

  test('names the documented declarations moved, with the types they '
      'leave and join', () {
    const changes =
        'diff --git a/lib/s.dart b/lib/s.dart\n'
        '@@ -10,9 +10,3 @@ class _SState extends State<S> {\n'
        '   int count = 0;\n'
        '-  /// Formats [bytes] for people.\n'
        '-  String formatBytes(int bytes) {\n'
        '-    final kilobytes = bytes / unit;\n'
        '-    return label(kilobytes);\n'
        '-  }\n'
        '-\n'
        '   void sync() {}\n'
        '@@ -40,2 +34,8 @@ class _SState extends State<S> {\n'
        '   }\n'
        ' }\n'
        '+\n'
        '+/// Formats [bytes] for people.\n'
        '+String formatBytes(int bytes) {\n'
        '+  final kilobytes = bytes / unit;\n'
        '+  return label(kilobytes);\n'
        '+}\n';

    expect(
      CommitDigest(changes, maxChars: 4000).text,
      'Moved without change:\n'
      '- lib/s.dart, within the file: 4 lines, formatBytes from _SState to '
      'the top level',
    );
  });
}
