part of 'dry_review.dart';

/// One replacement a [DryFix] makes: the [original] code at [offset] in
/// the file at [path] becomes [replacement], importing [importUri] into
/// the file when the replacement names something it doesn't import yet.
class DryEdit {
  /// Creates the replacement of [original], at [offset] in [path], by
  /// [replacement].
  const DryEdit(
    this.path,
    this.offset,
    this.original,
    this.replacement, {
    this.importUri,
  });

  /// Library the file must import for [replacement] to resolve; null
  /// when it already does.
  final String? importUri;

  /// Offset of [original] in the file.
  final int offset;

  /// The code replaced, as it was when reviewed: the edit is refused when
  /// the file no longer has it at [offset].
  final String original;

  /// Project-relative path of the file.
  final String path;

  /// The code written instead.
  final String replacement;

  /// Offset just past [original].
  int get end => offset + original.length;
}
