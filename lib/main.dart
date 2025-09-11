// ignore_for_file: deprecated_member_use

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

          // Resizable Splitter
          ResizableSplitter(onResize: _onResize),

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
                            ? EditorScreen(
                                filePath: selectedFile.path,
                                onContentChanged: _refreshOutlineCallback,
                              )
                            : const Center(child: Text('No file selected')),
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
          ),
        ],
      ),
    );
  }
}

class ResizableSplitter extends StatefulWidget {
  final Function(double) onResize;

  const ResizableSplitter({super.key, required this.onResize});

  @override
  State<ResizableSplitter> createState() => _ResizableSplitterState();
}

class _ResizableSplitterState extends State<ResizableSplitter> {
  bool _isHovering = false;
  bool _isDragging = false;
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
