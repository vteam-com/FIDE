part of 'reference_finder.dart';

/// Asks whether [contents] compile no worse than their files do now,
/// answered with null when they do; see [ReferenceFinder.checkCompiles].
class CheckCompilesRequest extends ReferenceRequest<void> {
  /// Creates the request checking [contents] for the change [action].
  const CheckCompilesRequest(this.contents, this.action);

  /// New content of each file to check, keyed by absolute path.
  final Map<String, String> contents;

  /// Names the change in the error, such as `Renaming`.
  final String action;
}
