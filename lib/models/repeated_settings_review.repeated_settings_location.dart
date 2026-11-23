part of 'repeated_settings_review.dart';

/// Where a widget is built: a project-relative [path] and 1-based [line],
/// in a view or in a widget.
class RepeatedSettingsLocation {
  /// Creates the location in [path] at [line], inside [className], in a
  /// view when [isInView].
  const RepeatedSettingsLocation(
    this.path,
    this.line, {
    this.className,
    this.isInView = false,
  });

  /// The class the widget is built in; null outside a class.
  final String? className;

  /// Whether the widget is built in a view, a file declaring a screen as
  /// the File Layout review judges it, wherever it is; else in a widget.
  final bool isInView;

  /// 1-based line.
  final int line;

  /// Project-relative path of the file.
  final String path;

  /// Whether the location is in a shared widget, under `lib/widgets/`.
  bool get isSharedWidget => path.startsWith(sharedWidgetsFolder);

  /// Folder of the project's shared widgets.
  static const String sharedWidgetsFolder = 'lib/widgets/';

  @override
  String toString() => '$path:$line';
}
