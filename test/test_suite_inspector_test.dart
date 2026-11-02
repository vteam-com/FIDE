import 'dart:io';

import 'package:fide/services/test_suite_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory project;

  setUp(() {
    project = Directory.systemTemp.createTempSync('fide_tests_');
  });

  tearDown(() => project.deleteSync(recursive: true));

  /// Writes [content] to [path] under the project.
  void write(String path, String content) => File('${project.path}/$path')
    ..createSync(recursive: true)
    ..writeAsStringSync(content);

  test('null without a test folder', () async {
    expect(await const TestSuiteInspector().inspect(project.path), isNull);
  });

  test('sorts tests into unit and widget tests', () async {
    write('test/model_test.dart', "test('adds', () {});");
    write('test/ui/button_test.dart', "testWidgets('taps', (t) async {});");
    write('test/helpers.dart', '// shared');
    Directory('${project.path}/integration_test').createSync();

    final suite = (await const TestSuiteInspector().inspect(project.path))!;

    expect(suite.unitTests, ['test/model_test.dart']);
    expect(suite.widgetTests, ['test/ui/button_test.dart']);
    expect(suite.otherFiles, ['test/helpers.dart']);
    expect(suite.hasIntegrationTests, isTrue);
    expect(suite.reportLines, contains('  ⚠️ test/helpers.dart'));
  });
}
