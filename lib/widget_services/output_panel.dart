import 'package:fide/constants/constants.dart';
import 'package:fide/models/file_location.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/editor_navigation.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:fide/widgets/copy_button.dart';
import 'package:fide/widgets/section_panel.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Command output in a collapsible section, with Copy, Wrap and Clear in
/// its header; `path:line:column` references to existing files, relative
/// ones resolved against the open project, are links that open the file at
/// that line.
class OutputPanel extends ConsumerStatefulWidget {
  /// Creates a section titled [title] showing [text].
  const OutputPanel({
    super.key,
    required this.title,
    this.isExpanded = false,
    required this.text,
    required this.onClear,
  });

  /// Whether the section starts expanded.
  final bool isExpanded;

  /// Clears the output, as the header's Clear button does; the owner drops
  /// the text, which hides the section until there is output again.
  final VoidCallback onClear;

  /// The command output shown.
  final String text;

  /// The section heading.
  final String title;

  @override
  ConsumerState<OutputPanel> createState() => _OutputPanelState();
}

class _OutputPanelState extends ConsumerState<OutputPanel> {
  bool _wrapText = false;

  /// File references in the text, each with the recognizer that opens it.
  List<(FileLocation, TapGestureRecognizer)> _links = [];

  /// Whether each path seen so far exists, so streaming output doesn't
  /// hit the disk again for every new line.
  final Map<String, bool> _pathExists = {};

  @override
  void initState() {
    super.initState();
    _findLinks(from: 0);
  }

  @override
  void didUpdateWidget(OutputPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.text;
    if (old == widget.text) return;
    // Streaming output only appends: scan from the old text's last,
    // unfinished line rather than the whole text again
    _findLinks(
      from: widget.text.startsWith(old) ? old.lastIndexOf('\n') + 1 : 0,
    );
  }

  @override
  void dispose() {
    _disposeLinks();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SectionPanel(
      title: widget.title,
      isExpanded: widget.isExpanded,
      rightWidget: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CopyButton(text: widget.text),
          CompactIconButton(
            onPressed: () => setState(() => _wrapText = !_wrapText),
            icon: _wrapText ? Icons.wrap_text : Icons.text_fields,
            tooltip: _wrapText
                ? 'Disable text wrapping'
                : 'Enable text wrapping',
          ),
          CompactIconButton(
            icon: Icons.backspace,
            onPressed: widget.onClear,
            tooltip: 'Clear output',
          ),
        ],
      ),

      child: Container(
        constraints: const BoxConstraints(maxHeight: AppSize.terminalMaxHeight),
        padding: const EdgeInsets.all(AppSpacing.large),
        child: SingleChildScrollView(
          child: _wrapText
              ? _buildText()
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _buildText(),
                ),
        ),
      ),
    );
  }

  /// The output in monospace so columns line up; long lines wrap only
  /// when the panel gives it a bounded width.
  Widget _buildText() {
    final colorScheme = Theme.of(context).colorScheme;
    return SelectableText.rich(
      _buildSpans(),
      style: AppTextStyle.code.copyWith(color: colorScheme.onSurface),
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
      showCursor: true,
      contextMenuBuilder: (_, editableTextState) {
        return AdaptiveTextSelectionToolbar.editableText(
          editableTextState: editableTextState,
        );
      },
    );
  }

  /// The text with each file reference as an underlined link.
  TextSpan _buildSpans() {
    final text = widget.text;
    final linkStyle = AppTextStyle.link(context);
    final spans = <TextSpan>[];
    var offset = 0;
    for (final (location, recognizer) in _links) {
      spans.add(TextSpan(text: text.substring(offset, location.start)));
      spans.add(
        TextSpan(
          text: text.substring(location.start, location.end),
          style: linkStyle,
          recognizer: recognizer,
          mouseCursor: SystemMouseCursors.click,
        ),
      );
      offset = location.end;
    }
    spans.add(TextSpan(text: text.substring(offset)));
    return TextSpan(children: spans);
  }

  void _disposeLinks() {
    for (final (_, recognizer) in _links) {
      recognizer.dispose();
    }
  }

  /// Updates [_links] for the current text, which is unchanged before
  /// offset [from]: links before it stay, the text after it is scanned
  /// again, and the recognizers of links found again are reused.
  void _findLinks({required int from}) {
    final kept = <(FileLocation, TapGestureRecognizer)>[];
    final spare = <(String, int, int), List<TapGestureRecognizer>>{};
    for (final link in _links) {
      final (location, recognizer) = link;
      if (location.end <= from) {
        kept.add(link);
      } else {
        spare.putIfAbsent(_target(location), () => []).add(recognizer);
      }
    }
    final found = FileLocation.findAll(
      widget.text.substring(from),
      baseDir: ref.read(currentProjectPathProvider),
      exists: (path) => _pathExists.putIfAbsent(
        path,
        () => ref.read(fileEntryServiceProvider).exists(path),
      ),
    );
    _links = [
      ...kept,
      for (final location in found)
        (
          FileLocation(
            start: from + location.start,
            end: from + location.end,
            path: location.path,
            line: location.line,
            column: location.column,
          ),
          _recognizerFor(location, spare[_target(location)]),
        ),
    ];
    for (final recognizers in spare.values) {
      for (final recognizer in recognizers) {
        recognizer.dispose();
      }
    }
  }

  /// A recognizer opening [location]: one taken from [spare], which open
  /// the same place, or a new one.
  TapGestureRecognizer _recognizerFor(
    FileLocation location,
    List<TapGestureRecognizer>? spare,
  ) {
    if (spare != null && spare.isNotEmpty) return spare.removeLast();
    return TapGestureRecognizer()
      ..onTap = () => openFileAtLine(
        ref,
        location.path,
        location.line,
        column: location.column,
      );
  }

  /// The place [location] opens, the same for every reference to it.
  static (String, int, int) _target(FileLocation location) =>
      (location.path, location.line, location.column);
}
