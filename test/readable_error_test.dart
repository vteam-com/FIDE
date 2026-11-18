import 'dart:io';

import 'package:fide/models/readable_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('describe drops the type names of exceptions and state errors', () {
    expect(ReadableError.describe(Exception('No file')), 'No file');
    expect(ReadableError.describe(StateError('Gone')), 'Gone');
    expect(
      ReadableError.describe(Exception('Bad state: not a field')),
      'not a field',
    );
    expect(ReadableError.describe(const FormatException('Bad')), 'Bad');
    expect(
      ReadableError.describe(const FileSystemException('Missing', '/a')),
      'Missing: /a',
    );
    expect(ReadableError.describe('plain'), 'plain');
  });

  test('describe keeps the message of network errors', () {
    expect(
      ReadableError.describe(
        const HttpException('api.github.com answered 500'),
      ),
      'api.github.com answered 500',
    );
    expect(
      ReadableError.describe(const SocketException('Failed host lookup')),
      'Failed host lookup',
    );
  });
}
