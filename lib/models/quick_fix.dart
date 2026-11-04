import 'package:fcheck/fcheck.dart' as fcheck;

/// What a quick fix did: one line for the user and the files it wrote.
typedef QuickFixOutcome = ({String summary, List<String> changedFiles});

/// A fix FIDE applies to a quality issue itself, editing the files with
/// its own code: instantly, or asking the model only for each translated
/// text. Each fix says which analyzer's issue offers it and when, so a new
/// fix is one entry here and one handler.
enum QuickFix {
  /// Move hardcoded strings users read, with a `BuildContext`, into the
  /// template ARB file and look them up through the generated
  /// localizations class.
  localizeStrings(
    'Localize strings',
    'moves the hardcoded strings users read into the ARB files and looks '
        'them up through the generated class',
    domain: fcheck.AnalyzerDomain.hardcodedStrings,
    appliesTo: _canLocalize,
  ),

  /// Localize hardcoded strings passed where no `BuildContext` is to a
  /// widget's `String` field, by making the field a lookup function the
  /// widget calls with its context.
  passLookup(
    'Pass a lookup',
    'localizes the hardcoded strings users read that are passed, where no '
        'BuildContext is, to a widget\'s String field, by making the field '
        'a lookup function the widget calls with its context',
  ),

  /// Move translations written as Dart localizations classes into ARB
  /// files, once, so gen-l10n owns the classes again.
  migrateToArb(
    'Migrate to ARB',
    'moves translations written by hand in the generated localizations '
        'classes into the ARB files, once',
  ),

  /// Make hardcoded strings the code compares or looks up, such as
  /// Firestore collection and field names, named constants in one class.
  makeConstants(
    'Make string constants',
    'makes the hardcoded strings the code compares or looks up, such as '
        'Firestore collection and field names, named constants',
    domain: fcheck.AnalyzerDomain.hardcodedStrings,
    appliesTo: _hasConstantStrings,
  ),

  /// Remove the ARB keys the code never uses from every ARB file.
  removeUnusedKeys(
    'Remove unused keys',
    'removes the ARB keys the code never uses from every ARB file, with '
        'their metadata, and regenerates the classes',
    domain: fcheck.AnalyzerDomain.localization,
    appliesTo: _solvesLocalizationProblems,
    localizationProblems: {'unusedKey'},
  ),

  /// Sort the members of widget and `State` classes, and imports, in the
  /// order fCheck checks, with fCheck's own sorter.
  sortMembers(
    'Sort members',
    'sorts the members of widget and State classes, and the imports, of '
        'every file in the order fCheck checks',
    domain: fcheck.AnalyzerDomain.sourceSorting,
  ),

  /// Raise the dependency constraints to their latest resolvable
  /// versions, which often bring Swift Package Manager support.
  upgradePackages(
    'Upgrade packages',
    'raises every dependency constraint in pubspec.yaml to its latest '
        'resolvable version and runs flutter pub get',
  ),

  /// Remove CocoaPods from the iOS and macOS projects once no plugin
  /// needs it, leaving Swift Package Manager alone.
  removeCocoaPods(
    'Remove CocoaPods',
    'runs pod deintegrate and deletes the Podfiles, Pods folders and '
        'CocoaPods xcconfig includes of the iOS and macOS projects, once '
        'every plugin supports Swift Package Manager',
  ),

  /// Translate missing, empty or untranslated ARB keys one short prompt at
  /// a time, FIDE writing the ARB files.
  translateKeys(
    'Translate with AI',
    'translates the missing, empty or untranslated ARB keys of every '
        'language',
    usesAi: true,
    domain: fcheck.AnalyzerDomain.localization,
    appliesTo: _solvesLocalizationProblems,
    localizationProblems: {
      'empty',
      'missing',
      'placeholderMismatch',
      'unchanged',
    },
  );

  const QuickFix(
    this.label,
    this.purpose, {
    this.usesAi = false,
    this.domain,
    this._appliesTo = _always,
    this.localizationProblems = const {},
  });

  /// Name of the fix, on its button and tooltip.
  final String label;

  /// What the fix does, for the AI choosing it: a phrase following the
  /// fix's name, such as "makes … named constants".
  final String purpose;

  /// Whether the fix asks the model, so it runs as a task in the AI panel.
  final bool usesAi;

  /// The analyzer whose issue offers the fix, when [appliesTo] its
  /// findings; null for fixes offered elsewhere.
  final fcheck.AnalyzerDomain? domain;

  /// fCheck's localization problems the fix solves, such as `missing`;
  /// none for fixes not working on ARB keys.
  final Set<String> localizationProblems;

  /// Whether the fix can solve some of the findings in its metrics.
  final bool Function(QuickFix fix, fcheck.ProjectMetrics metrics) _appliesTo;

  /// Whether the fix can solve some of [metrics]' findings of its
  /// [domain].
  bool appliesTo(fcheck.ProjectMetrics metrics) => _appliesTo(this, metrics);

  /// Any findings: the analyzer's issue alone calls for the fix.
  static bool _always(QuickFix _, fcheck.ProjectMetrics _) => true;

  /// Whether strings can be localized: the project is localized, its
  /// translations are in the ARB files, and some strings have a
  /// `BuildContext`.
  static bool _canLocalize(QuickFix _, fcheck.ProjectMetrics metrics) =>
      metrics.usesLocalization &&
      metrics.localizationSync?.isInSync != false &&
      metrics.hardcodedStringIssues.any(
        (issue) => issue.site?.buildContextName != null,
      );

  /// Whether some strings have no interpolations, so they can be named
  /// constants.
  static bool _hasConstantStrings(QuickFix _, fcheck.ProjectMetrics metrics) =>
      metrics.hardcodedStringIssues.any(
        (issue) => issue.site?.interpolations.isEmpty ?? false,
      );

  /// Whether [metrics] has localization problems [fix] solves.
  static bool _solvesLocalizationProblems(
    QuickFix fix,
    fcheck.ProjectMetrics metrics,
  ) => metrics.localizationIssues.any(
    (issue) => issue.details.any(
      (detail) => fix.localizationProblems.contains(detail.problemType.name),
    ),
  );
}
