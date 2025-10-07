// ignore_for_file:  use_build_context_synchronously

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:process_run/shell.dart';
import 'package:window_manager/window_manager.dart';

// Providers
import '../providers/app_providers.dart';

// Services
import '../services/ai_service.dart';
import '../services/git_service.dart';

// Utils
import '../utils/message_box.dart';

// Widgets
import '../screens/create_project_screen.dart';

class TitleBar extends ConsumerStatefulWidget {
  final ThemeMode themeMode;
  final Function(ThemeMode)? onThemeChanged;
  final VoidCallback? onToggleLeftPanel;
  final VoidCallback? onToggleBottomPanel;
  final VoidCallback? onToggleRightPanel;
  final bool leftPanelVisible;
  final bool bottomPanelVisible;
  final bool rightPanelVisible;
  final Function(String)? onProjectSwitch;
  final Function(String)? onProjectCreateStart;
  final VoidCallback? onProjectCreateComplete;

  const TitleBar({
    super.key,
    required this.themeMode,
    this.onThemeChanged,
    this.onToggleLeftPanel,
    this.onToggleBottomPanel,
    this.onToggleRightPanel,
    this.leftPanelVisible = true,
    this.bottomPanelVisible = true,
    this.rightPanelVisible = true,
    this.onProjectSwitch,
    this.onProjectCreateStart,
    this.onProjectCreateComplete,
  });

  @override
  ConsumerState<TitleBar> createState() => _TitleBarState();
}

class _TitleBarState extends ConsumerState<TitleBar> {
  final Logger _logger = Logger('_TitleBarState');

  Future<void> _toggleMaximize() async {
    try {
      final isMaximized = await windowManager.isMaximized();
      if (isMaximized) {
        await windowManager.unmaximize();
      } else {
        await windowManager.maximize();
      }
    } catch (e) {
      // Silently handle window manager errors
      _logger.severe('Error toggling window maximize state: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: _toggleMaximize,
      child: Container(
        height: 40,
        color: widget.themeMode == ThemeMode.dark
            ? const Color(0xFF323233) // VS Code dark title bar color
            : const Color(0xFFECECEC), // VS Code light title bar color
        child: Row(
          children: [
            // Platform-specific spacing for window controls
            if (Platform.isMacOS)
              const SizedBox(
                width: 80,
              ), // Space for macOS traffic lights (left side)
            // Left section: Project dropdown or app title
            Consumer(
              builder: (context, ref, child) {
                final currentProjectPath = ref.watch(
                  currentProjectPathProvider,
                );
                final mruFolders = ref.watch(mruFoldersProvider);

                if (currentProjectPath != null) {
                  // Show project dropdown
                  return _buildProjectDropdown(
                    currentProjectPath,
                    mruFolders,
                    ref,
                  );
                } else {
                  // Show app title when no project is loaded
                  return _buildAppTitle();
                }
              },
            ),

            // Center section: Panel toggle buttons
            Expanded(child: Center(child: _buildPanelToggleButtons())),

            // Right section: Settings button
            _buildSettingsButton(),

            // Spacer to push content away from right-side window controls (Windows/Linux)
            if (!Platform.isMacOS) const Spacer(),

            // Space for Windows/Linux window controls (right side)
            if (!Platform.isMacOS) const SizedBox(width: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectDropdown(
    String currentProjectPath,
    List<String> mruFolders,
    WidgetRef ref,
  ) {
    return GestureDetector(
      onTap: () =>
          _showProjectMenu(context, currentProjectPath, mruFolders, ref),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              path.basename(currentProjectPath),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                color: widget.themeMode == ThemeMode.dark
                    ? Colors.white.withValues(alpha: 0.9)
                    : Colors.black.withValues(alpha: 0.9),
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          Icon(
            Icons.arrow_drop_down,
            color: widget.themeMode == ThemeMode.dark
                ? Colors.white.withValues(alpha: 0.7)
                : Colors.black.withValues(alpha: 0.7),
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildAppTitle() {
    return Text(
      'The Flutter IDE',
      style: TextStyle(
        color: widget.themeMode == ThemeMode.dark
            ? Colors.white.withValues(alpha: 0.9)
            : Colors.black.withValues(alpha: 0.9),
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
    );
  }

  Widget _buildPanelToggleButtons() {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Left panel toggle
        IconButton(
          key: const Key('togglePanelLeft'),
          icon: SvgPicture.asset(
            'assets/toggle_panel_left.svg',
            width: 18,
            height: 18,
            colorFilter: ColorFilter.mode(
              widget.leftPanelVisible
                  ? colorScheme.primary
                  : colorScheme.onSurface,
              BlendMode.srcIn,
            ),
          ),
          onPressed: widget.onToggleLeftPanel,
          tooltip: 'Toggle Left Panel',
        ),
        // Bottom panel toggle
        IconButton(
          key: const Key('togglePanelBottom'),
          icon: SvgPicture.asset(
            'assets/toggle_panel_bottom.svg',
            width: 18,
            height: 18,
            colorFilter: ColorFilter.mode(
              widget.bottomPanelVisible
                  ? colorScheme.primary
                  : colorScheme.onSurface,
              BlendMode.srcIn,
            ),
          ),
          onPressed: widget.onToggleBottomPanel,
          tooltip: 'Toggle Bottom Panel',
        ),
        // Right panel toggle
        IconButton(
          key: const Key('togglePanelRight'),
          icon: SvgPicture.asset(
            'assets/toggle_panel_right.svg',
            width: 18,
            height: 18,
            colorFilter: ColorFilter.mode(
              widget.rightPanelVisible
                  ? colorScheme.primary
                  : colorScheme.onSurface,
              BlendMode.srcIn,
            ),
          ),
          onPressed: widget.onToggleRightPanel,
          tooltip: 'Toggle Right Panel',
        ),
      ],
    );
  }

  Widget _buildSettingsButton() {
    return IconButton(
      icon: const Icon(Icons.settings, size: 18),
      onPressed: () {
        _showSettingsDialog();
      },
      tooltip: 'Settings',
      style: IconButton.styleFrom(
        foregroundColor: widget.themeMode == ThemeMode.dark
            ? Colors.white.withValues(alpha: 0.9)
            : Colors.black.withValues(alpha: 0.9),
      ),
    );
  }

  Future<void> _handleDropdownSelection(String value, WidgetRef ref) async {
    final projectManager = ref.read(projectManagerProvider);

    if (value == 'add_folder') {
      // Open folder picker first
      try {
        final selectedDirectory = await FilePicker.platform.getDirectoryPath();
        if (selectedDirectory != null && mounted && context.mounted) {
          // Use the onProjectSwitch callback to load with loading screen
          if (widget.onProjectSwitch != null) {
            await widget.onProjectSwitch!(selectedDirectory);
          } else {
            // Fallback to direct loading if no callback provided
            final success = await projectManager.loadProject(selectedDirectory);
            if (success) {
              await projectManager.tryReopenLastFile(selectedDirectory);
            }
          }
        }
      } catch (e) {
        if (mounted && context.mounted) {
          MessageBox.showError(context, 'Error opening folder: $e');
        }
      }
      return;
    } else if (value == 'create_project') {
      // Show create project dialog using the shared dialog
      final result = await showCreateProjectDialog(context);
      if (result != null) {
        final String projectName = result['name'] as String;
        final String parentDirectory = result['directory'] as String;

        // Notify main app to show loading screen
        widget.onProjectCreateStart?.call(projectName);

        // Clear existing loading actions and add project creation steps
        ref.read(loadingActionsProvider.notifier).state = [];

        try {
          // Use ProjectService to create the project with loading actions
          final projectService = ref.read(projectServiceProvider);
          final success = await _createProjectWithLoadingActions(
            ref,
            projectService,
            projectName,
            parentDirectory,
          );

          if (!success) {
            if (context.mounted) {
              MessageBox.showError(context, 'Failed to create project');
            }
          } else if (result.containsKey('description')) {
            // AI-powered generation: use description to generate app code
            final description = result['description'] as String;
            await _generateProjectFromDescriptionWithActions(
              ref,
              projectService,
              projectName,
              parentDirectory,
              description,
            );
          }
        } finally {
          // Always notify main app to hide loading screen
          widget.onProjectCreateComplete?.call();
        }
      }
      return;
    } else if (value == 'close_project') {
      ref.read(projectLoadedProvider.notifier).state = false;
      ref.read(currentProjectPathProvider.notifier).state = null;
      ref.read(selectedFileProvider.notifier).state = null;
    } else if (value.startsWith('remove_')) {
      final pathToRemove = value.substring(7);
      final updatedMru = List<String>.from(ref.read(mruFoldersProvider))
        ..remove(pathToRemove);
      ref.read(mruFoldersProvider.notifier).state = updatedMru;

      // Save to SharedPreferences
      try {
        final prefs = await ref.read(sharedPreferencesProvider.future);
        await prefs.setStringList('mru_folders', updatedMru);
      } catch (e) {
        // Silently handle SharedPreferences errors
      }
    } else {
      // Use the callback to load project (this will set loading state)
      if (widget.onProjectSwitch != null) {
        await widget.onProjectSwitch!(value);
      } else {
        // Fallback to direct loading if no callback provided
        final success = await projectManager.loadProject(value);
        if (success) {
          await projectManager.tryReopenLastFile(value);
        }
      }
    }
  }

  List<PopupMenuEntry<String>> _buildDropdownMenuItems(
    List<String> mruFolders,
  ) {
    final items = <PopupMenuEntry<String>>[];

    // Add current MRU folders
    for (final folderPath in mruFolders) {
      final dirName = path.basename(folderPath);
      final hasAccess = Directory(folderPath).existsSync();
      items.add(
        PopupMenuItem<String>(
          value: folderPath,
          child: Row(
            children: [
              Icon(
                hasAccess ? Icons.folder : Icons.folder_off,
                color: hasAccess
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.error,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dirName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: hasAccess
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
              if (!hasAccess) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.lock,
                  color: Theme.of(context).colorScheme.error,
                  size: 14,
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (mruFolders.isNotEmpty) {
      items.add(const PopupMenuDivider());
    }

    // Add action items
    items.add(
      PopupMenuItem<String>(
        value: 'add_folder',
        child: Row(
          children: [
            Icon(
              Icons.add,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Open a folder ...',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ],
        ),
      ),
    );

    items.add(
      PopupMenuItem<String>(
        value: 'close_project',
        child: Row(
          children: [
            Icon(
              Icons.close,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Close Project',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ],
        ),
      ),
    );

    items.add(const PopupMenuDivider());

    items.add(
      PopupMenuItem<String>(
        value: 'create_project',
        child: Row(
          children: [
            Icon(
              Icons.create_new_folder,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Create new Project...',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ],
        ),
      ),
    );

    return items;
  }

  void _showProjectMenu(
    BuildContext context,
    String currentProjectPath,
    List<String> mruFolders,
    WidgetRef ref,
  ) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final Offset offset = button.localToGlobal(Offset.zero);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + button.size.height,
        offset.dx + button.size.width,
        offset.dy + button.size.height,
      ),
      items: _buildDropdownMenuItems(mruFolders),
    ).then((value) async {
      if (value != null) {
        await _handleDropdownSelection(value, ref);
      }
    });
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Theme'),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.brightness_auto),
                title: const Text('System'),
                onTap: () async {
                  widget.onThemeChanged?.call(ThemeMode.system);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.brightness_5),
                title: const Text('Light'),
                onTap: () async {
                  widget.onThemeChanged?.call(ThemeMode.light);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.brightness_2),
                title: const Text('Dark'),
                onTap: () async {
                  widget.onThemeChanged?.call(ThemeMode.dark);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  /// Create project with loading actions for progress display
  Future<bool> _createProjectWithLoadingActions(
    WidgetRef ref,
    dynamic projectService,
    String projectName,
    String parentDirectory,
  ) async {
    try {
      final Duration duration = const Duration(milliseconds: 500);
      int step = 1;

      // Check Flutter SDK availability
      _addLoadingAction(ref, step++, 'Validating Flutter SDK');
      if (!await projectService.isFlutterSDKAvailable()) {
        _updateLoadingActionStatus(ref, step - 1, LoadingStatus.failed);
        if (context.mounted) {
          MessageBox.showError(
            context,
            projectService.getFlutterInstallationInstructions(),
          );
        }
        return false;
      }
      _updateLoadingActionStatus(ref, step - 1, LoadingStatus.success);
      await Future.delayed(duration);

      // Create Flutter project
      _addLoadingAction(ref, step++, 'Creating Flutter project structure');
      try {
        final shell = Shell(workingDirectory: parentDirectory);
        final results = await shell.run('flutter create $projectName');

        if (results.isEmpty || results.first.exitCode != 0) {
          _updateLoadingActionStatus(ref, step - 1, LoadingStatus.failed);
          return false;
        }

        _updateLoadingActionStatus(ref, step - 1, LoadingStatus.success);
        await Future.delayed(duration);

        // Initialize Git repository
        _addLoadingAction(ref, step++, 'Initializing Git repository');
        final gitService = GitService();
        await gitService.initRepository(
          path.join(parentDirectory, projectName),
        );

        // Stage initial files and create commit
        await gitService.stageFiles(path.join(parentDirectory, projectName), [
          '.',
        ]);
        await gitService.commit(
          path.join(parentDirectory, projectName),
          'Initial commit: $projectName Flutter project',
        );

        _updateLoadingActionStatus(ref, step - 1, LoadingStatus.success);
        await Future.delayed(duration);

        return true;
      } catch (e) {
        _updateLoadingActionStatus(ref, step - 1, LoadingStatus.failed);
        return false;
      }
    } catch (e) {
      _logger.severe('Error in _createProjectWithLoadingActions: $e');
      return false;
    }
  }

  Future<void> _generateProjectFromDescriptionWithActions(
    WidgetRef ref,
    dynamic projectService,
    String projectName,
    String parentDirectory,
    String description,
  ) async {
    final aiService = AIService();
    final projectPath = path.join(parentDirectory, projectName);
    final mainDartPath = path.join(projectPath, 'lib', 'main.dart');

    try {
      // Show loading dialog
      if (context.mounted) {
        MessageBox.showInfo(context, 'Generating AI-powered Flutter app...');
      }

      // Generate instructions from AI
      final prompt =
          '''
Create a complete Flutter app based on the following description: "$description"

Provide the complete, working Flutter/Dart code for the main.dart file that implements this app.
Make sure the code:
1. Imports the necessary Flutter packages
2. Has a proper MaterialApp or CupertinoApp setup
3. Implements the described functionality
4. Includes proper state management if needed
5. Is properly formatted and follows Dart conventions
6. Can run without additional setup

Only provide the Dart code for main.dart, nothing else.
''';

      final aiResponse = await aiService.getCodeSuggestion(prompt, '');
      if (aiResponse.startsWith('Error:')) {
        if (context.mounted) {
          MessageBox.showError(
            context,
            'Failed to generate app from description: $aiResponse',
          );
        }
        return;
      }

      // Extract code from AI response (remove any markdown formatting if present)
      String generatedCode = aiResponse.trim();
      if (generatedCode.startsWith('```dart')) {
        generatedCode = generatedCode.substring(7);
      }
      if (generatedCode.endsWith('```')) {
        generatedCode = generatedCode.substring(0, generatedCode.length - 3);
      }
      generatedCode = generatedCode.trim();

      // Validate that we have valid Dart code
      if (!generatedCode.contains(
            'import \'package:flutter/material.dart\';',
          ) &&
          !generatedCode.contains('import "package:flutter/material.dart";')) {
        if (context.mounted) {
          MessageBox.showError(
            context,
            'AI generated invalid code. Please try with a more descriptive prompt.',
          );
        }
        return;
      }

      // Update main.dart
      final mainFile = File(mainDartPath);
      await mainFile.writeAsString(generatedCode);

      // Run flutter pub get to ensure dependencies are resolved
      try {
        final shell = Shell(workingDirectory: projectPath);
        await shell.run('flutter pub get');
        _logger.info(
          'Successfully ran flutter pub get for AI-generated project',
        );
      } catch (e) {
        _logger.warning('Failed to run flutter pub get: $e');
      }

      // Try to build the project to validate it works
      try {
        final shell = Shell(workingDirectory: projectPath);
        final result = await shell.run('flutter build --debug');
        if (result.first.exitCode == 0) {
          if (context.mounted) {
            MessageBox.showSuccess(
              context,
              'AI-powered Flutter app created successfully!',
            );
          }
        } else {
          if (context.mounted) {
            MessageBox.showWarning(
              context,
              'App created but may have issues. Please check the code and fix any problems.',
            );
          }
        }
      } catch (e) {
        _logger.warning('Could not validate build: $e');
        if (context.mounted) {
          MessageBox.showWarning(
            context,
            'App created successfully, but build validation failed.',
          );
        }
      }
    } catch (e) {
      _logger.severe('Error generating project from description: $e');
      if (context.mounted) {
        MessageBox.showError(context, 'Failed to generate app: $e');
      }
    }
  }

  void _addLoadingAction(WidgetRef ref, int step, String text) {
    final currentActions = ref.read(loadingActionsProvider);
    final updatedActions = List<LoadingAction>.from(currentActions)
      ..add(LoadingAction(step, text, LoadingStatus.pending));
    ref.read(loadingActionsProvider.notifier).state = updatedActions;
  }

  void _updateLoadingActionStatus(
    WidgetRef ref,
    int step,
    LoadingStatus status,
  ) {
    final currentActions = ref.read(loadingActionsProvider);
    final updatedActions = currentActions.map((action) {
      if (action.step == step) {
        return LoadingAction(action.step, action.text, status);
      }
      return action;
    }).toList();
    ref.read(loadingActionsProvider.notifier).state = updatedActions;
  }
}
