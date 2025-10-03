import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../utils/message_helper.dart';
import '../screens/main_layout.dart';
import '../panels/center/editor_screen.dart';

/// Service class for project-related operations
class ProjectOperations {
  final Ref ref;

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
            // Keep only the most recent 10
            if (currentMru.length > 10) {
              currentMru.removeRange(10, currentMru.length);
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
            MessageHelper.showError(
              context,
              'Failed to load project. Please ensure it is a valid Flutter project.',
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        MessageHelper.showError(context, 'Error loading project: $e');
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

  static void triggerSearchPrevious() {
    // Call the static method to toggle search in the current editor
    EditorScreen.findPrevious();
  }

  /// Panel visibility trigger functions
  static VoidCallback? _onLeftPanelVisibilityChanged;
  static VoidCallback? _onBottomPanelVisibilityChanged;
  static VoidCallback? _onRightPanelVisibilityChanged;

  static void setVisibilityCallbacks({
    VoidCallback? onLeftPanelVisibilityChanged,
    VoidCallback? onBottomPanelVisibilityChanged,
    VoidCallback? onRightPanelVisibilityChanged,
  }) {
    _onLeftPanelVisibilityChanged = onLeftPanelVisibilityChanged;
    _onBottomPanelVisibilityChanged = onBottomPanelVisibilityChanged;
    _onRightPanelVisibilityChanged = onRightPanelVisibilityChanged;
  }

  static void triggerTogglePanelLeft() {
    // Update visibility state
    _onLeftPanelVisibilityChanged?.call();
  }

  static void triggerTogglePanelBottom() {
    // Update visibility state
    _onBottomPanelVisibilityChanged?.call();
  }

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
      MessageHelper.showError(context, 'Please enter a valid line number');
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
      debugPrint('Error in tryLoadProject: $e');
      return false;
    }
  }
}

final projectOperationsProvider = Provider<ProjectOperations>((ref) {
  return ProjectOperations(ref);
});
