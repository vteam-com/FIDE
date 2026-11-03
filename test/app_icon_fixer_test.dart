import 'dart:convert';
import 'dart:io';

import 'package:fcheck/fcheck.dart';
import 'package:fide/services/app_icon_fixer.dart';
import 'package:fide/services/project_config_reader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

void main() {
  late Directory project;
  late String master;

  setUp(() {
    project = Directory.systemTemp.createTempSync('fide_icons_');
    master = p.join(project.path, 'master.png');
    // Wider than tall, with alpha: the fix crops it square and flattens iOS
    final image = img.Image(width: 1100, height: 1024, numChannels: 4)
      ..clear(img.ColorRgba8(30, 120, 200, 128));
    File(master).writeAsBytesSync(img.encodePng(image));
  });
  tearDown(() => project.deleteSync(recursive: true));

  void write(String path, String content) {
    File(p.join(project.path, path))
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
  }

  String read(String path) =>
      File(p.join(project.path, path)).readAsStringSync();

  Future<List<String>> fixThenCheck(AppIconPlatform platform) async {
    await const AppIconFixer(ProjectConfigReader())
        .fix(project.path, platform, master);
    return [
      for (final issue in const AppIconChecker().check(project))
        if (issue.platform == platform) issue.format(),
    ];
  }

  test('Android: every density, and android:icon when missing', () async {
    write(
      AppIconChecker.androidManifestPath,
      '<manifest>\n    <application android:label="app">\n'
      '    </application>\n</manifest>',
    );

    expect(await fixThenCheck(AppIconPlatform.android), isEmpty);
    expect(
      read(AppIconChecker.androidManifestPath),
      contains('android:icon="@mipmap/ic_launcher"'),
    );
  });

  test('iOS: Flutter default icon set, opaque', () async {
    Directory(p.join(project.path, 'ios')).createSync();

    expect(await fixThenCheck(AppIconPlatform.ios), isEmpty);
    final store = AppIconFileInfo.read(
      File(
        p.join(
          project.path,
          AppIconChecker.appleIconSetPath(AppIconPlatform.ios, 'AppIcon'),
          'app_icon_1024.png',
        ),
      ),
    )!;
    expect([store.width, store.hasAlpha], [1024, false]);
  });

  test('iOS: opaque Any icon, transparent Dark icon', () async {
    final set = AppIconChecker.appleIconSetPath(AppIconPlatform.ios, 'AppIcon');
    Map<String, Object> entry(String file, [String? appearance]) => {
      'idiom': 'universal',
      'size': '1024x1024',
      'filename': file,
      if (appearance != null)
        'appearances': [
          {'appearance': 'luminosity', 'value': appearance},
        ],
    };
    write(
      '$set/Contents.json',
      jsonEncode({
        'images': [
          entry('shared.png'),
          entry('shared.png', 'tinted'),
          entry('dark.png', 'dark'),
        ],
      }),
    );

    expect(await fixThenCheck(AppIconPlatform.ios), isEmpty);
    AppIconFileInfo info(String name) =>
        AppIconFileInfo.read(File(p.join(project.path, set, name)))!;
    expect(info('shared.png').hasAlpha, isFalse);
    expect(info('dark.png').hasAlpha, isTrue);
  });

  test('macOS: fills empty slots of the existing icon set', () async {
    final set = AppIconChecker.appleIconSetPath(
      AppIconPlatform.macos,
      'AppIcon',
    );
    write(
      '$set/Contents.json',
      jsonEncode({
        'images': [
          {'size': '16x16', 'idiom': 'mac', 'scale': '2x'},
          {
            'size': '512x512',
            'idiom': 'mac',
            'scale': '2x',
            'filename': 'big.png',
          },
        ],
      }),
    );

    expect(await fixThenCheck(AppIconPlatform.macos), isEmpty);
    expect(read('$set/Contents.json'), contains('app_icon_32.png'));
  });

  test('Web: links a favicon and adds the 512 px manifest icon', () async {
    write(AppIconChecker.webIndexPath, '<html><head>\n</head></html>');
    write(
      AppIconChecker.webManifestPath,
      jsonEncode({
        'name': 'app',
        'icons': [
          {'src': 'icons/Icon-192.png', 'sizes': '192x192'},
        ],
      }),
    );

    expect(await fixThenCheck(AppIconPlatform.web), isEmpty);
    expect(read(AppIconChecker.webIndexPath), contains('href="favicon.png"'));
    expect(read(AppIconChecker.webManifestPath), contains('Icon-512.png'));
  });

  test('Windows: an .ico with every size', () async {
    write(
      AppIconChecker.windowsResourceScriptPath,
      r'IDI_APP_ICON ICON "resources\\app_icon.ico"',
    );

    expect(await fixThenCheck(AppIconPlatform.windows), isEmpty);
  });

  test('Linux: loads an installed icon instead of a relative one', () async {
    const source = 'linux/runner/my_application.cc';
    write(
      source,
      '  gtk_window_set_default_size(window, 1280, 720);\n'
      '  gtk_window_set_icon_from_file(GTK_WINDOW(window),"assets/a.png",NULL);\n'
      '  gtk_widget_show(GTK_WIDGET(window));\n',
    );
    write('linux/CMakeLists.txt', 'project(app)\n');

    expect(await fixThenCheck(AppIconPlatform.linux), isEmpty);
    expect(read(source), isNot(contains('assets/a.png')));
    expect(read('linux/CMakeLists.txt'), contains('app_icon.png'));

    // A second fix leaves the runner and the install rule as they are
    final fixed = read(source);
    await const AppIconFixer(ProjectConfigReader())
        .fix(project.path, AppIconPlatform.linux, master);
    expect(read(source), fixed);
    expect('app_icon.png'.allMatches(read('linux/CMakeLists.txt')).length, 1);
  });

  test('every platform has a writer, iOS and macOS sharing one', () {
    expect(
      PlatformIconWriter.byPlatform.keys,
      unorderedEquals(AppIconPlatform.values),
    );
    expect(
      PlatformIconWriter.byPlatform[AppIconPlatform.android],
      isA<AndroidIconWriter>(),
    );
    expect(
      PlatformIconWriter.byPlatform[AppIconPlatform.macos],
      isA<AppleIconWriter>().having(
        (w) => w.platform,
        'platform',
        AppIconPlatform.macos,
      ),
    );
    expect(
      PlatformIconWriter.byPlatform[AppIconPlatform.web],
      isA<WebIconWriter>(),
    );
    expect(
      PlatformIconWriter.byPlatform[AppIconPlatform.windows],
      isA<WindowsIconWriter>(),
    );
    expect(
      PlatformIconWriter.byPlatform[AppIconPlatform.linux],
      isA<LinuxIconWriter>(),
    );
  });

  test('refuses a master that is not an image', () async {
    write('master.png', 'text');
    Directory(p.join(project.path, 'ios')).createSync();

    expect(
      const AppIconFixer(ProjectConfigReader())
          .fix(project.path, AppIconPlatform.ios, master),
      throwsA(isA<AppIconFixException>()),
    );
  });

  test('defaults to the flutter_launcher_icons image', () async {
    write('assets/logo.png', '');
    write(
      'pubspec.yaml',
      'name: app\nflutter_launcher_icons:\n  macos:\n'
          '    image_path: "assets/logo.png"\n',
    );

    expect(
      await const AppIconFixer(ProjectConfigReader())
          .defaultMasterPath(project.path),
      p.join(project.path, 'assets', 'logo.png'),
    );
  });
}
