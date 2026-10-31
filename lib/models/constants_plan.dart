import 'package:fide/models/hardcoded_string.dart';

/// What making a project's hardcoded strings constants would do, for the
/// user to review: the strings that can become constants, the class they
/// go to, and why the others cannot.
class ConstantsPlan {
  /// Creates the plan for strings going to [className] in [constantsPath].
  const ConstantsPlan({
    required this.className,
    required this.constantsPath,
    required this.importUri,
    required this.candidates,
    this.rejected = const {},
    required this.skipped,
  });

  /// Strings that can become constants, in file order.
  final List<HardcodedString> candidates;

  /// The class holding the constants.
  final String className;

  /// Absolute path of the file declaring [className].
  final String constantsPath;

  /// Import of [constantsPath].
  final String importUri;

  /// Strings that cannot become constants, with their reason, as the
  /// user can find them in the code.
  final Map<HardcodedString, String> rejected;

  /// Strings that cannot become constants, counted by reason.
  final Map<String, int> skipped;
}
