import 'package:fide/models/repeated_settings_review.dart';
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
    final fix = RepeatedSettingsFix('Use AppIconSize.large', [
      RepeatedSettingsEdit(
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
    final fix = RepeatedSettingsFix.all('Fix All', [
      RepeatedSettingsFix('Use Big', [
        RepeatedSettingsEdit(_path, call, callSource, 'Big()'),
      ]),
      RepeatedSettingsFix('Use large', [
        RepeatedSettingsEdit(_path, _numberAt, '32', 'large'),
      ]),
    ]);

    final fixed = fix.applyTo({_path: _code});

    expect(fixed.count, 1);
    expect(fixed.contents[_path], contains('final a = Big();'));
  });

  test('a file changed since the review is left alone', () {
    final fix = RepeatedSettingsFix('Use large', [
      RepeatedSettingsEdit(_path, _numberAt, '32', 'large'),
    ]);

    expect(
      () => fix.applyTo({_path: _code.replaceFirst('32', '48')}),
      throwsStateError,
    );
  });

  test('nameError accepts only a free class name', () {
    expect(RepeatedSettingsFix.nameError('LogoBox', {'Other'}), isNull);
    expect(
      RepeatedSettingsFix.nameError('logoBox', {}),
      'logoBox is not a class name',
    );
    expect(
      RepeatedSettingsFix.nameError('LogoBox', {'LogoBox'}),
      'LogoBox is taken: pick another name',
    );
  });
}
