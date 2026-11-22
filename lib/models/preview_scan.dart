import 'package:fide/models/text_offsets.dart';
import 'package:flutter/foundation.dart';

part 'preview_scan.preview_annotation.dart';
part 'preview_scan.preview_class.dart';
part 'preview_scan.preview_declaration.dart';
part 'preview_scan.preview_directive.dart';
part 'preview_scan.preview_parameter.dart';

/// What the Preview panel needs to know about one Dart file: its widget
/// previews, its classes, enums and type aliases, and its directives.
@immutable
class PreviewScan {
  /// The scan of a file that can't be parsed or has nothing to preview.
  static const PreviewScan empty = PreviewScan();

  /// The file's `@Preview` functions, static methods and constructors, in
  /// file order.
  final List<PreviewDeclaration> previews;

  /// The file's public classes, in file order.
  final List<PreviewClass> classes;

  /// The file's import directives, in file order.
  final List<PreviewDirective> imports;

  /// The file's export directives, in file order.
  final List<PreviewDirective> exports;

  /// The URIs of the file's `part` directives, in file order.
  final List<String> parts;

  /// The first value of each enum the file declares, by enum name.
  final Map<String, String> enumFirstValues;

  /// The type each type alias of the file names, as written, by alias
  /// name, such as `void Function(int)` for `OnPick`.
  final Map<String, String> typedefs;

  /// The names of the file's top-level declarations.
  final Set<String> topLevelNames;

  /// Whether the file is a `part of` another library, so it can't be
  /// imported by itself.
  final bool isPart;

  /// Creates the scan.
  const PreviewScan({
    this.previews = const [],
    this.classes = const [],
    this.imports = const [],
    this.exports = const [],
    this.parts = const [],
    this.enumFirstValues = const {},
    this.typedefs = const {},
    this.topLevelNames = const {},
    this.isPart = false,
  });

  /// A copy keeping only the preview labeled [label].
  PreviewScan only(String label) => PreviewScan(
    previews: [
      for (final preview in previews)
        if (preview.label == label) preview,
    ],
    classes: classes,
    imports: imports,
    exports: exports,
    parts: parts,
    enumFirstValues: enumFirstValues,
    typedefs: typedefs,
    topLevelNames: topLevelNames,
    isPart: isPart,
  );

  /// Annotation [position] of the preview labeled [label]; null when
  /// either doesn't exist.
  PreviewAnnotation? annotationOf(String label, int position) => previews
      .where((preview) => preview.label == label)
      .firstOrNull
      ?.annotations
      .elementAtOrNull(position);

  /// The class named [name]; null when the file declares none.
  PreviewClass? classNamed(String name) =>
      classes.where((type) => type.name == name).firstOrNull;

  /// The names of the types the file declares: its classes, enums and
  /// type aliases.
  Iterable<String> get typeNames => [
    ...classes.map((type) => type.name),
    ...enumFirstValues.keys,
    ...typedefs.keys,
  ];

  /// The widgets code can build: the public classes extending a widget
  /// class that are constructible.
  List<PreviewClass> get widgets => [
    for (final type in classes)
      if (type.isWidget && type.isConstructible) type,
  ];

  /// The widgets that no preview of this file builds.
  List<PreviewClass> get widgetsWithoutPreview => [
    for (final widget in widgets)
      if (!previews.any((preview) => preview.builds(widget.name))) widget,
  ];
}
