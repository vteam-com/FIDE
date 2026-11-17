part of 'dry_review.dart';

/// Where a widget is built: a project-relative [path] and 1-based [line].
class DryLocation {
  /// Creates the location in [path] at [line], inside [className].
  const DryLocation(this.path, this.line, {this.className});

  /// The class the widget is built in; null outside a class.
  final String? className;

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
