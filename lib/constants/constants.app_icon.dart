part of 'constants.dart';

/// The glyphs that stand for one kind of action wherever it is offered,
/// so a button tells at a glance who does the work.
class AppIcon {
  const AppIcon._();

  /// An action the AI does, such as Fix with AI or writing a commit
  /// message: the sparkles.
  static const IconData ai = Icons.auto_awesome;

  /// A fix FIDE's own code makes at once, such as Fix, Fix All or
  /// Generate Previews: the magic wand.
  static const IconData fix = Icons.auto_fix_high;
}
