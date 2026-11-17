import 'package:fide/models/dry_review.dart';
import 'package:flutter_test/flutter_test.dart';

/// Where the edits below are made.
const String _path = 'lib/a.dart';

/// The code edited.
const String _code = '''
import 'package:a/b.dart';

final a = Icon(size: 32, color: red);
''';

/// Offset of the `32` in [_code].
final int _numberAt = _code.indexOf('32');

void main() {
  test('replaces each original and adds the imports needed', () {
    final fix = DryFix('Use AppIconSize.large', [
      DryEdit(
        _path,
        _numberAt,
        '32',
        'AppIconSize.large',
        importUri: 'package:a/sizes.dart',
      ),
    ]);

    final fixed = fix.applyTo({_path: _code});

    expect(fixed.count, 1);
    expect(fixed.contents[_path], '''
import 'package:a/b.dart';
import 'package:a/sizes.dart';

final a = Icon(size: AppIconSize.large, color: red);
''');
  });

  test('an edit inside one already made is left out', () {
    final call = _code.indexOf('Icon(');
    final callSource = _code.substring(call, _code.indexOf(';', call));
    final fix = DryFix.all('Fix all', [
      DryFix('Use Big', [DryEdit(_path, call, callSource, 'Big()')]),
      DryFix('Use large', [DryEdit(_path, _numberAt, '32', 'large')]),
    ]);

    final fixed = fix.applyTo({_path: _code});

    expect(fixed.count, 1);
    expect(fixed.contents[_path], contains('final a = Big();'));
  });

  test('a file changed since the review is left alone', () {
    final fix = DryFix('Use large', [DryEdit(_path, _numberAt, '32', 'large')]);

    expect(
      () => fix.applyTo({_path: _code.replaceFirst('32', '48')}),
      throwsStateError,
    );
  });
}
