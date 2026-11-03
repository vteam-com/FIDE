import 'package:fide/constants/constants.dart';
import 'package:fide/providers/persisted_notifier.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Recently opened project folders, newest first; see [MruFoldersNotifier].
final mruFoldersProvider =
    StateNotifierProvider<MruFoldersNotifier, List<String>>(
      (ref) => MruFoldersNotifier(
        ref.watch(sharedPreferencesProvider.future),
        folderExists: ref.read(fileEntryServiceProvider).folderExists,
      ),
    );

/// The recent project folders that exist, recomputed only when the list
/// changes rather than on every build that shows them.
final accessibleMruFoldersProvider = Provider<Set<String>>(
  (ref) => {
    for (final folder in ref.watch(mruFoldersProvider))
      if (ref.read(fileEntryServiceProvider).folderExists(folder)) folder,
  },
);

/// Recently opened project folders, newest first, persisted to preferences.
///
/// The only writer of [PrefKeys.mruFolders]; every screen that lists or
/// edits recent projects goes through it.
class MruFoldersNotifier extends PersistedNotifier<List<String>> {
  /// Creates an empty list; call [load] to restore the saved one, dropping
  /// the folders [_folderExists] no longer finds.
  MruFoldersNotifier(
    Future<SharedPreferences> prefs, {
    required this._folderExists,
  }) : super(prefs, const []);

  /// Whether a saved folder still exists on disk.
  final bool Function(String folderPath) _folderExists;

  @override
  List<String> read(SharedPreferences prefs) =>
      (prefs.getStringList(PrefKeys.mruFolders) ?? const [])
          .where(_folderExists)
          .toList();

  /// Removes [path] from the list.
  Future<void> remove(String path) =>
      persist(state.where((folder) => folder != path).toList());

  /// Moves [path] to the front, keeping at most `AppMetric.mruFolderLimit`.
  Future<void> touch(String path) => persist(
    [
      path,
      ...state.where((folder) => folder != path),
    ].take(AppMetric.mruFolderLimit).toList(),
  );

  @override
  Future<void> write(SharedPreferences prefs, List<String> folders) =>
      prefs.setStringList(PrefKeys.mruFolders, folders);
}
