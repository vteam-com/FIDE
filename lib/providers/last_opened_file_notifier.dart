import 'package:fide/constants/constants.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/providers/persisted_notifier.dart';
import 'package:fide/providers/project_lifecycle_providers.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/file_content_reader.dart';
import 'package:fide/services/file_type_utils.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// The file last opened in the editor; see [LastOpenedFileNotifier].
final lastOpenedFileProvider =
    StateNotifierProvider<LastOpenedFileNotifier, String?>(
      (ref) => LastOpenedFileNotifier(
        ref.watch(sharedPreferencesProvider.future),
        reader: ref.read(fileContentReaderProvider),
        select: (file) => ref.read(selectedFileProvider.notifier).state = file,
      ),
    );

/// The absolute path of the file last opened in the editor, persisted so
/// the project reopens on it next time.
class LastOpenedFileNotifier extends PersistedNotifier<String?> {
  /// Starts with no file; [save] records each file opened and [tryReopen]
  /// restores the saved one, checking it with [_reader] and showing it
  /// through [_select].
  LastOpenedFileNotifier(
    Future<SharedPreferences> prefs, {
    required this._reader,
    required this._select,
  }) : super(prefs, null);

  /// Checks that the saved file exists and the editor can show it.
  final FileContentReader _reader;

  /// Shows the reopened file in the editor.
  final void Function(FileSystemItem file) _select;

  @override
  String? read(SharedPreferences prefs) =>
      prefs.getString(PrefKeys.lastOpenedFile);

  /// Remembers [filePath] so [tryReopen] can restore it next time.
  Future<void> save(String filePath) => persist(filePath);

  /// Opens the saved file again when it is still in the project at
  /// [projectPath], exists, and the editor can show it.
  Future<void> tryReopen(String projectPath) async {
    try {
      await load();
      final filePath = state;
      if (filePath == null ||
          filePath.isEmpty ||
          !p.isWithin(projectPath, filePath) ||
          !FileTypeUtils.isFileSupportedInEditor(filePath) ||
          !await _reader.exists(filePath) ||
          !await _reader.isWithinMaxSize(filePath)) {
        return;
      }
      _select(FileSystemItem.fromPath(filePath));
    } catch (_) {
      // Reopening is a convenience: the project opens without it
    }
  }

  @override
  Future<void> write(SharedPreferences prefs, String? filePath) =>
      prefs.setString(PrefKeys.lastOpenedFile, filePath ?? '');
}
