import 'package:fide/models/quick_fix.dart';
import 'package:fide/models/string_review.dart';
import 'package:fide/providers/project_lifecycle_providers.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/class_split_service.dart';
import 'package:fide/services/quick_fix_handler.dart';
import 'package:fide/services/quick_fix_runner.dart';
import 'package:fide/services/reference_finder.dart';
import 'package:fide/services/string_fixer.dart';
import 'package:fide/services/string_lookup_passer.dart';
import 'package:fide/services/string_rewriter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Finds where the open project uses a declaration; null while no project
/// is open. Its background analysis stops when the project closes.
final referenceFinderProvider = Provider<ReferenceFinder?>((ref) {
  final projectPath = ref.watch(currentProjectPathProvider);
  if (projectPath == null) return null;
  final finder = ReferenceFinder(
    projectPath: projectPath,
    flutterSdk: ref.read(flutterSdkProvider),
  );
  ref.onDispose(finder.dispose);
  return finder;
});

/// Provides the [StringLookupPasser] behind the Pass a lookup quick fix,
/// resolving the open project; null while no project is open.
final stringLookupPasserProvider = Provider<StringLookupPasser?>((ref) {
  final finder = ref.watch(referenceFinderProvider);
  if (finder == null) return null;
  return StringLookupPasser(
    finder,
    ref.read(l10nGeneratorProvider),
    ref.read(codeFormatterProvider),
  );
});

/// Provides the rewriter of each [StringFix]: a new fix registers its
/// rewriter here. Passing lookups needs an open project.
final stringRewritersProvider = Provider<Map<StringFix, StringRewriter>>((ref) {
  final passer = ref.watch(stringLookupPasserProvider);
  return {
    StringFix.localizeStrings: LocalizeStringsRewriter(
      ref.read(stringLocalizerProvider),
    ),
    if (passer != null) StringFix.passLookup: PassLookupRewriter(passer),
    StringFix.makeConstants: MakeConstantsRewriter(
      ref.read(stringConstantsExtractorProvider),
    ),
  };
});

/// Provides the [StringFixer] reviewing and rewriting hardcoded strings.
final stringFixerProvider = Provider<StringFixer>(
  (ref) => StringFixer(ref.watch(stringRewritersProvider)),
);

/// Provides the handler of each [QuickFix]: a new fix registers its
/// handler here.
final quickFixHandlersProvider = Provider<Map<QuickFix, QuickFixHandler>>((
  ref,
) {
  final strings = ref.watch(stringFixerProvider);
  return {
    for (final fix in StringFix.values)
      fix.quickFix: StringFixHandler(strings, fix),
    QuickFix.migrateToArb: MigrateToArbHandler(ref.read(arbMigratorProvider)),
    QuickFix.removeUnusedKeys: RemoveUnusedKeysHandler(
      ref.read(arbKeyRemoverProvider),
    ),
    QuickFix.sortMembers: SortMembersHandler(ref.read(codeReviewProvider)),
    QuickFix.translateKeys: TranslateKeysHandler(
      ref.read(arbTranslatorProvider),
    ),
    QuickFix.upgradePackages: UpgradePackagesHandler(
      ref.read(projectMaintenanceServiceProvider),
    ),
    QuickFix.removeCocoaPods: RemoveCocoaPodsHandler(
      ref.read(cocoaPodsMigratorProvider),
      ref.read(projectConfigReaderProvider),
    ),
  };
});

/// Provides the [QuickFixRunner] behind the issue dialogs' quick fixes and
/// the AI's `run_quick_fix` hook.
final quickFixRunnerProvider = Provider<QuickFixRunner>(
  (ref) => QuickFixRunner(
    review: ref.read(codeReviewProvider),
    strings: ref.watch(stringFixerProvider),
    handlers: ref.watch(quickFixHandlersProvider),
  ),
);

/// Provides the [ClassSplitService] behind the Organized view's split of
/// files with more than one public class.
final classSplitServiceProvider = Provider<ClassSplitService>(
  (ref) => ClassSplitService(
    ref.read(flutterSdkProvider),
    ref.read(codeFormatterProvider),
  ),
);
