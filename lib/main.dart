// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

// Screens
import 'screens/explorer/explorer_screen.dart';
import 'screens/explorer/welcome_screen.dart';
import 'screens/editor/editor_screen.dart';
import 'screens/outline/outline_panel.dart';

// Services
import 'services/file_system_service.dart';

// Theme
import 'theme/app_theme.dart';

// Models
import 'models/file_system_item.dart';
import 'models/project_node.dart';

void main() {
  runApp(const ProviderScope(child: FIDE()));
}

class FIDE extends StatefulWidget {
  const FIDE({super.key});

  @override
  State<FIDE> createState() => _FIDEState();
}

class _FIDEState extends State<FIDE> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FIDE - Flutter Integrated Developer Environment',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      navigatorKey: navigatorKey,
      home: PlatformMenuBar(
        menus: [
          PlatformMenu(
            label: 'File',
            menus: [
              PlatformMenuItem(
                label: 'Settings',
                shortcut: const SingleActivator(
                  LogicalKeyboardKey.comma,
                  meta: true,
                ),
                onSelected: () {
                  _showSettingsDialog(navigatorKey.currentContext ?? context);
                },
              ),
              PlatformMenuItem(
                label: 'Save',
                shortcut: const SingleActivator(
                  LogicalKeyboardKey.keyS,
                  meta: true,
                ),
                onSelected: () {
                  debugPrint('Save triggered');
                },
              ),
              PlatformMenuItemGroup(
                members: [
                  PlatformMenuItem(
                    label: 'Quit FIDE',
                    onSelected: () {
                      SystemNavigator.pop();
                    },
                  ),
                ],
              ),
            ],
          ),
          PlatformMenu(
            label: 'Help',
            menus: [
              PlatformMenuItem(
                label: 'About',
                onSelected: () {
                  showAboutDialog(
                    context: navigatorKey.currentContext ?? context,
                    applicationName: 'FIDE',
                    applicationVersion: '1.0.0',
                    applicationLegalese: '© 2025 FIDE',
                  );
                },
              ),
            ],
          ),
        ],
        child: ProviderScope(
          child: MainLayout(
            onThemeChanged: (themeMode) {
              setState(() => _themeMode = themeMode);
            },
          ),
        ),
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
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
                onTap: () {
                  setState(() => _themeMode = ThemeMode.system);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.brightness_5),
                title: const Text('Light'),
                onTap: () {
                  setState(() => _themeMode = ThemeMode.light);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.brightness_2),
                title: const Text('Dark'),
                onTap: () {
                  setState(() => _themeMode = ThemeMode.dark);
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
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// State management for the selected file
final selectedFileProvider = StateProvider<FileSystemItem?>((ref) => null);

// State management for project loading
final projectLoadedProvider = StateProvider<bool>((ref) => false);

// State management for current project path
final currentProjectPathProvider = StateProvider<String?>((ref) => null);

// State management for current project root
final currentProjectRootProvider = StateProvider<ProjectNode?>((ref) => null);

// File system service provider
final fileSystemServiceProvider = Provider<FileSystemService>(
  (ref) => FileSystemService(),
);

// Theme mode provider
final themeModeProvider = StateProvider<ThemeMode>((ref) {
  // Try to get saved theme mode from shared preferences
  // For now, default to system
  return ThemeMode.system;
});

class MainLayout extends ConsumerStatefulWidget {
  final Function(ThemeMode)? onThemeChanged;

  const MainLayout({super.key, this.onThemeChanged});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  double _explorerWidth = 250.0;
  double _outlineWidth = 200.0;
  final double _minExplorerWidth = 150.0;
  final double _maxExplorerWidth = 500.0;
  final double _minOutlineWidth = 150.0;
  final double _maxOutlineWidth = 400.0;

  // Callback to refresh outline
  VoidCallback? _refreshOutlineCallback;

  @override
  void initState() {
    super.initState();
    // File system service is initialized when first accessed
  }

  // Method to set the outline refresh callback
  void _setOutlineRefreshCallback(VoidCallback callback) {
    _refreshOutlineCallback = callback;
  }

  void _onResize(double delta) {
    setState(() {
      _explorerWidth = (_explorerWidth + delta).clamp(
        _minExplorerWidth,
        _maxExplorerWidth,
      );
    });
  }

  void _onOutlineResize(double delta) {
    setState(() {
      _outlineWidth = (_outlineWidth - delta).clamp(
        _minOutlineWidth,
        _maxOutlineWidth,
      );
    });
  }

  // Method to pick directory - can be called from WelcomeScreen
  Future<void> _pickDirectory() async {
    try {
      final selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory != null) {
        // Validate that this is a Flutter project
        final dir = Directory(selectedDirectory);
        final pubspecFile = File('${dir.path}/pubspec.yaml');
        final libDir = Directory('${dir.path}/lib');

        if (await pubspecFile.exists() && await libDir.exists()) {
          final pubspecContent = await pubspecFile.readAsString();
          if (pubspecContent.contains('flutter:') ||
              pubspecContent.contains('sdk: flutter')) {
            // Load the project
            ref.read(projectLoadedProvider.notifier).state = true;
            ref.read(currentProjectPathProvider.notifier).state =
                selectedDirectory;
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Selected folder is not a valid Flutter project'),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Selected folder is not a valid Flutter project'),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading project: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedFile = ref.watch(selectedFileProvider);
    final projectLoaded = ref.watch(projectLoadedProvider);
    final currentProjectPath = ref.watch(currentProjectPathProvider);

    return Scaffold(
      body: Row(
        children: [
          // Project Explorer Panel - Only show when project is loaded
          if (projectLoaded) ...[
            SizedBox(
              width: _explorerWidth,
              child: ExplorerScreen(
                onFileSelected: (file) {
                  ref.read(selectedFileProvider.notifier).state = file;
                },
                selectedFile: selectedFile,
                onThemeChanged: (themeMode) {
                  ref.read(themeModeProvider.notifier).state = themeMode;
                },
                onProjectLoaded: (loaded) {
                  ref.read(projectLoadedProvider.notifier).state = loaded;
                  if (!loaded) {
                    // Clear the current project path when unloaded
                    ref.read(currentProjectPathProvider.notifier).state = null;
                  }
                },
                initialProjectPath: currentProjectPath,
              ),
            ),

            // Resizable Splitter
            ResizableSplitter(onResize: _onResize),
          ],

          // Main Editor Area
          Expanded(
            child: Row(
              children: [
                // Editor
                Expanded(
                  child: selectedFile != null
                      ? EditorScreen(
                          filePath: selectedFile.path,
                          onContentChanged: _refreshOutlineCallback,
                          onClose: () {
                            ref.read(selectedFileProvider.notifier).state =
                                null;
                          },
                        )
                      : !projectLoaded
                      ? WelcomeScreen(
                          onOpenFolder: _pickDirectory,
                          onCreateProject: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Create new project feature coming soon!',
                                ),
                              ),
                            );
                          },
                        )
                      : const Center(
                          child: Text(
                            'Select a file to start editing',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ),
                ),

                // Outline View
                if (selectedFile != null) ...[
                  // Resizable Splitter between Editor and Outline
                  ResizableSplitter(onResize: _onOutlineResize),
                  SizedBox(
                    width: _outlineWidth,
                    child: OutlinePanel(
                      file: selectedFile,
                      onOutlineUpdate: _setOutlineRefreshCallback,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ResizableSplitter extends StatefulWidget {
  const ResizableSplitter({super.key, required this.onResize});

  final Function(double) onResize;

  @override
  State<ResizableSplitter> createState() => _ResizableSplitterState();
}

class _ResizableSplitterState extends State<ResizableSplitter> {
  bool _isDragging = false;

  bool _isHovering = false;

  double _startX = 0.0;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: _isHovering || _isDragging
          ? SystemMouseCursors.resizeLeftRight
          : MouseCursor.defer,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onHorizontalDragStart: (details) {
          setState(() {
            _isDragging = true;
            _startX = details.globalPosition.dx;
          });
        },
        onHorizontalDragUpdate: (details) {
          if (_isDragging) {
            final delta = details.globalPosition.dx - _startX;
            widget.onResize(delta);
            _startX = details.globalPosition.dx;
          }
        },
        onHorizontalDragEnd: (_) {
          setState(() => _isDragging = false);
        },
        child: Container(
          width: 8,
          color: _isHovering || _isDragging
              ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
              : Colors.transparent,
          child: Center(
            child: Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: _isHovering || _isDragging
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
