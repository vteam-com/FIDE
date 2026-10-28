import 'dart:io';

/// The platforms a Flutter project can target, with the metadata each part
/// of the UI needs. Declaration order is the order platforms are shown in.
///
/// Each value's [name] is the platform id Flutter uses: the `flutter build`
/// target, the project's platform folder, and the value saved in preferences.
enum FlutterPlatform {
  android('Android', 'android'),
  ios('iOS', 'ios'),
  web('Web', 'chrome'),
  macos('macOS', 'macos'),
  linux('Linux', 'linux'),
  windows('Windows', 'windows');

  const FlutterPlatform(this.displayName, this.deviceTarget);

  /// Human-readable platform name.
  final String displayName;

  /// Device id passed to `flutter run -d`.
  final String deviceTarget;

  /// Whether the host OS can build this platform: web and Android build
  /// anywhere, iOS needs macOS, and desktop targets need their own OS.
  bool get canBuildOnHost => switch (this) {
    android || web => true,
    ios || macos => Platform.isMacOS,
    linux => Platform.isLinux,
    windows => Platform.isWindows,
  };

  /// Bundled SVG icon for this platform.
  String get iconAsset => 'assets/platform_$name.svg';

  /// Whether this platform's native dependencies are managed by CocoaPods.
  bool get usesCocoaPods => this == ios || this == macos;

  /// Ids of the platforms that have a folder in the project at [projectPath].
  static Set<String> configuredIn(String projectPath) {
    return {
      for (final platform in values)
        if (Directory('$projectPath/${platform.name}').existsSync())
          platform.name,
    };
  }

  /// Returns the platform with id [id], or null for an unknown id.
  static FlutterPlatform? fromId(String id) => values.asNameMap()[id];
}
