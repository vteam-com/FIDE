import 'dart:async';
import 'dart:typed_data';

import 'package:fide/panels/center/terminal_panel.dart';
import 'package:fide/providers/terminal_providers.dart';
import 'package:fide/services/terminal_session.dart';
import 'package:flutter_pty2/flutter_pty2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xterm/xterm.dart';

/// A shell that prints nothing and takes any input.
class _SilentPty implements PtySession {
  @override
  Stream<Uint8List> get output => const Stream.empty();

  @override
  void kill() {}

  @override
  Future<void> close() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('takes the focus when it opens, from the editor holding it', (
    tester,
  ) async {
    final showTerminal = ValueNotifier(false);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          terminalSessionProvider.overrideWith(
            (ref) => TerminalSession(
              spawn: (_) async => _SilentPty(),
              environment: () async => const {},
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder(
              valueListenable: showTerminal,
              builder: (_, show, _) => Column(
                children: [
                  // The editor, holding the focus first
                  const TextField(autofocus: true),
                  if (show) const Expanded(child: TerminalPanel()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);

    showTerminal.value = true;
    await tester.pump();
    await tester.pump();

    final terminal = tester.widget<TerminalView>(find.byType(TerminalView));
    expect(terminal.focusNode?.hasFocus, isTrue);
  });
}
