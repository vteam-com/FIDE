import 'dart:io';

import 'package:fide/models/flutter_platform.dart';
import 'package:fide/providers/build_artifacts_inspector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Writes a [size]-pixel PNG at [path], creating its folder.
File writePng(String path, int size) => File(path)
  ..createSync(recursive: true)
  ..writeAsBytesSync(img.encodePng(img.Image(width: size, height: size)));

/// Writes the web page linking `favicon.png` and the favicon, [size] pixels.
void writeWebFavicon(String projectPath, int size) {
  File('$projectPath/web/index.html')
    ..createSync(recursive: true)
    ..writeAsStringSync('<link rel="icon" href="favicon.png"/>');
  writePng('$projectPath/web/favicon.png', size);
}

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
    writeWebFavicon(project.path, 16);

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

    writeWebFavicon(project.path, 16);
    const set = 'macos/Runner/Assets.xcassets/AppIcon.appiconset';
    File('${project.path}/$set/Contents.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        '{"images": ['
        '{"size": "16x16", "scale": "1x", "filename": "small.png"},'
        '{"size": "512x512", "scale": "1x", "filename": "brand.png"}]}',
      );
    writePng('${project.path}/$set/small.png', 16);
    final macIcon = writePng('${project.path}/$set/brand.png', 512);

    // The file Contents.json names, not a template file name
    expect(await inspector.projectIconPath(project.path), macIcon.path);
  });
}
