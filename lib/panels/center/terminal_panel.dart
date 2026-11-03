import 'dart:async';

import 'package:fide/constants/constants.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/terminal_providers.dart';
import 'package:fide/services/terminal_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';

/// Embedded terminal panel powered by xterm, launching a shell inside the current project directory.
class TerminalPanel extends ConsumerStatefulWidget {
  const TerminalPanel({super.key});

  @override
  ConsumerState<TerminalPanel> createState() => _TerminalPanelState();
}

class _TerminalPanelState extends ConsumerState<TerminalPanel> {
  /// Clears the screen and moves the cursor to the top.
  static const String _clearScreen = '\x1b[2J\x1b[H';

  final TerminalController controller = TerminalController();

  /// The shell shown, whose output feeds [terminal].
  late final TerminalSession _session = ref.read(terminalSessionProvider);

  late final StreamSubscription<String> _output;

  final Terminal terminal = Terminal(maxLines: AppMetric.terminalMaxLines);

  String? _currentProjectPath;

  @override
  void initState() {
    super.initState();
    _output = _session.output.listen(terminal.write);
    terminal.onOutput = (data) => unawaited(_session.write(data));

    // Initialize current project path
    _currentProjectPath = ref.read(currentProjectPathProvider);

    _startShell();
  }

  @override
  void dispose() {
    unawaited(_output.cancel());
    _session.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the session alive while the panel shows
    ref.watch(terminalSessionProvider);
    // Listen for changes to the current project path
    ref.listen<String?>(currentProjectPathProvider, (_, next) {
      if (next != _currentProjectPath) {
        _currentProjectPath = next;
        if (next == null) {
          // Project closed, close the terminal
          _closeTerminal();
        } else {
          // Project changed or loaded, restart shell
          _restartShell();
        }
      }
    });

    return TerminalView(
      terminal,
      controller: controller,
      autofocus: true,
      backgroundOpacity: 1,
      // Keeps the first and last rows and columns clear of the panel edges
      padding: const EdgeInsets.all(AppSpacing.medium),
      theme: TerminalTheme(
        cursor: Colors.white,
        selection: Colors.blue.withAlpha(AppSize.gutterDividerAlpha.toInt()),
        searchHitBackground: Colors.yellow,
        searchHitBackgroundCurrent: Colors.orange,
        searchHitForeground: Colors.black,
        black: TerminalPalette.background,
        red: TerminalPalette.red,
        green: TerminalPalette.green,
        yellow: TerminalPalette.yellow,
        blue: TerminalPalette.blue,
        magenta: TerminalPalette.magenta,
        cyan: TerminalPalette.cyan,
        white: TerminalPalette.white,
        brightBlack: TerminalPalette.brightBlack,
        brightRed: TerminalPalette.red,
        brightGreen: TerminalPalette.green,
        brightYellow: TerminalPalette.yellow,
        brightBlue: TerminalPalette.blue,
        brightMagenta: TerminalPalette.magenta,
        brightCyan: TerminalPalette.cyan,
        brightWhite: TerminalPalette.brightWhite,
        background: TerminalPalette.background,
        foreground: TerminalPalette.white,
      ),
    );
  }

  /// Starts the shell in the project folder, or the app's own folder
  /// when no project is loaded, and reports how it went.
  Future<void> _startShell() async {
    try {
      final started = await _session.start(
        workingDirectory: ref.read(currentProjectPathProvider),
      );
      // The panel was disposed, or the shell restarted, while spawning
      if (!mounted || !started) return;
      terminal.write(
        'Terminal started (macOS zsh) in project: '
        '${_session.workingDirectory}\r\n',
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      terminal.write('Failed to start terminal: $e\r\n');
      setState(() {});
    }
  }

  void _restartShell() {
    _session.stop();
    terminal.write(_clearScreen);
    _startShell();
  }

  void _closeTerminal() {
    _session.stop();
    terminal.write(_clearScreen);
    terminal.write('Project closed. Terminal stopped.\r\n');
    terminal.write('Load a project to start the terminal.\r\n');
  }
}
