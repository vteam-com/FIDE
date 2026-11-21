import 'package:fide/constants/constants.dart';
import 'package:fide/providers/persisted_notifier.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the editor shows Markdown files rendered rather than as their
/// text, persisted; see [MarkdownPreviewNotifier].
final markdownPreviewProvider =
    StateNotifierProvider<MarkdownPreviewNotifier, bool>(
      (ref) =>
          MarkdownPreviewNotifier(ref.watch(sharedPreferencesProvider.future)),
    );

/// The editor's View as Markdown toggle: one choice for every Markdown
/// file, persisted to preferences, so each file opens the way the user
/// last chose.
class MarkdownPreviewNotifier extends PersistedNotifier<bool> {
  /// Starts showing the text; call [load] to restore the saved choice.
  MarkdownPreviewNotifier(Future<SharedPreferences> prefs)
    : super(prefs, false);

  @override
  bool? read(SharedPreferences prefs) =>
      prefs.getBool(PrefKeys.markdownPreview);

  /// Shows every Markdown file rendered when [preview], else as its text,
  /// and saves the choice for the next launch.
  Future<void> setPreview(bool preview) => persist(preview);

  @override
  Future<void> write(SharedPreferences prefs, bool preview) =>
      prefs.setBool(PrefKeys.markdownPreview, preview);
}
