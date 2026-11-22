import 'package:fide/models/dart_type_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('splits a type into its prefix, name and type arguments', () {
    final type = DartTypeText.parse('p.Box<int, Map<String, List<int>>>?');
    expect(type.prefix, 'p');
    expect(type.name, 'Box');
    expect(type.arguments, ['int', 'Map<String, List<int>>']);
    expect(type.isNullable, isTrue);
    expect(type.isFunction, isFalse);
  });

  test('reads a function type: its return type and parameter count', () {
    final type = DartTypeText.parse(
      'Future<void> Function(String id, {required int index, bool? last})?',
    );
    expect(type.isFunction, isTrue);
    expect(type.isNullable, isTrue);
    expect(type.returnType, 'Future<void>');
    expect(type.parameterCount, 3);
    expect(DartTypeText.parse('Function()').returnType, isEmpty);
    expect(DartTypeText.parse('void Function(int a,)').parameterCount, 1);
  });

  test('a list of callbacks is a list, not a function type', () {
    final type = DartTypeText.parse('List<void Function(int)>');
    expect(type.isFunction, isFalse);
    expect(type.name, 'List');
    expect(type.arguments, ['void Function(int)']);
  });

  test('keeps a record type whole', () {
    final type = DartTypeText.parse('(int, String)');
    expect(type.name, '(int, String)');
    expect(type.arguments, isEmpty);
  });
}
