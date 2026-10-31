import 'package:fide/models/locale_number.dart';

/// What moving a project's Dart-written translations into ARB files did.
class ArbMigration {
  /// Creates the outcome.
  const ArbMigration({
    required this.keys,
    required this.locales,
    required this.movedCode,
    required this.changedFiles,
  });

  /// Absolute paths of the Dart files that now import the moved code.
  final List<String> changedFiles;

  /// Keys written to the template ARB file.
  final int keys;

  /// Locales with an ARB file written.
  final List<String> locales;

  /// Hand-written members moved out of the generated file.
  final List<String> movedCode;

  /// One line for the user.
  String get summary {
    final moved = movedCode.isEmpty
        ? ''
        : '; moved ${movedCode.join(', ')} to their own file and updated '
              '${changedFiles.length.localized} files';
    return 'Migrated ${keys.localized} keys in ${locales.join(', ')} to ARB'
        '$moved';
  }
}
