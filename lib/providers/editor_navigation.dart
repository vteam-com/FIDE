import 'package:fide/constants/constants.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/models/search_result.dart';
import 'package:fide/providers/active_editor.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/center_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens [filePath] in the editor: see [openItem].
void openFile(WidgetRef ref, String filePath) =>
    openItem(ref, FileSystemItem.fromPath(filePath));

/// Opens [item] in the editor, the one way to open a file, from any panel:
/// closes the center view showing, which closing the file returns to,
/// even when the file was already the active one.
void openItem(WidgetRef ref, FileSystemItem item) {
  if (ref.read(centerViewProvider) case final view?) {
    ref.read(centerViewOpenedFileProvider.notifier).state = (
      view: view,
      path: item.path,
    );
  }
  ref.read(centerViewProvider.notifier).state = null;
  ref.read(selectedFileProvider.notifier).state = item;
}

/// Opens [filePath] in the editor and moves the caret to 1-based [line]
/// and [column].
Future<void> openFileAtLine(
  WidgetRef ref,
  String filePath,
  int line, {
  int column = 1,
}) async {
  // Read before the pause: the calling widget may be gone after it
  final editor = ref.read(activeEditorProvider);
  openFile(ref, filePath);
  await Future.delayed(AppDuration.editorScroll);
  editor.navigateToLine(line, column: column);
}

/// Opens the file of [place] (a search match, a caller, a callee, a
/// definition) with the caret on the name it marks.
Future<void> openPlace(WidgetRef ref, SearchResult place) => openFileAtLine(
  ref,
  place.filePath,
  place.lineNumber,
  column: place.matchStart + 1,
);

/// Opens [filePath] in the editor showing its changes since the last
/// commit, the one diff view, wherever it is asked for.
Future<void> openFileDiff(WidgetRef ref, String filePath) async {
  // Read before the pause: the calling widget may be gone after it
  final editor = ref.read(activeEditorProvider);
  openFile(ref, filePath);
  await Future.delayed(AppDuration.editorScroll);
  editor.showDiff();
}
