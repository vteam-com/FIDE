part of 'dry_review.dart';

/// One way a repeated setting is written, as in its first location, and
/// every [locations] writing it that way.
class DryVariant {
  /// Creates the variant written as [source] at [locations].
  const DryVariant(this.source, this.locations);

  /// Where it is written, in file order.
  final List<DryLocation> locations;

  /// The code, as written at the first location.
  final String source;
}
