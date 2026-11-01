import 'package:fide/constants/constants.dart';
import 'package:fide/models/chat_message.dart';
import 'package:fide/models/relative_time.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:fide/widgets/markdown_text.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/outlined_surface.dart';
import 'package:fide/widgets/surface_padding.dart';
import 'package:flutter/material.dart';

/// One full-width entry of the AI panel's transcript, laid out like a
/// terminal session: the user's prompt in an outlined box, model replies
/// as Markdown after a dot, and progress steps as dimmed lines.
///
/// Hovering shows when it was added and a button copying its text.
class AiTranscriptEntry extends StatefulWidget {
  /// Creates the entry showing [message].
  const AiTranscriptEntry({super.key, required this.message});

  /// The message shown.
  final ChatMessage message;

  @override
  State<AiTranscriptEntry> createState() => _AiTranscriptEntryState();
}

class _AiTranscriptEntryState extends State<AiTranscriptEntry> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Stack(
        children: [
          _buildContent(),
          if (_isHovering) Positioned(top: 0, right: 0, child: _buildToolbar()),
        ],
      ),
    );
  }

  /// The message, shaped by who wrote it.
  Widget _buildContent() {
    final message = widget.message;
    final colorScheme = Theme.of(context).colorScheme;
    if (message.isUser) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedSurface(
          padding: SurfacePadding.dense,
          child: Text(message.content, style: AppTextStyle.label),
        ),
      );
    }
    if (message.isProgress) {
      return _buildMarked(
        colorScheme.onSurfaceVariant,
        Text(message.content, style: AppTextStyle.secondary(context)),
      );
    }
    return _buildMarked(
      colorScheme.primary,
      MarkdownText(data: message.content, color: colorScheme.onSurface),
    );
  }

  /// [child] after a dot in [markerColor], as a terminal marks each step.
  Widget _buildMarked(Color markerColor, Widget child) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.medium,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.tiny),
          child: Icon(Icons.circle, size: AppIconSize.tiny, color: markerColor),
        ),
        Expanded(child: child),
      ],
    );
  }

  /// When the message was added and the button copying it, kept out of
  /// text selections.
  Widget _buildToolbar() {
    final timestamp = widget.message.timestamp;
    return SelectionContainer.disabled(
      child: OutlinedSurface(
        padding: SurfacePadding.none,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.tiny,
          children: [
            if (timestamp != null)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.medium),
                child: Text(
                  timestamp.timeAgo(),
                  style: AppTextStyle.secondary(context),
                ),
              ),
            CompactIconButton(
              icon: Icons.copy,
              tooltip: 'Copy to clipboard',
              onPressed: () =>
                  MessageBox.copyToClipboard(context, widget.message.content),
            ),
          ],
        ),
      ),
    );
  }
}
