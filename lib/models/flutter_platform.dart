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

  /// The `flutter build` target packaging an Android App Bundle.
  static const String appBundleTarget = 'appbundle';

  /// Human-readable platform name.
  final String displayName;

  /// Device id passed to `flutter run -d`.
  final String deviceTarget;

  /// Whether [host], the desktop platform the IDE runs on (null for an
  /// unknown OS), can build this platform: web and Android build anywhere,
  /// iOS needs macOS, and desktop targets need their own OS.
  bool canBuildOn(FlutterPlatform? host) => switch (this) {
    android || web => true,
    ios => host == macos,
    macos || linux || windows => host == this,
  };

  /// How to add this platform to a project that has no folder for it.
  String get enableInstructions {
    final create =
        'Run in the project folder:\nflutter create --platforms=$name .';
    return switch (this) {
      android => '$create\n\nRequires Android Studio or the Android SDK.',
      ios => '$create\n\nRequires macOS and Xcode.',
      web =>
        'If Flutter web is disabled, first run:\nflutter config --enable-web\n\n$create',
      macos || linux || windows =>
        'If Flutter $displayName desktop is disabled, first run:\nflutter config --enable-$name-desktop\n\n$create',
    };
  }

  /// Why the host OS [hostOs] can't build this platform.
  String cannotBuildOn(String hostOs) {
    final requiredHost = switch (this) {
      ios || macos => macos.displayName,
      _ => displayName,
    };
    return '$displayName builds require a $requiredHost machine.\n\nYou cannot build $displayName apps from $hostOs.';
  }

  /// The `flutter build` arguments for [target], one of [buildTargets]
  /// (the first by default), with this platform's extra flags.
  List<String> buildArguments([String? target]) => [
    'build',
    target ?? buildTargets.first,
    ...extraBuildArguments,
  ];

  /// The `flutter build` targets packaging this platform, the default
  /// first: Android builds an APK or an App Bundle, the others their id.
  List<String> get buildTargets => switch (this) {
    android => const ['apk', appBundleTarget],
    _ => [name],
  };

  /// Flags every `flutter build` of this platform adds: web builds skip the
  /// WebAssembly dry run, which only warns.
  List<String> get extraBuildArguments => switch (this) {
    web => const ['--no-wasm-dry-run'],
    _ => const [],
  };

  /// Bundled SVG icon for this platform.
  String get iconAsset => 'assets/platform_$name.svg';

  /// Whether this platform's native dependencies are managed by CocoaPods.
  bool get usesCocoaPods => this == ios || this == macos;

  /// Returns the platform with id [id], or null for an unknown id.
  static FlutterPlatform? fromId(String id) => values.asNameMap()[id];
}
