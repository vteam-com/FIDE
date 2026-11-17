part of 'output_log.dart';

/// The newest [AppMetric.outputLogMaxLines] lines of one output stream,
/// each ending with a newline, headed by how many earlier lines were
/// dropped; the text is cached until the lines change.
class _OutputLines {
  final Queue<String> _lines = Queue<String>();

  /// Lines dropped from the head to stay within the cap.
  int _dropped = 0;

  /// The text of [_lines], or null when they changed since it was built.
  String? _text;

  /// Whether any line has been added since the last [clear].
  bool get isNotEmpty => _lines.isNotEmpty;

  /// The kept lines, each followed by a newline.
  String get text => _text ??= _join();

  /// Appends each line of [text], dropping the oldest beyond the cap.
  void add(String text) {
    if (text.contains('\n')) {
      _lines.addAll(text.split('\n'));
    } else {
      _lines.add(text);
    }
    while (_lines.length > AppMetric.outputLogMaxLines) {
      _lines.removeFirst();
      _dropped++;
    }
    _text = null;
  }

  /// Discards every line.
  void clear() {
    _lines.clear();
    _dropped = 0;
    _text = null;
  }

  /// Builds [text] from the lines.
  String _join() {
    if (_lines.isEmpty) return '';
    final buffer = StringBuffer();
    if (_dropped > 0) buffer.writeln('… $_dropped earlier lines dropped');
    buffer
      ..writeAll(_lines, '\n')
      ..writeln();
    return buffer.toString();
  }
}
