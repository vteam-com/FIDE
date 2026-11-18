import 'package:fide/models/app_release.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pub_semver/pub_semver.dart';

/// GitHub's description of release [tag], holding the builds [assets].
Map<String, Object?> _release(String tag, List<String> assets) => {
  'tag_name': tag,
  'assets': [
    for (final name in assets)
      {
        'name': name,
        'browser_download_url':
            'https://github.com/o/r/releases/download/$tag/$name',
      },
  ],
};

void main() {
  test('reads the version and the named build', () {
    final release = AppRelease.fromGitHub(
      _release('v1.2.3', ['FIDE-linux.tar.gz', 'FIDE-macos.zip']),
      'FIDE-macos.zip',
    );

    expect(release?.version, Version(1, 2, 3));
    expect(
      release?.downloadUrl,
      Uri.parse(
        'https://github.com/o/r/releases/download/v1.2.3/FIDE-macos.zip',
      ),
    );
  });

  test('no release without the named build', () {
    expect(
      AppRelease.fromGitHub(
        _release('v1.2.3', ['FIDE-linux.tar.gz']),
        'FIDE-macos.zip',
      ),
      isNull,
    );
  });

  test('no release without a version tag', () {
    for (final tag in ['1.2.3', 'vNext', 'nightly']) {
      expect(
        AppRelease.fromGitHub(
          _release(tag, ['FIDE-macos.zip']),
          'FIDE-macos.zip',
        ),
        isNull,
        reason: tag,
      );
    }
  });

  test('no release from an unexpected answer', () {
    expect(AppRelease.fromGitHub(null, 'FIDE-macos.zip'), isNull);
    expect(AppRelease.fromGitHub('Not Found', 'FIDE-macos.zip'), isNull);
    expect(
      AppRelease.fromGitHub({'message': 'Not Found'}, 'FIDE-macos.zip'),
      isNull,
    );
  });
}
