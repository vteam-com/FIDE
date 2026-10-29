import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/providers/active_editor.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  ref.read(selectedFileProvider.notifier).state =
      FileSystemItem.fromFileSystemEntity(File(filePath));
  await Future.delayed(AppDuration.editorScroll);
  editor.navigateToLine(line, column: column);
}
