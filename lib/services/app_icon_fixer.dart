import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:fcheck/fcheck.dart';
import 'package:fide/constants/constants.dart';
import 'package:fide/services/project_config_reader.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

part 'app_icon_fixer.app_icon_fix_exception.dart';
part 'app_icon_fixer.icon_writer.dart';

/// Writes a platform's app icons from one master image, and the files
/// listing them, so that fCheck's [AppIconChecker] finds nothing wrong:
/// what `flutter_launcher_icons` does, without its configuration.
class AppIconFixer {
  final ProjectConfigReader _config;

  /// Creates a fixer reading the project's pubspec with [_config].
  const AppIconFixer(this._config);

  /// Smallest master that no icon is upscaled from: the iOS App Store icon.
  static const int recommendedMasterSize = AppIconChecker.appStoreIconSize;

  /// Size of the favicon written.
  static const int _faviconSize = 32;

  /// Favicon linked from a page that links none.
  static const String _defaultFavicon = 'favicon.png';

  /// Asset catalog slots of new Flutter iOS projects, by idiom, as
  /// `points@scale`.
  static const Map<String, List<String>> _iosDefaultSlots = {
    'iphone': [
      '20x20@2x',
      '20x20@3x',
      '29x29@1x',
      '29x29@2x',
      '29x29@3x',
      '40x40@2x',
      '40x40@3x',
      '60x60@2x',
      '60x60@3x',
    ],
    'ipad': [
      '20x20@1x',
      '20x20@2x',
      '29x29@1x',
      '29x29@2x',
      '40x40@1x',
      '40x40@2x',
      '76x76@1x',
      '76x76@2x',
      '83.5x83.5@2x',
    ],
    'ios-marketing': ['1024x1024@1x'],
  };

  /// Asset catalog slots of new Flutter macOS projects, by idiom.
  static const Map<String, List<String>> _macosDefaultSlots = {
    'mac': [
      '16x16@1x',
      '16x16@2x',
      '32x32@1x',
      '32x32@2x',
      '128x128@1x',
      '128x128@2x',
      '256x256@1x',
      '256x256@2x',
      '512x512@1x',
      '512x512@2x',
    ],
  };

  /// Loads the Linux window icon from next to the executable, where the
  /// CMake rule [_linuxInstallRule] installs it.
  static const String _linuxIconCode = '''
  // The app icon, installed next to the executable by CMakeLists.txt.
  g_autofree gchar* exe_path = g_file_read_link("/proc/self/exe", nullptr);
  g_autofree gchar* exe_dir = g_path_get_dirname(exe_path);
  g_autofree gchar* icon_path =
      g_build_filename(exe_dir, "data", "app_icon.png", nullptr);
  gtk_window_set_icon_from_file(window, icon_path, nullptr);
''';

  /// Installs the Linux window icon into the bundle's data folder.
  static const String _linuxInstallRule = '''

# The window icon runner/my_application.cc loads.
install(FILES "runner/resources/app_icon.png"
  DESTINATION "\${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)
''';

  /// Project-relative Linux CMake project.
  static const String _linuxCmakePath = 'linux/CMakeLists.txt';

  /// Statements setting the GTK window icon, which [_linuxIconCode]
  /// replaces.
  static final RegExp _linuxIconStatement = RegExp(
    r'^[ \t]*gtk_window_set(?:_default)?_icon\w*\([^;]*\);[ \t]*\n',
    multiLine: true,
  );

  /// The GTK runner line [_linuxIconCode] goes after.
  static final RegExp _linuxDefaultSize = RegExp(
    r'^.*gtk_window_set_default_size\(.*\n',
    multiLine: true,
  );

  /// The image the project's icons are best generated from: the one
  /// `flutter_launcher_icons` is configured with, else the largest PNG
  /// icon a platform already has that is not Flutter's default; null when
  /// there is none.
  Future<String?> defaultMasterPath(String projectPath) async {
    final pubspec = await _config.pubspec(projectPath);
    for (final path in pubspec?.launcherIconsImagePaths ?? const <String>[]) {
      final file = File(p.join(projectPath, path));
      if (await file.exists()) return file.path;
    }
    final report = await Isolate.run(
      () => const AppIconChecker().inspect(Directory(projectPath)),
    );
    AppIconSlot? best;
    for (final slot in report.slots) {
      final file = slot.file;
      if (file == null || file.icoSizes.isNotEmpty || slot.isFlutterDefault) {
        continue;
      }
      if (best == null || file.width > best.file!.width) best = slot;
    }
    final path = best?.filePath;
    return path == null ? null : p.join(projectPath, path);
  }

  /// Writes [platform]'s icons in the project at [projectPath] from the
  /// image at [masterPath], off the UI thread; returns the
  /// project-relative files written.
  ///
  /// Throws [AppIconFixException] when the master can't be read or the
  /// platform lacks the file declaring its icons.
  Future<List<String>> fix(
    String projectPath,
    AppIconPlatform platform,
    String masterPath,
  ) {
    return Isolate.run(() {
      final writer = _IconWriter.load(projectPath, masterPath);
      switch (platform) {
        case AppIconPlatform.android:
          _fixAndroid(writer);
        case AppIconPlatform.ios || AppIconPlatform.macos:
          _fixApple(writer, platform);
        case AppIconPlatform.web:
          _fixWeb(writer);
        case AppIconPlatform.windows:
          writer.ico(
            AppIconChecker.windowsIconPathIn(projectPath),
            AppIconChecker.windowsRequiredSizes,
          );
        case AppIconPlatform.linux:
          _fixLinux(writer);
      }
      return writer.written;
    });
  }

  /// Writes the launcher icon of each density, pointing `android:icon` at
  /// it when it names none or a drawable.
  static void _fixAndroid(_IconWriter writer) {
    const manifestPath = AppIconChecker.androidManifestPath;
    final manifest = writer.read(manifestPath);
    if (manifest == null) {
      throw const AppIconFixException(
        'Missing $manifestPath; recreate the platform with '
        '"flutter create --platforms=android ."',
      );
    }
    final icon = AppIconChecker.androidIcon(manifest);
    var name = icon?.name ?? AppIconChecker.androidDefaultIconName;
    if (icon?.type != 'mipmap') {
      name = AppIconChecker.androidDefaultIconName;
      final reference = 'android:icon="@mipmap/$name"';
      writer.text(
        manifestPath,
        icon == null
            ? manifest.replaceFirst(
                RegExp(r'<application\b'),
                '<application\n        $reference',
              )
            : manifest.replaceFirst(
                RegExp(r'android:icon="@drawable/[\w.]+"'),
                reference,
              ),
      );
    }
    for (final MapEntry(key: folder, value: size)
        in AppIconChecker.androidDensitySizes.entries) {
      writer.png('${AppIconChecker.androidResPath}/$folder/$name.png', size);
    }
  }

  /// Writes an image for every slot of the asset catalog icon set, naming
  /// the empty ones, or Flutter's default set when it has none; iOS icons
  /// are made opaque for the App Store.
  static void _fixApple(_IconWriter writer, AppIconPlatform platform) {
    final setPath = AppIconChecker.appleIconSetPathIn(writer.root, platform);
    final contentsPath = '$setPath/Contents.json';
    final existing = writer.readJson(contentsPath);
    final contents = existing?['images'] is List
        ? existing!
        : _defaultContents(platform);
    final images = (contents['images']! as List).whereType<Map>().toList();
    // An image shared with the default appearance must be opaque on iOS;
    // dark and tinted ones may be transparent
    final opaque = <String>{};
    final sizes = <String, int>{};
    for (final image in images) {
      final pixels = AppIconChecker.applePixelSize(image);
      if (pixels == null) continue;
      final filename = '${image['filename'] ??= 'app_icon_$pixels.png'}';
      sizes[filename] = pixels;
      if (platform == AppIconPlatform.ios && image['appearances'] == null) {
        opaque.add(filename);
      }
    }
    for (final MapEntry(key: filename, value: pixels) in sizes.entries) {
      writer.png(
        '$setPath/$filename',
        pixels,
        opaque: opaque.contains(filename),
      );
    }
    writer.json(contentsPath, contents);
  }

  /// Flutter's default `Contents.json` of [platform]'s icon set.
  static Map<String, Object?> _defaultContents(AppIconPlatform platform) {
    final slots = platform == AppIconPlatform.ios
        ? _iosDefaultSlots
        : _macosDefaultSlots;
    return {
      'images': [
        for (final MapEntry(key: idiom, value: sizes) in slots.entries)
          for (final slot in sizes)
            {
              'size': slot.split('@').first,
              'idiom': idiom,
              'scale': slot.split('@').last,
            },
      ],
      'info': {'version': 1, 'author': 'xcode'},
    };
  }

  /// Writes the favicon, linking it when the page links none, and every
  /// manifest icon, adding the sizes browsers need.
  static void _fixWeb(_IconWriter writer) {
    final index = writer.read(AppIconChecker.webIndexPath);
    final href = index == null ? null : AppIconChecker.faviconHref(index);
    if (index != null && href == null) {
      writer.text(
        AppIconChecker.webIndexPath,
        index.replaceFirst(
          '</head>',
          '  <link rel="icon" type="image/png" href="$_defaultFavicon"/>\n'
              '</head>',
        ),
      );
    }
    final faviconPath = AppIconChecker.webPath(href ?? _defaultFavicon);
    if (faviconPath != null) writer.png(faviconPath, _faviconSize);

    const manifestPath = AppIconChecker.webManifestPath;
    final hasManifest = writer.read(manifestPath) != null;
    final manifest = writer.readJson(manifestPath);
    if (hasManifest && manifest == null) {
      throw const AppIconFixException(
        '$manifestPath is not valid JSON; fix it, then try again',
      );
    }
    final contents = manifest ?? <String, Object?>{};
    final icons = contents['icons'] is List
        ? contents['icons']! as List
        : (contents['icons'] = <Object?>[]) as List;
    final sizes = <int>{};
    for (final icon in icons.whereType<Map>()) {
      final size = AppIconChecker.squareSize(icon['sizes'])?.round();
      final path = icon['src'] is String
          ? AppIconChecker.webPath(icon['src'] as String)
          : null;
      if (size == null || path == null) continue;
      sizes.add(size);
      writer.png(path, size);
    }
    final missing = AppIconChecker.webRequiredSizes.difference(sizes);
    for (final size in missing) {
      final src = 'icons/Icon-$size.png';
      icons.add({'src': src, 'sizes': '${size}x$size', 'type': 'image/png'});
      writer.png(AppIconChecker.webPath(src)!, size);
    }
    if (!hasManifest || missing.isNotEmpty) writer.json(manifestPath, contents);
  }

  /// Writes the window icon, has the GTK runner load it from next to the
  /// executable instead of any other icon, and installs it there.
  static void _fixLinux(_IconWriter writer) {
    final sourcePath = AppIconChecker.linuxApplicationPathIn(writer.root);
    final source = sourcePath == null ? null : writer.read(sourcePath);
    if (sourcePath == null || source == null) {
      throw const AppIconFixException(
        'Missing the GTK runner; recreate the platform with '
        '"flutter create --platforms=linux ."',
      );
    }
    writer.png(AppIconChecker.linuxIconPath, AppIconChecker.linuxMinIconSize);
    if (!source.contains(_linuxIconCode)) {
      final cleaned = source.replaceAll(_linuxIconStatement, '');
      final anchor = _linuxDefaultSize.firstMatch(cleaned);
      if (anchor == null) {
        throw AppIconFixException(
          'Could not find where the window is set up in $sourcePath; add '
          'the icon there by hand:\n$_linuxIconCode',
        );
      }
      writer.text(
        sourcePath,
        cleaned.replaceRange(anchor.end, anchor.end, _linuxIconCode),
      );
    }
    final cmake = writer.read(_linuxCmakePath);
    final iconName = p.basename(AppIconChecker.linuxIconPath);
    if (cmake != null && !cmake.contains(iconName)) {
      writer.text(_linuxCmakePath, '${cmake.trimRight()}\n$_linuxInstallRule');
    }
  }
}
