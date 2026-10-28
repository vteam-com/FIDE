part of 'app_providers.dart';

/// Recently opened project folders, newest first, persisted to preferences.
///
/// The only writer of [PrefKeys.mruFolders]; every screen that lists or
/// edits recent projects goes through it.
class MruFoldersNotifier extends StateNotifier<List<String>> {
  final Ref _ref;

  /// Creates an empty list; call [load] to restore the saved one.
  MruFoldersNotifier(this._ref) : super(const []);

  /// Restores the saved list, dropping folders that no longer exist.
  Future<void> load() async {
    final prefs = await _ref.read(sharedPreferencesProvider.future);
    final saved = prefs.getStringList(PrefKeys.mruFolders) ?? const [];
    state = saved.where((path) => Directory(path).existsSync()).toList();
  }

  /// Removes [path] from the list.
  Future<void> remove(String path) {
    return _save(state.where((folder) => folder != path).toList());
  }

  /// Moves [path] to the front, keeping at most `AppMetric.mruFolderLimit`.
  Future<void> touch(String path) {
    return _save(
      [
        path,
        ...state.where((folder) => folder != path),
      ].take(AppMetric.mruFolderLimit).toList(),
    );
  }

  Future<void> _save(List<String> folders) async {
    state = folders;
    try {
      final prefs = await _ref.read(sharedPreferencesProvider.future);
      await prefs.setStringList(PrefKeys.mruFolders, folders);
    } catch (_) {
      // Silently handle SharedPreferences errors
    }
  }
}
