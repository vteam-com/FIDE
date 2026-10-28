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

  test('configuredIn lists only platforms with a project folder', () {
    final project = Directory.systemTemp.createTempSync('fide_platforms_');
    addTearDown(() => project.deleteSync(recursive: true));
    Directory('${project.path}/android').createSync();
    Directory('${project.path}/web').createSync();

    expect(FlutterPlatform.configuredIn(project.path), {'android', 'web'});
  });

  test('web runs on Chrome and CocoaPods covers only Apple platforms', () {
    expect(FlutterPlatform.web.deviceTarget, 'chrome');
    expect(FlutterPlatform.values.where((platform) => platform.usesCocoaPods), [
      FlutterPlatform.ios,
      FlutterPlatform.macos,
    ]);
  });
}
