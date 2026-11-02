part of 'reference_finder.dart';

/// Asks for the field the argument starting at [offset] of [filePath]
/// fills; see [ReferenceFinder.lookupField].
class LookupFieldRequest extends ReferenceRequest<LookupField> {
  /// Creates the request for the argument at [offset] of [filePath].
  const LookupFieldRequest(this.filePath, this.offset);

  /// The file holding the argument, as an absolute path.
  final String filePath;

  /// Where the argument starts in [filePath]'s content.
  final int offset;
}
