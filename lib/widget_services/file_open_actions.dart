import 'package:fide/models/project_files.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/editor_navigation.dart';
import 'package:fide/widgets/quick_open_dialog.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Go to File: shows the palette over the loaded project's files, open
/// tabs first, and opens the chosen one; does nothing without a project.
Future<void> quickOpenFile(BuildContext context, WidgetRef ref) async {
  final root = ref.read(currentProjectRootProvider);
  if (root == null) return;

  // Open tabs first, the way VS Code lists recently opened files first
  final openFiles = {
    for (final document in ref.read(openDocumentsProvider).documents)
      document.filePath,
  };
  final projectFiles = ProjectFiles.under(root);
  final chosen = await QuickOpenDialog.show(
    context,
    rootPath: root.path,
    files: [
      ...projectFiles.where(openFiles.contains),
      ...projectFiles.where((file) => !openFiles.contains(file)),
    ],
  );
  if (chosen != null) openFile(ref, chosen);
}

/// Open File: picks any file with the platform's file dialog, starting in
/// the project folder, and opens it; does nothing without a project.
Future<void> pickAndOpenFile(WidgetRef ref) async {
  final projectPath = ref.read(currentProjectPathProvider);
  if (projectPath == null) return;

  final picked = await FilePicker.pickFile(
    dialogTitle: 'Open File',
    initialDirectory: projectPath,
  );
  final path = picked?.path;
  if (path != null) openFile(ref, path);
}
