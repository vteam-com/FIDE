import 'package:fide/models/dart_package_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const json = '''
{
  "configVersion": 2,
  "packages": [
    {"name": "app", "rootUri": "../", "packageUri": "lib/"},
    {"name": "kit", "rootUri": "file:///cache/kit-1.0.0", "packageUri": "lib/"},
    {"name": "flutter", "rootUri": "file:///sdk/packages/flutter", "packageUri": "lib/"}
  ],
  "flutterRoot": "file:///sdk"
}
''';
  final config = DartPackageConfig.parse(
    json,
    configPath: '/work/app/.dart_tool/package_config.json',
  );

  test("maps a package's library URI to its file", () {
    expect(config.libFolders['app'], '/work/app/lib');
    expect(
      config.pathOf('package:kit/src/a.dart'),
      '/cache/kit-1.0.0/lib/src/a.dart',
    );
    expect(config.pathOf('package:missing/a.dart'), isNull);
    expect(
      config.uriOf('/work/app/lib/views/home.dart'),
      'package:app/views/home.dart',
    );
    expect(config.uriOf('/work/app/test/home_test.dart'), isNull);
  });

  test("tells the SDK's libraries, which it doesn't map", () {
    expect(config.isSdk('dart:async'), isTrue);
    expect(config.isSdk('package:flutter/material.dart'), isTrue);
    expect(config.isSdk('package:kit/kit.dart'), isFalse);
    expect(config.pathOf('package:flutter/material.dart'), isNull);
  });

  test('is empty for content that is no package config', () {
    final empty = DartPackageConfig.parse('[', configPath: '/a/b.json');
    expect(empty.libFolders, isEmpty);
    expect(empty.flutterRoot, isNull);
  });
}
