import 'dart:io';

import 'package:fide/models/flutter_platform.dart';
import 'package:fide/providers/build_artifacts_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory project;

  setUp(() => project = Directory.systemTemp.createTempSync('fide_build_'));
  tearDown(() => project.deleteSync(recursive: true));

  test('reports an unbuilt project without an icon', () async {
    final artifacts = await const BuildArtifactsInspector().inspect(
      project.path,
      FlutterPlatform.linux,
    );

    expect(artifacts.appIconPath, isNull);
    expect(artifacts.size, 'Not built');
    expect(artifacts.lastBuildTime, 'Never');
  });

  test('finds the platform output, its size and the app icon', () async {
    File('${project.path}/build/web/main.dart.js')
      ..createSync(recursive: true)
      ..writeAsBytesSync(List.filled(2048, 0));
    File('${project.path}/web/favicon.png').createSync(recursive: true);

    final artifacts = await const BuildArtifactsInspector().inspect(
      project.path,
      FlutterPlatform.web,
    );

    expect(artifacts.location, '${project.path}/build/web');
    expect(artifacts.size, '2.0 KB');
    expect(artifacts.appIconPath, '${project.path}/web/favicon.png');
    expect(artifacts.lastBuildTime, isNot(anyOf('Never', 'Unknown')));
  });

  test('picks the sharpest platform icon for the whole project', () async {
    const inspector = BuildArtifactsInspector();
    expect(await inspector.projectIconPath(project.path), isNull);

    File('${project.path}/web/favicon.png').createSync(recursive: true);
    final macIcon = File(
      '${project.path}/macos/Runner/Assets.xcassets/AppIcon.appiconset/'
      'app_icon_512.png',
    )..createSync(recursive: true);

    expect(await inspector.projectIconPath(project.path), macIcon.path);
  });
}
