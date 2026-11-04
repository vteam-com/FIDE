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

  test('web runs on Chrome and only iOS and macOS are Apple platforms', () {
    expect(FlutterPlatform.web.deviceTarget, 'chrome');
    expect(FlutterPlatform.values.where((platform) => platform.isApple), [
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
    final reason = FlutterPlatform.ios.cannotBuildOn(FlutterPlatform.linux);
    expect(reason, contains('macOS'));
    expect(reason, contains('from Linux'));
    expect(FlutterPlatform.windows.cannotBuildOn(null), contains('Windows'));
  });

  test('Android builds an APK or an App Bundle, the others one package', () {
    final android = FlutterPlatform.android.buildActions;
    expect(android.map((action) => action.id), ['build_apk', 'build_aab']);
    expect(android.map((action) => action.target), [
      null,
      FlutterPlatform.appBundleTarget,
    ]);
    for (final platform in FlutterPlatform.values) {
      if (platform == FlutterPlatform.android) continue;
      final action = platform.buildActions.single;
      expect(action.id, 'build');
      expect(action.title, 'Build ${platform.displayName}');
      expect(action.target, isNull);
    }
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
