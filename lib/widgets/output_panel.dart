import 'package:fide/widgets/section_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Utils
import '../utils/message_box.dart';

class OutputPanel extends StatefulWidget {
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
  State<OutputPanel> createState() => _OutputPanelState();
}

class _OutputPanelState extends State<OutputPanel> {
  bool _isExpanded = false;

  bool _wrapText = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return SectionPanel(
      title: widget.title,
      isExpanded: _isExpanded,
      rightWidget: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: _copyToClipboard,
            icon: const Icon(Icons.copy, size: 16),
            tooltip: 'Copy to clipboard',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
          IconButton(
            onPressed: () {
              setState(() => _wrapText = !_wrapText);
            },
            icon: Icon(
              _wrapText ? Icons.wrap_text : Icons.text_fields,
              size: 16,
            ),
            tooltip: _wrapText
                ? 'Disable text wrapping'
                : 'Enable text wrapping',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
          if (widget.onClear != null)
            IconButton(
              icon: const Icon(Icons.backspace, size: 16),
              onPressed: () => widget.onClear?.call(),
              tooltip: 'Clear output',
            ),
        ],
      ),

      child: Container(
        constraints: const BoxConstraints(maxHeight: 400),
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: SelectableText(
            widget.text,
            style: TextStyle(
              fontSize: 11,
              fontFamily: _wrapText ? null : 'monospace',
              color: Theme.of(context).colorScheme.onSurface,
              height: _wrapText ? 1.2 : 1.0,
            ),
            textAlign: TextAlign.left,
            textDirection: TextDirection.ltr,
            showCursor: true,
            contextMenuBuilder: (context, editableTextState) {
              return AdaptiveTextSelectionToolbar.editableText(
                editableTextState: editableTextState,
              );
            },
          ),
        ),
      ),
    );
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.text));
    MessageBox.showSuccess(context, 'Copied to clipboard');
  }
}
