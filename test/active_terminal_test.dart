import 'package:fide/providers/active_terminal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

void main() {
  /// Lines printed before the prompt, more than a screen holds.
  const int printedLines = 40;

  /// The shell prompt and what the user typed after it.
  const String prompt = r'$ flutter te';

  /// The terminal's lines as text, trailing blanks trimmed.
  List<String> linesOf(Terminal terminal) => [
    for (var i = 0; i < terminal.buffer.height; i++)
      terminal.buffer.lines[i].toString().trimRight(),
  ];

  /// A terminal that printed [printedLines] lines, then [prompt].
  Terminal printedTerminal() {
    final terminal = Terminal();
    for (var i = 0; i < printedLines; i++) {
      terminal.write('line $i\r\n');
    }
    terminal.write(prompt);
    return terminal;
  }

  test('clear keeps only the prompt line, at the top', () {
    final terminal = printedTerminal();
    ActiveTerminal()
      ..attach(terminal)
      ..clear();

    expect(terminal.buffer.height, terminal.viewHeight);
    expect(linesOf(terminal).first, prompt);
    expect(linesOf(terminal).skip(1).every((line) => line.isEmpty), isTrue);
    expect(terminal.buffer.cursorY, 0);
    expect(terminal.buffer.cursorX, prompt.length);
  });

  test('clear keeps a wrapped prompt line whole', () {
    final terminal = Terminal();
    final long = 'x' * (terminal.viewWidth + prompt.length);
    terminal.write('before\r\n$long');
    ActiveTerminal()
      ..attach(terminal)
      ..clear();

    expect(linesOf(terminal).take(2).join(), long);
    expect(terminal.buffer.cursorY, 1);
  });

  test('clear does nothing once the terminal detached', () {
    final terminal = printedTerminal();
    final before = linesOf(terminal);
    ActiveTerminal()
      ..attach(terminal)
      ..detach(terminal)
      ..clear();

    expect(linesOf(terminal), before);
  });
}
