import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/section_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Represents `OutputPanel`.
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
            icon: const Icon(Icons.copy, size: AppIconSize.medium),
            tooltip: 'Copy to clipboard',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: AppSize.compactIconButton,
              minHeight: AppSize.compactIconButton,
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() => _wrapText = !_wrapText);
            },
            icon: Icon(
              _wrapText ? Icons.wrap_text : Icons.text_fields,
              size: AppIconSize.medium,
            ),
            tooltip: _wrapText
                ? 'Disable text wrapping'
                : 'Enable text wrapping',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: AppSize.compactIconButton,
              minHeight: AppSize.compactIconButton,
            ),
          ),
          if (widget.onClear != null)
            IconButton(
              icon: const Icon(Icons.backspace, size: AppIconSize.medium),
              onPressed: () => widget.onClear?.call(),
              tooltip: 'Clear output',
            ),
        ],
      ),

      child: Container(
        constraints: const BoxConstraints(maxHeight: AppSize.terminalMaxHeight),
        padding: const EdgeInsets.all(AppSpacing.large),
        child: SingleChildScrollView(
          child: SelectableText(
            widget.text,
            style: TextStyle(
              fontSize: AppFontSize.metadata,
              fontFamily: _wrapText ? null : 'monospace',
              color: Theme.of(context).colorScheme.onSurface,
              height: _wrapText ? AppLineHeight.tight : 1.0,
            ),
            textAlign: TextAlign.left,
            textDirection: TextDirection.ltr,
            showCursor: true,
            contextMenuBuilder: (_, editableTextState) {
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
