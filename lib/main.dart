import 'dart:async';
import 'dart:io';

import 'package:fide/app_bootstrap.dart';
import 'package:fide/constants/constants.dart';
import 'package:fide/models/app_view_state.dart';
import 'package:fide/models/locale_number.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/app_view_notifier.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/screens/create_project_screen.dart';
import 'package:fide/screens/loading_screen.dart';
import 'package:fide/screens/main_layout.dart';
import 'package:fide/screens/settings_screen.dart';
import 'package:fide/screens/welcome_screen.dart';
import 'package:fide/services/login_shell_environment.dart';
import 'package:fide/theme/app_theme.dart';
import 'package:fide/widget_services/app_command.dart';
import 'package:fide/widget_services/app_title_bar.dart';
import 'package:fide/widget_services/native_menu_builder.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/zoomed_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:logging/logging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LocaleNumber.locale = NumberLocale(Platform.localeName);
  // Read the shell PATH in the background: apps opened from the Dock lack it
  unawaited(LoginShellEnvironment.load());

  // Setup logging
  Logger.root.level = Level.ALL;

  await initializeWindowManager();
  final container = ProviderContainer();

  runApp(UncontrolledProviderScope(container: container, child: const FIDE()));
}

/// Root widget of the FIDE application.
class FIDE extends ConsumerStatefulWidget {
  const FIDE({super.key});

  @override
  ConsumerState<FIDE> createState() => _FIDEState();
}

class _FIDEState extends ConsumerState<FIDE> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  /// Restores the settings and the recent projects, then reopens the most
  /// recent one.
  Future<void> _initializeApp() async {
    await ref.read(themeModeProvider.notifier).load();
    await ref.read(zoomProvider.notifier).load();
    await ref.read(mruFoldersProvider.notifier).load();
    if (mounted) await ref.read(appViewProvider.notifier).openRecentProject();
  }

  @override
  Widget build(BuildContext context) {
    _showErrors(projectOpenErrorProvider, MessageBox.showError);
    _showErrors(
      projectCreationErrorProvider,
      (context, error) => MessageBox.showDetails(
        context,
        title: const Text('Project Creation Error'),
        content: Text(error),
      ),
    );
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'FIDE - Flutter Integrated Developer Environment',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      navigatorKey: navigatorKey,
      // Zooms everything the navigator shows, dialogs included
      builder: (_, child) =>
          ZoomedView(zoom: ref.watch(zoomProvider), child: child!),
      home: Scaffold(
        // Builder so the gradient resolves against the app theme, not the
        // context above MaterialApp
        // The native menu binds each menu shortcut's main key; this binds
        // the aliases.
        // The autofocused Focus routes keys here before any widget has focus
        body: CallbackShortcuts(
          bindings: {
            AppShortcut.quickOpenAlias: _quickOpenFile,
            AppShortcut.zoomInAlias: ref.read(zoomProvider.notifier).zoomIn,
          },
          child: Focus(
            autofocus: true,
            child: Builder(
              builder: (context) => DecoratedBox(
                decoration: AppTheme.workspaceBackground(context),
                child: Column(
                  children: [
                    AppTitleBar(menus: _buildMenus(context)),
                    // Main content with menu bar
                    Expanded(
                      child: PlatformMenuBar(
                        menus: _buildMenus(context),
                        child: Consumer(
                          builder: (_, ref, _) {
                            final view = ref.read(appViewProvider.notifier);
                            final Widget content = switch (ref.watch(
                              appViewProvider,
                            )) {
                              AppViewState.createProject => CreateProjectScreen(
                                onCancel: view.showWelcome,
                                onOpenProject: view.loadProject,
                              ),
                              AppViewState.loadingProject => LoadingScreen(
                                loadingProjectName: view.loadingProjectPath,
                              ),
                              AppViewState.welcome => const WelcomeScreen(),
                              AppViewState.mainLayout => const MainLayout(),
                            };

                            // Settings cover the view, which stays mounted
                            // so closing them returns to it unchanged
                            return Stack(
                              children: [
                                Positioned.fill(child: content),
                                if (ref.watch(settingsVisibleProvider))
                                  Positioned.fill(
                                    child: SettingsScreen(
                                      menus: _buildMenus(context),
                                      onClose: _closeSettings,
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The native menus; [context] must be under the app's navigator.
  List<PlatformMenuItem> _buildMenus(BuildContext context) {
    return NativeMenuBuilder(context: context, ref: ref).buildMenus();
  }

  /// Hides the settings screen.
  void _closeSettings() {
    ref.read(settingsVisibleProvider.notifier).state = false;
  }

  /// Shows the Go to File palette over the loaded project's files.
  void _quickOpenFile() {
    AppCommand.quickOpen.run(navigatorKey.currentContext ?? context, ref);
  }

  /// Shows each message [errors] receives with [show], then clears it, so
  /// the next one shows even when it reads the same.
  void _showErrors(
    StateProvider<String?> errors,
    void Function(BuildContext context, String error) show,
  ) {
    ref.listen(errors, (_, error) {
      final context = navigatorKey.currentContext;
      if (error == null || context == null) return;
      show(context, error);
      ref.read(errors.notifier).state = null;
    });
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
