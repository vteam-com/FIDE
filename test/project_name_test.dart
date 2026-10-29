import 'package:fide/models/project_name.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('empty input has no name', () {
    expect(ProjectName.normalize(''), isNull);
  });

  test('uppercase and camelCase become snake_case', () {
    expect(ProjectName.normalize('MyApp'), 'my_app');
    expect(ProjectName.normalize('helloWorld'), 'hello_world');
    expect(ProjectName.normalize('HELLO'), 'hello');
  });

  test('spaces and punctuation collapse to single underscores', () {
    expect(ProjectName.normalize('  my -- app! '), 'my_app');
  });

  test('a leading digit gets a prefix', () {
    expect(ProjectName.normalize('2048'), 'app_2048');
  });

  test('a reserved word gets a suffix', () {
    expect(ProjectName.normalize('class'), 'class_app');
  });

  test('nothing valid left falls back', () {
    expect(ProjectName.normalize('!!!'), ProjectName.fallback);
  });
}
