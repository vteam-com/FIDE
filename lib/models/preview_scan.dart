import 'package:flutter/foundation.dart';

part 'preview_scan.preview_annotation.dart';
part 'preview_scan.preview_declaration.dart';
part 'preview_scan.preview_import.dart';
part 'preview_scan.preview_parameter.dart';
part 'preview_scan.preview_widget.dart';

/// What the Preview panel needs to know about one Dart file: its widget
/// previews, its widgets and its imports.
@immutable
class PreviewScan {
  /// The scan of a file that can't be parsed or has nothing to preview.
  static const PreviewScan empty = PreviewScan();

  /// The file's `@Preview` functions, static methods and constructors, in
  /// file order.
  final List<PreviewDeclaration> previews;

  /// The file's public widget classes, in file order.
  final List<PreviewWidget> widgets;

  /// The file's import directives, in file order.
  final List<PreviewImport> imports;

  /// The first value of each enum the file declares, by enum name.
  final Map<String, String> enumFirstValues;

  /// The names of the file's top-level declarations.
  final Set<String> topLevelNames;

  /// Whether the file is a `part of` another library, so it can't be
  /// imported by itself.
  final bool isPart;

  /// The offset just past the file's last directive; 0 without any.
  final int directivesEnd;

  /// Creates the scan.
  const PreviewScan({
    this.previews = const [],
    this.widgets = const [],
    this.imports = const [],
    this.enumFirstValues = const {},
    this.topLevelNames = const {},
    this.isPart = false,
    this.directivesEnd = 0,
  });

  /// A copy keeping only the preview labeled [label].
  PreviewScan only(String label) => PreviewScan(
    previews: [
      for (final preview in previews)
        if (preview.label == label) preview,
    ],
    widgets: widgets,
    imports: imports,
    enumFirstValues: enumFirstValues,
    topLevelNames: topLevelNames,
    isPart: isPart,
    directivesEnd: directivesEnd,
  );

  /// Annotation [position] of the preview labeled [label]; null when
  /// either doesn't exist.
  PreviewAnnotation? annotationOf(String label, int position) => previews
      .where((preview) => preview.label == label)
      .firstOrNull
      ?.annotations
      .elementAtOrNull(position);

  /// The widgets that no preview of this file builds.
  List<PreviewWidget> get widgetsWithoutPreview => [
    for (final widget in widgets)
      if (!previews.any((preview) => preview.builds(widget.name))) widget,
  ];
}
