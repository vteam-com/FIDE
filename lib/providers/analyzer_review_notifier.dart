import 'package:fide/constants/constants.dart';
import 'package:fide/models/analyzer_review.dart';
import 'package:fide/providers/persisted_notifier.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which review the Analyzer tab shows, persisted; see
/// [AnalyzerReviewNotifier].
final analyzerReviewProvider =
    StateNotifierProvider<AnalyzerReviewNotifier, AnalyzerReview>(
      (ref) =>
          AnalyzerReviewNotifier(ref.watch(sharedPreferencesProvider.future)),
    );

/// The Analyzer tab's File Layout or Repeated Widget Settings choice,
/// persisted to preferences.
class AnalyzerReviewNotifier extends PersistedEnumNotifier<AnalyzerReview> {
  /// Starts on the File Layout; call [load] to restore the saved choice.
  AnalyzerReviewNotifier(Future<SharedPreferences> prefs)
    : super(
        prefs,
        AnalyzerReview.layout,
        PrefKeys.analyzerReview,
        AnalyzerReview.values,
      );
}
