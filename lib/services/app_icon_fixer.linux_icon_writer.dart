part of 'app_icon_fixer.dart';

/// Writes the window icon, has the GTK runner load it from next to the
/// executable instead of any other icon, and installs it there.
class LinuxIconWriter extends PlatformIconWriter {
  /// Creates a stateless writer.
  const LinuxIconWriter();

  /// Loads the Linux window icon from next to the executable, where the
  /// CMake rule [_installRule] installs it.
  static const String _iconCode = '''
  // The app icon, installed next to the executable by CMakeLists.txt.
  g_autofree gchar* exe_path = g_file_read_link("/proc/self/exe", nullptr);
  g_autofree gchar* exe_dir = g_path_get_dirname(exe_path);
  g_autofree gchar* icon_path =
      g_build_filename(exe_dir, "data", "app_icon.png", nullptr);
  gtk_window_set_icon_from_file(window, icon_path, nullptr);
''';

  /// Installs the Linux window icon into the bundle's data folder.
  static const String _installRule = '''

# The window icon runner/my_application.cc loads.
install(FILES "runner/resources/app_icon.png"
  DESTINATION "\${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)
''';

  /// Project-relative Linux CMake project.
  static const String _cmakePath = 'linux/CMakeLists.txt';

  /// Statements setting the GTK window icon, which [_iconCode] replaces.
  static final RegExp _iconStatement = RegExp(
    r'^[ \t]*gtk_window_set(?:_default)?_icon\w*\([^;]*\);[ \t]*\n',
    multiLine: true,
  );

  /// The GTK runner line [_iconCode] goes after.
  static final RegExp _defaultSize = RegExp(
    r'^.*gtk_window_set_default_size\(.*\n',
    multiLine: true,
  );

  @override
  void write(IconWriter writer) {
    final sourcePath = AppIconChecker.linuxApplicationPathIn(writer.root);
    final source = sourcePath == null ? null : writer.read(sourcePath);
    if (sourcePath == null || source == null) {
      throw const AppIconFixException(
        'Missing the GTK runner; recreate the platform with '
        '"flutter create --platforms=linux ."',
      );
    }
    writer.png(AppIconChecker.linuxIconPath, AppIconChecker.linuxMinIconSize);
    if (!source.contains(_iconCode)) {
      final cleaned = source.replaceAll(_iconStatement, '');
      final anchor = _defaultSize.firstMatch(cleaned);
      if (anchor == null) {
        throw AppIconFixException(
          'Could not find where the window is set up in $sourcePath; add '
          'the icon there by hand:\n$_iconCode',
        );
      }
      writer.text(
        sourcePath,
        cleaned.replaceRange(anchor.end, anchor.end, _iconCode),
      );
    }
    final cmake = writer.read(_cmakePath);
    final iconName = p.basename(AppIconChecker.linuxIconPath);
    if (cmake != null && !cmake.contains(iconName)) {
      writer.text(_cmakePath, '${cmake.trimRight()}\n$_installRule');
    }
  }
}
