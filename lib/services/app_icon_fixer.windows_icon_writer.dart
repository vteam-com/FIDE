part of 'app_icon_fixer.dart';

/// Writes the runner's `.ico` holding every size Windows needs.
class WindowsIconWriter extends PlatformIconWriter {
  /// Creates a stateless writer.
  const WindowsIconWriter();

  @override
  void write(IconWriter writer) {
    writer.ico(
      AppIconChecker.windowsIconPathIn(writer.root),
      AppIconChecker.windowsRequiredSizes,
    );
  }
}
