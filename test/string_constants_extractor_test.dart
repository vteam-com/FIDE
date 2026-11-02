import 'dart:io';

import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/models/constants_plan.dart';
import 'package:fide/models/hardcoded_string.dart';
import 'package:fide/services/code_formatter.dart';
import 'package:fide/services/process_runner.dart';
import 'package:fide/services/project_config_reader.dart';
import 'package:fide/services/string_constants_extractor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('fide_constants_'));
  tearDown(() => root.deleteSync(recursive: true));

  /// The string [literal] in the file [path] holding [content].
  HardcodedString stringIn(String path, String content, String literal) =>
      HardcodedString(
        path: path,
        line: 1,
        site: fcheck.HardcodedStringSite(
          offset: content.indexOf(literal),
          length: literal.length,
          textParts: [literal.substring(1, literal.length - 1)],
          interpolations: const [],
          isWidgetOutput: false,
          calleeName: 'collection',
        ),
      );

  test('declares one constant per value, reusing existing ones', () async {
    const service = '''
final users = db.collection('users').orderBy('name');
final venues = db.collection('venues').orderBy('name');
''';
    final servicePath = p.join(root.path, 'lib', 'service.dart');
    final constantsPath = p.join(
      root.path,
      'lib',
      'constants',
      'data_keys.dart',
    );
    File(servicePath)
      ..createSync(recursive: true)
      ..writeAsStringSync(service);
    File(constantsPath)
      ..createSync(recursive: true)
      ..writeAsStringSync('''
class DataKeys {
  DataKeys._();

  static const String users = 'users';
}
''');
    final strings = [
      for (final literal in ["'users'", "'venues'"])
        stringIn(servicePath, service, literal),
      for (final match in RegExp("'name'").allMatches(service))
        HardcodedString(
          path: servicePath,
          line: 1,
          site: fcheck.HardcodedStringSite(
            offset: match.start,
            length: match.end - match.start,
            textParts: const ['name'],
            interpolations: const [],
            isWidgetOutput: false,
            calleeName: 'orderBy',
          ),
        ),
    ];
    final plan = ConstantsPlan(
      className: 'DataKeys',
      constantsPath: constantsPath,
      importUri: 'package:app/constants/data_keys.dart',
      candidates: strings,
      skipped: const {},
    );

    final result = await const StringConstantsExtractor(
      CodeFormatter(ProcessRunner()),
      ProjectConfigReader(),
    ).apply(plan, strings);

    expect(result.rewritten, 4);
    expect(File(servicePath).readAsStringSync(), '''
import 'package:app/constants/data_keys.dart';

final users = db.collection(DataKeys.users).orderBy(DataKeys.name);
final venues = db.collection(DataKeys.venues).orderBy(DataKeys.name);
''');
    final constants = File(constantsPath).readAsStringSync();
    expect(RegExp('static const String').allMatches(constants), hasLength(3));
    expect(
      constants.indexOf("name = 'name'"),
      lessThan(constants.indexOf("venues = 'venues'")),
    );
  });
}
