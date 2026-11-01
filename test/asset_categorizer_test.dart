import 'dart:io';

import 'package:fide/models/asset_kind.dart';
import 'package:fide/models/byte_size.dart';
import 'package:fide/models/project_node.dart';
import 'package:fide/providers/asset_categorizer.dart';
import 'package:fide/providers/project_tree_reader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('AssetKind.of', () {
    test('reads the extension', () {
      expect(AssetKind.of('assets/photo.JPG'), AssetKind.images);
      expect(AssetKind.of('assets/diagram.svg'), AssetKind.images);
      expect(AssetKind.of('fonts/Inter.ttf'), AssetKind.fonts);
      expect(AssetKind.of('assets/click.wav'), AssetKind.audio);
      expect(AssetKind.of('assets/intro.mp4'), AssetKind.video);
      expect(AssetKind.of('assets/hero.riv'), AssetKind.animations);
      expect(AssetKind.of('assets/config.json'), AssetKind.data);
      expect(AssetKind.of('assets/model.bin'), AssetKind.other);
    });

    test('reads icon and animation hints in the path', () {
      expect(AssetKind.of('assets/icons/home.png'), AssetKind.icons);
      expect(AssetKind.of('assets/app_logo.svg'), AssetKind.icons);
      expect(AssetKind.of('assets/favicon.ico'), AssetKind.icons);
      expect(AssetKind.of('assets/lottie/loader.json'), AssetKind.animations);
      expect(AssetKind.of('assets/icons/list.json'), AssetKind.data);
    });
  });

  group('AssetCategorizer', () {
    late Directory project;

    setUp(() => project = Directory.systemTemp.createTempSync('fide_assets_'));
    tearDown(() => project.deleteSync(recursive: true));

    void write(String relativePath, [String content = '']) {
      File(p.join(project.path, relativePath))
        ..createSync(recursive: true)
        ..writeAsStringSync(content);
    }

    Future<ProjectNode> loadedRoot() async {
      final root = ProjectNode(
        name: p.basename(project.path),
        path: project.path,
        type: ProjectNodeType.directory,
      );
      await const ProjectTreeReader().loadChildren(root);
      return root;
    }

    List<String> names(List<ProjectNode>? nodes) => [
      for (final node in nodes ?? const <ProjectNode>[]) node.name,
    ];

    test('groups the assets folder and pubspec entries by kind', () async {
      write('pubspec.yaml', '''
name: app
flutter:
  assets:
    - images/
    - path: data/cities.csv
  fonts:
    - family: Inter
      fonts:
        - asset: fonts/Inter.ttf
''');
      write('assets/icons/home.png');
      write('assets/.DS_Store');
      write('images/backgrounds/sky.jpg');
      write('data/cities.csv');
      write('fonts/Inter.ttf');
      write('fonts/unlisted.otf');

      final assets = await const AssetCategorizer().categorize(
        await loadedRoot(),
      );

      expect(assets.keys, [
        AssetKind.images,
        AssetKind.icons,
        AssetKind.fonts,
        AssetKind.data,
      ]);
      expect(names(assets[AssetKind.images]), ['sky.jpg']);
      expect(names(assets[AssetKind.icons]), ['home.png']);
      expect(names(assets[AssetKind.fonts]), ['Inter.ttf']);
      expect(names(assets[AssetKind.data]), ['cities.csv']);
    });

    test('ignores entries outside the project and missing paths', () async {
      write('pubspec.yaml', '''
name: app
flutter:
  assets:
    - ../secrets/
    - missing/
''');

      final assets = await const AssetCategorizer().categorize(
        await loadedRoot(),
      );

      expect(assets, isEmpty);
    });
  });

  test('ByteSize.readableSize', () {
    expect(0.readableSize, '0 B');
    expect(512.readableSize, '512.0 B');
    expect(2048.readableSize, '2.0 KB');
  });
}
