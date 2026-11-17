import 'package:fide/providers/side_panel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';

/// Routes terminal commands, such as the Edit menu's Clear Terminal, to the
/// terminal of the Terminal panel that is mounted.
///
/// The panel attaches its terminal on mount and detaches it on dispose;
/// while none is attached every command is a no-op.
class ActiveTerminal {
  /// Moves the cursor to the top-left corner of the screen.
  static const String _cursorHome = '\x1b[H';

  /// Starts a control sequence, such as one moving the cursor.
  static const String _controlSequence = '\x1b[';

  /// Erases the lines scrolled off the top of the screen.
  static const String _eraseScrollback = '\x1b[3J';

  Terminal? _terminal;

  /// Makes [terminal] the target of subsequent commands.
  void attach(Terminal terminal) => _terminal = terminal;

  /// Clears the terminal, as ⌘K does in macOS Terminal and VS Code: erases
  /// the scrollback and the screen but the cursor's line, such as the
  /// shell prompt and what is typed after it, which moves to the top.
  void clear() {
    final terminal = _terminal;
    if (terminal == null) return;
    final buffer = terminal.buffer;
    // The cursor's line starts on the screen line its wrapping began on
    var top = buffer.absoluteCursorY;
    while (top > buffer.scrollBack && buffer.lines[top].isWrapped) {
      top--;
    }
    final linesAbove = top - buffer.scrollBack;
    terminal.write(
      [
        // Deleting the lines above shifts the cursor's line to the top
        if (linesAbove > 0) '$_cursorHome$_controlSequence${linesAbove}M',
        _eraseScrollback,
        // Puts the cursor back on its line, the sequence counting from 1
        '$_controlSequence${buffer.cursorY - linesAbove + 1};'
            '${buffer.cursorX + 1}H',
      ].join(),
    );
  }

  /// Stops routing to [terminal], unless another terminal has attached
  /// since.
  void detach(Terminal terminal) {
    if (identical(_terminal, terminal)) {
      _terminal = null;
    }
  }
}

/// Provides the [ActiveTerminal] that menus and shortcuts send terminal
/// commands through.
final activeTerminalProvider = Provider<ActiveTerminal>(
  (_) => ActiveTerminal(),
);

/// Whether the terminal is the active panel, clicked or focused last, so
/// its commands, such as Clear Terminal, are enabled.
final terminalActiveProvider = Provider<bool>(
  (ref) => ref.watch(activePanelProvider) == SidePanel.bottom,
);
