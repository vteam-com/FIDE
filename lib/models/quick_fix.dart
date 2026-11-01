import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:flutter/material.dart';

/// A fix FIDE applies to a quality issue itself, editing the files with
/// its own code: instantly, or asking the model only for each translated
/// text.
enum QuickFix {
  /// Move hardcoded strings users read, with a `BuildContext`, into the
  /// template ARB file and look them up through the generated
  /// localizations class.
  localizeStrings(
    Icons.translate,
    'Localize strings',
    'moves the hardcoded strings users read into the ARB files and looks '
        'them up through the generated class',
  ),

  /// Localize hardcoded strings passed where no `BuildContext` is to a
  /// widget's `String` field, by making the field a lookup function the
  /// widget calls with its context.
  passLookup(
    Icons.input,
    'Pass a lookup',
    'localizes the hardcoded strings users read that are passed, where no '
        'BuildContext is, to a widget\'s String field, by making the field '
        'a lookup function the widget calls with its context',
  ),

  /// Move translations written as Dart localizations classes into ARB
  /// files, once, so gen-l10n owns the classes again.
  migrateToArb(
    Icons.drive_file_move_outline,
    'Migrate to ARB',
    'moves translations written by hand in the generated localizations '
        'classes into the ARB files, once',
  ),

  /// Make hardcoded strings the code compares or looks up, such as
  /// Firestore collection and field names, named constants in one class.
  makeConstants(
    Icons.data_object,
    'Make string constants',
    'makes the hardcoded strings the code compares or looks up, such as '
        'Firestore collection and field names, named constants',
  ),

  /// Remove the ARB keys the code never uses from every ARB file.
  removeUnusedKeys(
    Icons.delete_sweep_outlined,
    'Remove unused keys',
    'removes the ARB keys the code never uses from every ARB file, with '
        'their metadata, and regenerates the classes',
  ),

  /// Sort the members of widget and `State` classes, and imports, in the
  /// order fCheck checks, with fCheck's own sorter.
  sortMembers(
    Icons.sort,
    'Sort members',
    'sorts the members of widget and State classes, and the imports, of '
        'every file in the order fCheck checks',
  ),

  /// Translate missing, empty or untranslated ARB keys one short prompt at
  /// a time, FIDE writing the ARB files.
  translateKeys(
    Icons.g_translate,
    'Translate with AI',
    'translates the missing, empty or untranslated ARB keys of every '
        'language',
  );

  const QuickFix(this.icon, this.label, this.purpose);

  /// Glyph of the fix's button.
  final IconData icon;

  /// Name of the fix, on its button and tooltip.
  final String label;

  /// Whether the fix asks the model, so it runs as a task in the AI panel.
  bool get usesAi => this == translateKeys;

  /// fCheck's localization problems the fix solves, such as `missing`;
  /// none for fixes not working on ARB keys.
  Set<String> get localizationProblems => switch (this) {
    translateKeys => const {
      'empty',
      'missing',
      'placeholderMismatch',
      'unchanged',
    },
    removeUnusedKeys => const {'unusedKey'},
    _ => const {},
  };

  /// The role of the hardcoded strings the fix rewrites unasked; null for
  /// fixes not rewriting hardcoded strings.
  fcheck.HardcodedStringRole? get stringRole => switch (this) {
    localizeStrings || passLookup => fcheck.HardcodedStringRole.presentation,
    makeConstants => fcheck.HardcodedStringRole.data,
    _ => null,
  };

  /// What the fix does, for the AI choosing it: a phrase following the
  /// fix's name, such as "makes … named constants".
  final String purpose;
}
