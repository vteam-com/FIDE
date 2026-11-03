part of 'app_icon_fixer.dart';

/// Writes an image for every slot of the asset catalog icon set, naming
/// the empty ones, or Flutter's default set when it has none; iOS icons
/// are made opaque for the App Store.
class AppleIconWriter extends PlatformIconWriter {
  /// Creates the writer of [platform], iOS or macOS.
  const AppleIconWriter(this.platform);

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

  /// The Apple platform written.
  final AppIconPlatform platform;

  @override
  void write(IconWriter writer) {
    final setPath = AppIconChecker.appleIconSetPathIn(writer.root, platform);
    final contentsPath = '$setPath/Contents.json';
    final existing = writer.readJson(contentsPath);
    final contents = existing?['images'] is List
        ? existing!
        : _defaultContents();
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
  Map<String, Object?> _defaultContents() {
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
}
