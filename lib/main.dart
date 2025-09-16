// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Providers
import 'providers/app_providers.dart';

// Widgets
import 'widgets/main_layout.dart';

// Screens
import 'screens/editor_screen.dart';

// Services
import 'services/git_service.dart';

// Theme
import 'theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: FIDE()));
}

class FIDE extends ConsumerStatefulWidget {
  const FIDE({super.key});

  @override
  ConsumerState<FIDE> createState() => _FIDEState();
}

// Global functions for menu actions
void triggerSave() {
  // Call the static method to save the current editor
  EditorScreen.saveCurrentEditor();
}

void triggerOpenFolder() {
  // This will be set by MainLayout
  _mainLayoutKey.currentState?.pickDirectory();
}

void triggerReopenLastFile() {
  // This will be set by MainLayout
  _mainLayoutKey.currentState?.tryReopenLastFile(
    _mainLayoutKey.currentState?.mruFolders.first ?? '',
  );
}

void triggerCloseDocument() {
  // Call the static method to close the current editor
  EditorScreen.closeCurrentEditor();
}

// Global key to access MainLayout
final GlobalKey<MainLayoutState> _mainLayoutKey = GlobalKey<MainLayoutState>();

class _FIDEState extends ConsumerState<FIDE> {
  ThemeMode _themeMode = ThemeMode.system;
  String? _lastOpenedFileName;
  late SharedPreferences _prefs;
  static const String _themeModeKey = 'theme_mode';

  @override
  void initState() {
    super.initState();
    _initializeTheme();
  }

  Future<void> _initializeTheme() async {
    _prefs = await SharedPreferences.getInstance();
    final savedThemeMode = _prefs.getString(_themeModeKey);
    if (savedThemeMode != null) {
      setState(() {
        _themeMode = _parseThemeMode(savedThemeMode);
      });
    }
  }

  ThemeMode _parseThemeMode(String themeString) {
    switch (themeString) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  Future<void> _saveThemeMode(ThemeMode themeMode) async {
    final themeString = themeMode.name; // 'light', 'dark', or 'system'
    await _prefs.setString(_themeModeKey, themeString);
  }

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
                  triggerSave();
                },
              ),
              PlatformMenuItem(
                label: 'Close Document',
                shortcut: const SingleActivator(
                  LogicalKeyboardKey.keyW,
                  meta: true,
                ),
                onSelected: () {
                  triggerCloseDocument();
                },
              ),
              PlatformMenuItemGroup(
                members: [
                  PlatformMenuItem(
                    label: 'Quit FIDE',
                    shortcut: const SingleActivator(
                      LogicalKeyboardKey.keyQ,
                      meta: true,
                    ),

                    onSelected: () {
                      SystemNavigator.pop();
                    },
                  ),
                ],
              ),
            ],
          ),
          PlatformMenu(
            label: 'File',
            menus: [
              PlatformMenuItem(
                label: 'Open folder',
                onSelected: () async {
                  triggerOpenFolder();
                },
              ),
              PlatformMenuItem(
                label: _getLastOpenedFileLabel(),
                shortcut: const SingleActivator(
                  LogicalKeyboardKey.keyR,
                  meta: true,
                  shift: true,
                ),
                onSelected: () {
                  triggerReopenLastFile();
                },
              ),
            ],
          ),
          PlatformMenu(
            label: 'Git',
            menus: [
              PlatformMenuItem(
                label: 'Initialize Repository',
                onSelected: () async {
                  final currentPath = ref.read(currentProjectPathProvider);
                  if (currentPath != null) {
                    final gitService = GitService();
                    final result = await gitService.initRepository(currentPath);
                    if (navigatorKey.currentContext != null) {
                      ScaffoldMessenger.of(
                        navigatorKey.currentContext!,
                      ).showSnackBar(SnackBar(content: Text(result)));
                    }
                  }
                },
              ),
              PlatformMenuItem(
                label: 'Refresh Status',
                shortcut: const SingleActivator(
                  LogicalKeyboardKey.keyR,
                  meta: true,
                  shift: true,
                ),
                onSelected: () {
                  // This will be handled by the Git panel refresh
                },
              ),
            ],
          ),
          PlatformMenu(
            label: 'Edit',
            menus: [
              PlatformMenuItem(
                label: 'Go to Line',
                shortcut: const SingleActivator(
                  LogicalKeyboardKey.keyG,
                  control: true,
                ),
                onSelected: () {
                  _showGotoLineDialog(navigatorKey.currentContext ?? context);
                },
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
        child: MainLayout(
          key: _mainLayoutKey,
          onThemeChanged: (themeMode) {
            setState(() => _themeMode = themeMode);
          },
          onFileOpened: (fileName) {
            setState(() => _lastOpenedFileName = fileName);
          },
        ),
      ),
    );
  }

  void _handleGotoLine(String value, BuildContext context) {
    if (value.isEmpty) return;

    final lineNumber = int.tryParse(value);
    if (lineNumber != null && lineNumber > 0) {
      // Navigate to the line
      EditorScreen.navigateToLine(lineNumber);
      Navigator.of(context).pop();
    } else {
      // Show error for invalid input
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid line number'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showGotoLineDialog(BuildContext context) {
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
                  _handleGotoLine(value, context);
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
                _handleGotoLine(lineController.text, context);
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
                onTap: () async {
                  setState(() => _themeMode = ThemeMode.system);
                  await _saveThemeMode(ThemeMode.system);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.brightness_5),
                title: const Text('Light'),
                onTap: () async {
                  setState(() => _themeMode = ThemeMode.light);
                  await _saveThemeMode(ThemeMode.light);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.brightness_2),
                title: const Text('Dark'),
                onTap: () async {
                  setState(() => _themeMode = ThemeMode.dark);
                  await _saveThemeMode(ThemeMode.dark);
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

  String _getLastOpenedFileLabel() {
    // Use the state variable that gets updated when files are opened
    if (_lastOpenedFileName != null) {
      return 'Last file opened: $_lastOpenedFileName';
    }
    return 'No file opened';
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
