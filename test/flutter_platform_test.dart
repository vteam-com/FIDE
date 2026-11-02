import 'dart:io';

import 'package:fide/models/flutter_platform.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromId round-trips every platform and rejects unknown ids', () {
    for (final platform in FlutterPlatform.values) {
      expect(FlutterPlatform.fromId(platform.name), platform);
    }
    expect(FlutterPlatform.fromId('fuchsia'), isNull);
  });

  test('every platform has a bundled icon', () {
    for (final platform in FlutterPlatform.values) {
      expect(
        File(platform.iconAsset).existsSync(),
        true,
        reason: platform.name,
      );
    }
  });

  test('iOS and macOS build only on a Mac, the others where they run', () {
    expect(FlutterPlatform.ios.canBuildOn(FlutterPlatform.macos), isTrue);
    expect(FlutterPlatform.ios.canBuildOn(FlutterPlatform.linux), isFalse);
    expect(FlutterPlatform.linux.canBuildOn(FlutterPlatform.linux), isTrue);
    expect(FlutterPlatform.windows.canBuildOn(FlutterPlatform.macos), isFalse);
    expect(FlutterPlatform.web.canBuildOn(null), isTrue);
    expect(FlutterPlatform.android.canBuildOn(FlutterPlatform.windows), isTrue);
  });

  test('web runs on Chrome and CocoaPods covers only Apple platforms', () {
    expect(FlutterPlatform.web.deviceTarget, 'chrome');
    expect(FlutterPlatform.values.where((platform) => platform.usesCocoaPods), [
      FlutterPlatform.ios,
      FlutterPlatform.macos,
    ]);
  });

  test('enable instructions name the platform folder to create', () {
    for (final platform in FlutterPlatform.values) {
      expect(
        platform.enableInstructions,
        contains('--platforms=${platform.name}'),
      );
    }
  });

  test('iOS builds need a Mac', () {
    expect(FlutterPlatform.ios.cannotBuildOn('linux'), contains('macOS'));
  });

  test('build arguments carry each platform target and its extra flags', () {
    expect(FlutterPlatform.android.buildArguments(), ['build', 'apk']);
    expect(
      FlutterPlatform.android.buildArguments(FlutterPlatform.appBundleTarget),
      ['build', 'appbundle'],
    );
    expect(FlutterPlatform.web.buildArguments(), [
      'build',
      'web',
      '--no-wasm-dry-run',
    ]);
    expect(FlutterPlatform.macos.buildArguments(), ['build', 'macos']);
  });
}
