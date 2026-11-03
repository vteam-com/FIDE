import 'package:fide/constants/constants.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/providers/active_editor.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/center_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens [filePath] in the editor.
void openFile(WidgetRef ref, String filePath) {
  ref.read(selectedFileProvider.notifier).state = FileSystemItem.fromPath(
    filePath,
  );
}

/// Opens [filePath] in the editor from the center view showing, which
/// closing the file returns to; the view closes even when the file was
/// already the active one.
void openFromCenterView(WidgetRef ref, String filePath) {
  if (ref.read(centerViewProvider) case final view?) {
    ref.read(centerViewOpenedFileProvider.notifier).state = (
      view: view,
      path: filePath,
    );
  }
  ref.read(centerViewProvider.notifier).state = null;
  openFile(ref, filePath);
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
