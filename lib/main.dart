import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Screens
import 'screens/explorer/explorer_screen.dart';
import 'screens/editor/editor_screen.dart';

// Theme
import 'theme/app_theme.dart';

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

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  final List<Widget> _screens = [
    const ExplorerScreen(onFileSelected: null), // Will be replaced in initState
    const EditorScreen(),
    const Center(child: Text('Terminal')),
    const Center(child: Text('Debug')),
  ];

  @override
  void initState() {
    super.initState();
    // Replace the explorer screen with one that has the callback
    _screens[0] = ExplorerScreen(
      onFileSelected: () {
        setState(() => _selectedIndex = 1);
        _pageController.jumpToPage(1);
      },
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
              _pageController.jumpToPage(index);
            },
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.all(8.0),
              child: FlutterLogo(size: 40),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.folder),
                label: Text('Explorer'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.code),
                label: Text('Editor'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.terminal),
                label: Text('Terminal'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.bug_report),
                label: Text('Debug'),
              ),
            ],
          ),
          // Main content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: _screens,
            ),
          ),
        ],
      ),
    );
  }
}
