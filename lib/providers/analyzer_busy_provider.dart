import 'package:fide/providers/file_layout_review_provider.dart';
import 'package:fide/providers/follow_busy.dart';
import 'package:fide/providers/repeated_settings_review_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the File Layout review runs, without starting it.
final _layoutBusyProvider = followBusy(
  fileLayoutReviewProvider,
  (review) => review.isLoading,
);

/// Whether the Repeated Widget Settings review runs, without starting it.
final _repeatedBusyProvider = followBusy(
  repeatedSettingsReviewProvider,
  (review) => review.isLoading,
);

/// Whether either of the Analyzer tab's reviews runs. The tab rings its
/// icon meanwhile, so it shows from the other tabs, never starting a
/// review itself.
final analyzerBusyProvider = Provider<bool>(
  (ref) => ref.watch(_layoutBusyProvider) || ref.watch(_repeatedBusyProvider),
);
