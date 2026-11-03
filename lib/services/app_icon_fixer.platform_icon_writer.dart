part of 'app_icon_fixer.dart';

/// Writes one platform's app icons, and the files listing them, through
/// an [IconWriter]: what [AppIconFixer.fix] does for that platform.
///
/// [AppIconPlatform] is fCheck's enum, so it can't carry the behaviour;
/// [byPlatform] maps each value to its writer instead.
abstract class PlatformIconWriter {
  /// Creates a stateless writer.
  const PlatformIconWriter();

  /// The writer of each platform.
  static const Map<AppIconPlatform, PlatformIconWriter> byPlatform = {
    AppIconPlatform.android: AndroidIconWriter(),
    AppIconPlatform.ios: AppleIconWriter(AppIconPlatform.ios),
    AppIconPlatform.macos: AppleIconWriter(AppIconPlatform.macos),
    AppIconPlatform.web: WebIconWriter(),
    AppIconPlatform.windows: WindowsIconWriter(),
    AppIconPlatform.linux: LinuxIconWriter(),
  };

  /// Writes the platform's icons with [writer], whose root is the project.
  ///
  /// Throws [AppIconFixException] when the platform lacks the file
  /// declaring its icons.
  void write(IconWriter writer);
}
