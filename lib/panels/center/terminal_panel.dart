import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fide/constants/constants.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pty/flutter_pty.dart';
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

  Pty? pty;

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
    pty?.kill();
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
  void _startShell() {
    try {
      final env = Map<String, String>.from(Platform.environment)
        ..['TERM'] = 'xterm-256color';

      // Get the current project path, fallback to app directory if no project loaded
      final projectPath =
          ref.read(currentProjectPathProvider) ?? Directory.current.path;

      pty = Pty.start(
        '/bin/zsh',
        arguments: [],
        workingDirectory: projectPath,
        environment: env,
      );

      // Pipe PTY output to terminal with UTF-8 decoding
      pty!.output.listen((data) {
        final str = utf8.decode(data, allowMalformed: true);
        terminal.write(str);
      });

      // Pipe user input to PTY
      terminal.onOutput = (data) {
        final bytes = Uint8List.fromList(utf8.encode(data));
        pty!.write(bytes);
      };

      terminal.write(
        'Terminal started (macOS zsh) in project: $projectPath\r\n',
      );
      setState(() {});
    } catch (e) {
      terminal.write('Failed to start terminal: $e\r\n');
      setState(() {});
    }
  }

  void _restartShell() {
    // Kill existing PTY
    pty?.kill();
    pty = null;

    // Clear terminal with ANSI escape code
    terminal.write('\x1b[2J\x1b[H'); // Clear screen and move cursor to top

    // Start new shell
    _startShell();
  }

  void _closeTerminal() {
    // Kill existing PTY
    pty?.kill();
    pty = null;

    // Clear terminal and show closed message
    terminal.write('\x1b[2J\x1b[H'); // Clear screen and move cursor to top
    terminal.write('Project closed. Terminal stopped.\r\n');
    terminal.write('Load a project to start the terminal.\r\n');
  }
}
