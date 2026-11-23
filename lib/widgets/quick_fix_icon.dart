import 'package:fide/models/quick_fix.dart';
import 'package:material_ui/material_ui.dart';

/// The glyph of a [QuickFix]'s button.
extension QuickFixIcon on QuickFix {
  /// Glyph of the fix's button.
  IconData get icon => switch (this) {
    QuickFix.localizeStrings => Icons.translate,
    QuickFix.passLookup => Icons.input,
    QuickFix.migrateToArb => Icons.drive_file_move_outline,
    QuickFix.makeConstants => Icons.data_object,
    QuickFix.removeUnusedKeys => Icons.delete_sweep_outlined,
    QuickFix.sortMembers => Icons.sort,
    QuickFix.splitClasses => Icons.call_split,
    QuickFix.fixStates => Icons.merge,
    QuickFix.upgradePackages => Icons.arrow_upward,
    QuickFix.removeCocoaPods => Icons.delete_outline,
    QuickFix.translateKeys => Icons.g_translate,
  };
}
