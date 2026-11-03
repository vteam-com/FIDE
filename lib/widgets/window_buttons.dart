import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// The minimize, maximize (or restore) and close buttons of the window, for
/// platforms whose hidden title bar drops the native ones, such as Linux.
class WindowButtons extends StatefulWidget {
  /// Creates the buttons acting on the current window.
  const WindowButtons({super.key});

  @override
  State<WindowButtons> createState() => _WindowButtonsState();
}

class _WindowButtonsState extends State<WindowButtons> {
/// Whether the window fills the screen, the maximize button restoring it.
  bool _isMaximized = false;
/// Follows maximize and restore to swap the maximize button's icon.
  ListenerId? _listenerId;
/// The window the buttons act on, when there is one.
  final Window? _window = WindowManager.instance.getCurrent();
@override
  void initState() {
    super.initState();
    _isMaximized = _window?.isMaximized ?? false;
    _listenerId = _window?.addListener((event) {
      if (event is WindowMaximizedEvent || event is WindowRestoredEvent) {
        final isMaximized = _window.isMaximized;
        if (mounted && isMaximized != _isMaximized) {
          setState(() => _isMaximized = isMaximized);
        }
      }
    });
  }
@override
  void dispose() {
    if (_listenerId case final id?) {
      _window?.removeListener(id);
    }
    super.dispose();
  }
@override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        WindowCaptionButton.minimize(
          brightness: brightness,
          onPressed: () => _window?.minimize(),
        ),
        if (_isMaximized)
          WindowCaptionButton.unmaximize(
            brightness: brightness,
            onPressed: () => _window?.unmaximize(),
          )
        else
          WindowCaptionButton.maximize(
            brightness: brightness,
            onPressed: () => _window?.maximize(),
          ),
        // Closing asks the close listeners first, like the system's button
        WindowCaptionButton.close(
          brightness: brightness,
          onPressed: () => _window?.close(),
        ),
      ],
    );
  }
}
