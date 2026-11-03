// ignore: fcheck_dead_code
import 'package:fide/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Sizes, centres and shows the main window with a hidden title bar; for
/// `main()`, before the widgets, and the integration tests.
Future<void> initializeWindowManager() async {
  WidgetsFlutterBinding.ensureInitialized();

  final window = WindowManager.instance.getCurrent();
  if (window == null) {
    return;
  }
  window
    ..titleBarStyle = TitleBarStyle.hidden
    // The hidden style also hides the window buttons; keep them
    ..isWindowControlButtonsVisible = true
    ..backgroundColor = Colors.transparent.toNative()
    ..setSize(AppSize.initialWindowSize.toNative(), false)
    ..minimumSize = AppSize.minWindowSize.toNative()
    ..center()
    ..show()
    ..focus()
    // Leaving full screen hides the window buttons again; bring them back
    ..addListener((event) {
      if (event is WindowExitedFullScreenEvent) {
        window.isWindowControlButtonsVisible = true;
      }
    });
}
