// ignore: fcheck_dead_code

import 'package:fide/models/constants.dart';
import 'package:fide/panels/center/editor/editor_screen.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/screens/main_layout.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

/// Controller class for project-related UI operations.
class ProjectOperations {
  final Ref ref;

  static final Logger _logger = Logger('ProjectOperations');

  ProjectOperations(this.ref);

  /// Global function to save the current editor
  static void triggerSave() {
    // Call the static method to save the current editor
    EditorScreen.saveCurrentEditor();
  }

  /// Global function for opening folder picker and loading project
  static Future<void> pickDirectoryAndLoadProject(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      final selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory != null && context.mounted) {
        // Use ProjectManager to load the project
        final projectManager = ref.read(projectManagerProvider);
        final success = await projectManager.loadProject(selectedDirectory);

        if (success) {
          await projectManager.tryReopenLastFile(selectedDirectory);

          // Add to MRU folders
          final currentMru = List<String>.from(ref.read(mruFoldersProvider));
          if (!currentMru.contains(selectedDirectory)) {
            currentMru.insert(0, selectedDirectory); // Add to beginning
            // Keep only the most recent configured entries.
            if (currentMru.length > AppMetric.maxMruFolders) {
              currentMru.removeRange(
                AppMetric.maxMruFolders,
                currentMru.length,
              );
            }
            ref.read(mruFoldersProvider.notifier).state = currentMru;

            // Save to SharedPreferences
            try {
              final prefs = await ref.read(sharedPreferencesProvider.future);
              await prefs.setStringList('mru_folders', currentMru);
            } catch (e) {
              // Silently handle SharedPreferences errors
            }
          }
        } else {
          if (context.mounted) {
            MessageBox.showError(
              context,
              'Failed to load project. Please ensure it is a valid Flutter project.',
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        MessageBox.showError(context, 'Error loading project: $e');
      }
    }
  }

  /// Global function for opening folder picker (will be set by MainLayout)
  static Future<void> triggerOpenFolder() async {}

  /// Global function for reopening last file
  static void triggerReopenLastFile() {
    // This will be set by MainLayout
    final GlobalKey<MainLayoutState> mainLayoutKey =
        GlobalKey<MainLayoutState>();
    final currentProjectPath = mainLayoutKey.currentState?.ref.read(
      currentProjectPathProvider,
    );
    if (currentProjectPath != null) {
      mainLayoutKey.currentState?.tryReopenLastFile(currentProjectPath);
    }
  }

  /// Global function to close document
  static void triggerCloseDocument() {
    // Call the static method to close the current editor
    EditorScreen.closeCurrentEditor();
  }

  /// Global function to toggle search
  static void triggerSearch() {
    // Call the static method to toggle search in the current editor
    EditorScreen.toggleSearch();
  }

  /// Global functions for find next/previous
  static void triggerSearchNext() {
    // Call the static method to toggle search in the current editor
    EditorScreen.findNext();
  }

  /// Triggers navigation to the previous search match in the active editor.
  static void triggerSearchPrevious() {
    // Call the static method to toggle search in the current editor
    EditorScreen.findPrevious();
  }

  /// Panel visibility trigger functions
  static VoidCallback? _onLeftPanelVisibilityChanged;
  static VoidCallback? _onBottomPanelVisibilityChanged;
  static VoidCallback? _onRightPanelVisibilityChanged;

  /// Toggles visibility of the left panel through the registered callback.
  static void triggerTogglePanelLeft() {
    // Update visibility state
    _onLeftPanelVisibilityChanged?.call();
  }

  /// Toggles visibility of the bottom panel through the registered callback.
  static void triggerTogglePanelBottom() {
    // Update visibility state
    _onBottomPanelVisibilityChanged?.call();
  }

  /// Toggles visibility of the right panel through the registered callback.
  static void triggerTogglePanelRight() {
    // Update visibility state
    _onRightPanelVisibilityChanged?.call();
  }

  /// Handle Go to Line action
  static Future<void> handleGotoLine(String value, BuildContext context) async {
    if (value.isEmpty) return;

    final lineNumber = int.tryParse(value);
    if (lineNumber != null && lineNumber > 0) {
      // Navigate to the line
      EditorScreen.navigateToLine(lineNumber);
      Navigator.of(context).pop();
    } else {
      // Show error for invalid input
      MessageBox.showError(context, 'Please enter a valid line number');
    }
  }

  /// Show Go to Line dialog
  static void showGotoLineDialog(BuildContext context) {
    final TextEditingController lineController = TextEditingController();
    final FocusNode focusNode = FocusNode();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Go to Line'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: lineController,
                focusNode: focusNode,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Line number',
                  hintText: 'Enter line number',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (value) {
                  handleGotoLine(value, context);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                handleGotoLine(lineController.text, context);
              },
              child: const Text('Go'),
            ),
          ],
        );
      },
    );

    // Focus the text field when dialog opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusNode.requestFocus();
    });
  }

  /// Try to load a project (used by WelcomeScreen and TitleBar)
  static Future<bool> tryLoadProject(String directoryPath) async {
    try {
      // This will be called from within the widget context
      // We'll need to get the ref from wherever this is called
      throw UnimplementedError(
        'This method should be called with a ref parameter',
      );
    } catch (e) {
      _logger.severe('Error in tryLoadProject: $e');
      return false;
    }
  }
}

final projectOperationsProvider = Provider<ProjectOperations>((ref) {
  return ProjectOperations(ref);
});
