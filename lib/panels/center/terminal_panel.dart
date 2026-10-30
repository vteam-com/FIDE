import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fide/constants/constants.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pty2/flutter_pty2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';

/// Embedded terminal panel powered by xterm, launching a shell inside the current project directory.
class TerminalPanel extends ConsumerStatefulWidget {
  const TerminalPanel({super.key});

  @override
  ConsumerState<TerminalPanel> createState() => _TerminalPanelState();
}

class _TerminalPanelState extends ConsumerState<TerminalPanel> {
  TerminalController? controller;

  PtySession? pty;

  /// Incremented on every start/stop so a slow async spawn can tell it is stale.
  int _shellGeneration = 0;

  late Terminal terminal;

  String? _currentProjectPath;

  @override
  void initState() {
    super.initState();
    terminal = Terminal(maxLines: AppMetric.terminalMaxLines);
    controller = TerminalController();

    // Initialize current project path
    _currentProjectPath = ref.read(currentProjectPathProvider);

    _startShell();
  }

  @override
  void dispose() {
    _stopShell();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
      controller: controller!,
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

  /// Starts a zsh PTY session and wires terminal input/output streams.
  Future<void> _startShell() async {
    final generation = ++_shellGeneration;
    try {
      // Get the current project path, fallback to app directory if no project loaded
      final projectPath =
          ref.read(currentProjectPathProvider) ?? Directory.current.path;

      final session = await Pty.spawn(
        PtySpawnOptions(
          executable: '/bin/zsh',
          workingDirectory: projectPath,
          environment: const PtyEnvironment.inherit(
            overrides: {'TERM': 'xterm-256color'},
          ),
        ),
      );

      // The panel was disposed, or the shell restarted, while spawning
      if (!mounted || generation != _shellGeneration) {
        session.kill();
        unawaited(session.close());
        return;
      }
      pty = session;

      // Pipe PTY output to terminal with UTF-8 decoding
      session.output.listen((data) {
        final str = utf8.decode(data, allowMalformed: true);
        terminal.write(str);
      });

      // Pipe user input to PTY
      terminal.onOutput = (data) {
        final bytes = Uint8List.fromList(utf8.encode(data));
        unawaited(session.input.write(bytes).catchError((_) {}));
      };

      terminal.write(
        'Terminal started (macOS zsh) in project: $projectPath\r\n',
      );
      setState(() {});
    } catch (e) {
      if (!mounted) {
        return;
      }
      terminal.write('Failed to start terminal: $e\r\n');
      setState(() {});
    }
  }

  /// Kills the running shell (if any) and releases its PTY session.
  void _stopShell() {
    _shellGeneration++;
    final session = pty;
    pty = null;
    if (session == null) {
      return;
    }
    try {
      session.kill();
    } catch (_) {
      // The shell already exited
    }
    unawaited(session.close());
  }

  void _restartShell() {
    // Kill existing PTY
    _stopShell();

    // Clear terminal with ANSI escape code
    terminal.write('\x1b[2J\x1b[H'); // Clear screen and move cursor to top

    // Start new shell
    _startShell();
  }

  void _closeTerminal() {
    // Kill existing PTY
    _stopShell();

    // Clear terminal and show closed message
    terminal.write('\x1b[2J\x1b[H'); // Clear screen and move cursor to top
    terminal.write('Project closed. Terminal stopped.\r\n');
    terminal.write('Load a project to start the terminal.\r\n');
  }
}
