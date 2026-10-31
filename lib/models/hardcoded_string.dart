import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/models/arb_message.dart';

/// A hardcoded string FIDE can rewrite in place, as a localized lookup or
/// a named constant: where it is, its ARB message, and its role.
class HardcodedString {
  /// Creates the string at [site], on 1-based [line] of the file at [path].
  HardcodedString({required this.path, required this.line, required this.site})
    : message = ArbMessage.fromSite(site);

  /// 1-based line of the string.
  final int line;

  /// The string as an ARB message.
  final ArbMessage message;

  /// Absolute path of the file.
  final String path;

  /// Where fCheck found the string.
  final fcheck.HardcodedStringSite site;

  /// What the string is for, judged by fCheck from how the code uses it.
  fcheck.HardcodedStringRole get role => site.role;

  /// The use that decided [role], such as `photoType → Text(…)`.
  String get evidence => site.roleEvidence;

  /// The same string found again, such as by another fix's plan.
  @override
  bool operator ==(Object other) =>
      other is HardcodedString &&
      other.path == path &&
      other.site.offset == site.offset;

  @override
  int get hashCode => Object.hash(path, site.offset);
}
