import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Screens
import 'screens/explorer/explorer_screen.dart';
import 'screens/editor/editor_screen.dart';
import 'screens/outline/outline_panel.dart';

// Services
import 'services/file_system_service.dart';

// Theme
import 'theme/app_theme.dart';

// Models
import 'models/file_system_item.dart';

void main() {
  runApp(const ProviderScope(child: FIDE()));
}

class FIDE extends StatelessWidget {
  const FIDE({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FIDE - Flutter Integrated Developer Environment',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const MainLayout(),
    );
  }
}

// State management for the selected file
final selectedFileProvider = StateProvider<FileSystemItem?>((ref) => null);

// File system service provider
final fileSystemServiceProvider = Provider<FileSystemService>(
  (ref) => FileSystemService(),
);

class MainLayout extends ConsumerStatefulWidget {
  const MainLayout({super.key});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  final double _explorerWidth = 250.0;
  final double _outlineWidth = 200.0;

  @override
  void initState() {
    super.initState();
    // File system service is initialized when first accessed
  }

  @override
  Widget build(BuildContext context) {
    final selectedFile = ref.watch(selectedFileProvider);

    return Scaffold(
      body: Row(
        children: [
          // Project Explorer Panel
          SizedBox(
            width: _explorerWidth,
            child: ExplorerScreen(
              onFileSelected: (file) {
                ref.read(selectedFileProvider.notifier).state = file;
              },
            ),
          ),

          // Vertical divider
          const VerticalDivider(width: 1, thickness: 1),

          // Main Editor Area
          Expanded(
            child: Column(
              children: [
                // Toolbar
                Container(
                  height: 40,
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.menu, size: 20),
                        onPressed: () {
                          // Toggle explorer panel
                        },
                      ),
                      const Spacer(),
                      if (selectedFile != null)
                        Text(
                          selectedFile.name,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () {
                          ref.read(selectedFileProvider.notifier).state = null;
                        },
                      ),
                    ],
                  ),
                ),

                // Editor and Outline
                Expanded(
                  child: Row(
                    children: [
                      // Editor
                      Expanded(
                        child: selectedFile != null
                            ? EditorScreen(filePath: selectedFile.path)
                            : const Center(child: Text('No file selected')),
                      ),

                      // Outline View
                      if (selectedFile != null) ...[
                        const VerticalDivider(width: 1, thickness: 1),
                        SizedBox(
                          width: _outlineWidth,
                          child: OutlinePanel(file: selectedFile),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
