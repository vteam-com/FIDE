part of 'dry_analyzer.dart';

/// A public numeric constant of the project, reusable for the numbers
/// equal to it.
class _Constant {
  _Constant(this.name, this.scopeName, this.libraryUri, this.type);

  /// The library declaring it, imported where it is used.
  final String libraryUri;

  /// How code names it: `AppIconSize.large`.
  final String name;

  /// The name a file must see to use it: its class, or itself at the top
  /// level.
  final String scopeName;

  /// Its type: a number written in a setting takes only a constant of the
  /// number's type.
  final DartType type;

  /// The edit writing [name] in place of [use], importing [libraryUri]
  /// when the file doesn't see [scopeName] yet.
  DryEdit editOf(_LiteralUse use) => DryEdit(
    use.location.path,
    use.offset,
    use.source,
    name,
    importUri: use.scope.lookup(scopeName).getter == null ? libraryUri : null,
  );
}
