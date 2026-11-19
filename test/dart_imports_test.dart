import 'package:fide/models/dart_imports.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('packageUriOf names a lib file with slashes on every platform', () {
    expect(
      packageUriOf('demo', p.join('l10n', 'app_localizations.dart')),
      'package:demo/l10n/app_localizations.dart',
    );
    expect(packageUriOf('demo', 'main.dart'), 'package:demo/main.dart');
  });

  test('relativeUriOf is the URI a file imports another with', () {
    final from = p.join('p', 'lib', 'a', 'b.dart');
    expect(
      relativeUriOf(p.join('p', 'lib', 'c', 'd.dart'), from: from),
      '../c/d.dart',
    );
    expect(
      relativeUriOf(p.join('p', 'lib', 'a', 'e.dart'), from: from),
      'e.dart',
    );
  });

  test('withImport adds an import once, in package order', () {
    const content = "import 'package:a/a.dart';\nimport 'package:c/c.dart';\n";
    final added = withImport(
      content,
      'package:b/b.dart',
      isImported: (uri) => uri == 'package:b/b.dart',
    );

    expect(
      added,
      "import 'package:a/a.dart';\nimport 'package:b/b.dart';\n"
      "import 'package:c/c.dart';\n",
    );
    expect(
      withImport(
        added,
        'package:b/b.dart',
        isImported: (uri) => uri == 'package:b/b.dart',
      ),
      added,
    );
  });

  test('withImport keeps dart, package, then relative imports in order', () {
    const content = "import 'dart:io';\n\nimport 'a.dart';\n\nclass A {}\n";

    expect(
      withImport(content, 'package:b/b.dart', isImported: (_) => false),
      "import 'dart:io';\n\nimport 'package:b/b.dart';\nimport 'a.dart';\n"
      '\nclass A {}\n',
    );
  });

  test('withDirective adds a part after the other directives', () {
    const content = "import 'dart:io';\n\nclass A {}\n";

    expect(
      withDirective(content, "part 'a.b.dart';"),
      "import 'dart:io';\npart 'a.b.dart';\n\nclass A {}\n",
    );
  });

  test('compareDirectiveLines sorts dart, package, then relative URIs', () {
    final lines = [
      "import 'b.dart';",
      "import 'package:a/a.dart';",
      "import 'dart:io';",
    ]..sort(compareDirectiveLines);

    expect(lines, [
      "import 'dart:io';",
      "import 'package:a/a.dart';",
      "import 'b.dart';",
    ]);
  });
}
