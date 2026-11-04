import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/models/locale_number.dart';
import 'package:fide/models/project_paths.dart';
import 'package:fide/models/quick_fix.dart';
import 'package:fide/models/string_review.dart';
import 'package:fide/services/arb_key_remover.dart';
import 'package:fide/services/arb_migrator.dart';
import 'package:fide/services/arb_translator.dart';
import 'package:fide/services/chat_model.dart';
import 'package:fide/services/cocoa_pods_migrator.dart';
import 'package:fide/services/code_review.dart';
import 'package:fide/services/project_config_reader.dart';
import 'package:fide/services/project_maintenance_service.dart';
import 'package:fide/services/string_fixer.dart';
import 'package:path/path.dart' as p;

part 'quick_fix_handler.migrate_to_arb_handler.dart';
part 'quick_fix_handler.quick_fix_request.dart';
part 'quick_fix_handler.remove_cocoa_pods_handler.dart';
part 'quick_fix_handler.remove_unused_keys_handler.dart';
part 'quick_fix_handler.sort_members_handler.dart';
part 'quick_fix_handler.string_fix_handler.dart';
part 'quick_fix_handler.translate_keys_handler.dart';
part 'quick_fix_handler.upgrade_packages_handler.dart';

/// Runs one [QuickFix] on a project, from a fresh fCheck analysis; each
/// fix has its own handler, registered by fix in the runner's provider.
abstract interface class QuickFixHandler {
  /// Applies the fix as [request] asks; null when the user cancels
  /// through [QuickFixRequest.confirm].
  Future<QuickFixOutcome?> run(QuickFixRequest request);
}

/// The outcome of a fix with nothing to do, saying so in [summary].
QuickFixOutcome _nothingToDo(String summary) =>
    (summary: summary, changedFiles: const <String>[]);
