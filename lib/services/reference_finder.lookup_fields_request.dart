part of 'reference_finder.dart';

/// Where a string argument starts: the file holding it, as an absolute
/// path, and its offset in that file's content.
typedef LookupSite = ({String filePath, int offset});

/// The field a [LookupSite]'s argument fills, or the message saying why
/// it fills none that can become a lookup function.
typedef LookupSiteField = ({LookupField? field, String? error});

/// Asks for the field each of [sites] fills, in one pass over the
/// analysis; see [ReferenceFinder.lookupFields].
class LookupFieldsRequest extends ReferenceRequest<List<LookupSiteField>> {
  /// Creates the request for the arguments at [sites].
  const LookupFieldsRequest(this.sites);

  /// The arguments to look up, in the order the answer follows.
  final List<LookupSite> sites;
}
