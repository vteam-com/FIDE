import 'package:fide/services/terminal_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The shell session behind the Terminal panel, stopped once the panel
/// is gone; override in tests to fake the shell.
final terminalSessionProvider = Provider.autoDispose<TerminalSession>((ref) {
  final session = TerminalSession();
  ref.onDispose(session.dispose);
  return session;
});
