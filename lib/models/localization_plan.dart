import 'package:fide/models/hardcoded_string.dart';
import 'package:fide/models/l10n_config.dart';

/// What localizing a project's hardcoded strings would do, for the user to
/// review before it is applied: the strings that can become lookups and
/// why the others cannot.
class LocalizationPlan {
  /// Creates the plan for the project at [projectPath].
  const LocalizationPlan({
    required this.projectPath,
    required this.config,
    required this.importUri,
    required this.candidates,
    this.rejected = const {},
    required this.skipped,
  });

  /// Strings that can become lookups, in file order.
  final List<HardcodedString> candidates;

  /// The project's gen-l10n settings.
  final L10nConfig config;

  /// Import of the generated localizations class.
  final String importUri;

  /// The project folder.
  final String projectPath;

  /// Strings that cannot become lookups, with their reason, as the
  /// user can find them in the code.
  final Map<HardcodedString, String> rejected;

  /// Strings that cannot become lookups, counted by reason.
  final Map<String, int> skipped;
}
