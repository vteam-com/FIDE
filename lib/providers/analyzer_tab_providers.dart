import 'package:fide/providers/file_layout_review_provider.dart';
import 'package:fide/providers/follow_busy.dart';
import 'package:fide/providers/repeated_settings_review_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the File Layout review runs, without starting it.
final _layoutBusyProvider = followBusy(
  fileLayoutReviewProvider,
  (review) => review.isLoading,
);

/// How many files the File Layout review moves, without starting it:
/// zero until it has run.
final _layoutMovesProvider = follow(
  fileLayoutReviewProvider,
  (review) => review.value?.moves.length ?? 0,
  none: 0,
);

/// Whether the Repeated Widget Settings review runs, without starting it.
final _repeatedBusyProvider = followBusy(
  repeatedSettingsReviewProvider,
  (review) => review.isLoading,
);

/// How many repeated settings the Repeated Widget Settings review found,
/// without starting it: zero until it has run.
final _repeatedFindingsProvider = follow(
  repeatedSettingsReviewProvider,
  (review) => review.value?.findings.length ?? 0,
  none: 0,
);

/// Whether either of the Analyzer tab's reviews runs. The tab rings its
/// icon meanwhile, so it shows from the other tabs, never starting a
/// review itself.
final analyzerBusyProvider = Provider<bool>(
  (ref) => ref.watch(_layoutBusyProvider) || ref.watch(_repeatedBusyProvider),
);

/// How many changes the Analyzer tab's reviews found, files to move and
/// repeated widget settings, as their headers count them: the tab's
/// badge. Never starting a review itself, it counts those the tab has
/// run, kept current as they run again once saves pause.
final analyzerFindingCountProvider = Provider<int>(
  (ref) =>
      ref.watch(_layoutMovesProvider) + ref.watch(_repeatedFindingsProvider),
);
