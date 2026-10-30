import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/file_location.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/editor_navigation.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/section_panel.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Command output in a collapsible section; `path:line:column` references
/// to existing files, relative ones resolved against the open project, are
/// links that open the file at that line.
class OutputPanel extends ConsumerStatefulWidget {
  const OutputPanel({
    super.key,
    required this.title,
    this.isExpanded = false,
    required this.text,
    this.onClear,
  });

  final bool isExpanded;

  final Function? onClear;

  final String text;

  final String title;

  @override
  ConsumerState<OutputPanel> createState() => _OutputPanelState();
}

class _OutputPanelState extends ConsumerState<OutputPanel> {
  bool _isExpanded = false;

  bool _wrapText = false;

  /// File references in the text, each with the recognizer that opens it.
  List<(FileLocation, TapGestureRecognizer)> _links = [];

  /// Whether each path seen so far exists, so streaming output doesn't
  /// hit the disk again for every new line.
  final Map<String, bool> _pathExists = {};

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isExpanded;
    _findLinks();
  }

  @override
  void didUpdateWidget(OutputPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _findLinks();
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
      isExpanded: _isExpanded,
      rightWidget: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CompactIconButton(
            onPressed: _copyToClipboard,
            icon: Icons.copy,
            tooltip: 'Copy to clipboard',
          ),
          CompactIconButton(
            onPressed: () => setState(() => _wrapText = !_wrapText),
            icon: _wrapText ? Icons.wrap_text : Icons.text_fields,
            tooltip: _wrapText
                ? 'Disable text wrapping'
                : 'Enable text wrapping',
          ),
          if (widget.onClear != null)
            CompactIconButton(
              icon: Icons.backspace,
              onPressed: () => widget.onClear?.call(),
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

  void _copyToClipboard() => MessageBox.copyToClipboard(context, widget.text);

  void _disposeLinks() {
    for (final (_, recognizer) in _links) {
      recognizer.dispose();
    }
  }

  /// Rebuilds [_links] for the current text.
  void _findLinks() {
    _disposeLinks();
    final locations = FileLocation.findAll(
      widget.text,
      baseDir: ref.read(currentProjectPathProvider),
      exists: (path) =>
          _pathExists.putIfAbsent(path, () => File(path).existsSync()),
    );
    _links = [
      for (final location in locations)
        (
          location,
          TapGestureRecognizer()
            ..onTap = () => openFileAtLine(
              ref,
              location.path,
              location.line,
              column: location.column,
            ),
        ),
    ];
  }
}
