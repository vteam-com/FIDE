import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';
import 'package:flutter_pty/flutter_pty.dart';

class DesktopTerminal extends StatefulWidget {
  const DesktopTerminal({super.key});

  @override
  State<DesktopTerminal> createState() => _DesktopTerminalState();
}

class _DesktopTerminalState extends State<DesktopTerminal> {
  TerminalController? controller;

  Pty? pty;

  late Terminal terminal;

  @override
  void initState() {
    super.initState();
    terminal = Terminal(maxLines: 1000);
    controller = TerminalController();
    _startShell();
  }

  @override
  void dispose() {
    pty?.kill();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      constraints: const BoxConstraints(minWidth: 400, minHeight: 300),
      child: TerminalView(terminal, controller: controller!, autofocus: true),
    );
  }

  void _startShell() {
    try {
      pty = Pty.start(
        '/bin/zsh',
        arguments: [],
        workingDirectory: Directory.current.path,
      );

      // Pipe PTY output to terminal
      pty!.output.listen((data) {
        terminal.write(String.fromCharCodes(data));
      });

      // Pipe user input to PTY
      terminal.onOutput = (data) {
        final bytes = Uint8List.fromList(utf8.encode(data));
        pty!.write(bytes);
      };

      terminal.write('Terminal started (macOS zsh).\r\n');
      setState(() {});
    } catch (e) {
      terminal.write('Failed to start terminal: $e\r\n');
      setState(() {});
    }
  }
}
