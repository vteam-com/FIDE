// ignore_for_file:  use_build_context_synchronously

import 'dart:async';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/theme/app_theme.dart';
import 'package:fide/widgets/badge_status.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:fide/widgets/status_tone_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A message bar in the icon and color of its [type], with a close button
/// and, for tones whose messages are copyable, a copy button; it fades out
/// after the tone's display duration or when closed, then calls [onClose].
class MessageWidget extends StatefulWidget {
  /// Creates a message bar showing [message] in the style of [type].
  const MessageWidget({
    super.key,
    required this.message,
    this.type = StatusTone.info,
    this.onClose,
  });

  /// The text shown.
  final String message;

  /// Called once the message has faded out, to remove it.
  final VoidCallback? onClose;

  /// The tone giving the message its icon, color, duration and buttons.
  final StatusTone type;

  @override
  State<MessageWidget> createState() => _MessageWidgetState();
}

class _MessageWidgetState extends State<MessageWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;

  /// Fades the message out once the tone's display duration is over.
  Timer? _autoDismissTimer;

  /// Whether the message is already fading out, so closing it while the
  /// timer fires reports [MessageWidget.onClose] only once.
  bool _dismissing = false;

  late Animation<double> _fadeAnimation;

  bool _showCopiedText = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: AppDuration.messageAnimation,
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    _autoDismissTimer = Timer(widget.type.messageDuration, _dismiss);
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.type.color;
    final foregroundColor = AppTheme.onStatusColor;
    final semanticLabel = widget.type.messageLabel;

    return FadeTransition(
      opacity: _fadeAnimation,
      // Shown in an overlay, outside any Material: this one gives the text
      // the theme's default style (no debug underline) and the buttons
      // their ink
      child: Material(
        type: MaterialType.transparency,
        child: Tooltip(
          message: semanticLabel,
          child: Container(
            margin: AppPadding.messageMargin,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(AppRadius.medium),
              border: Border.all(
                color: foregroundColor.withValues(alpha: AppOpacity.selected),
                width: AppSize.borderThin,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: AppOpacity.subtle),
                  blurRadius: AppSpacing.tiny,
                  offset: const Offset(0, AppSpacing.micro),
                ),
              ],
            ),
            child: Padding(
              padding: AppPadding.actionTabContent,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    widget.type.icon,
                    color: foregroundColor,
                    size: AppIconSize.large,
                  ),
                  const SizedBox(width: AppSpacing.large),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: AppTextStyle.label.copyWith(
                        color: foregroundColor,
                      ),
                    ),
                  ),
                  if (widget.type.messageCopyable) ...[
                    const SizedBox(width: AppSpacing.medium),
                    SizedBox(
                      height: AppSize.compactActionButton,
                      child: _showCopiedText
                          ? Center(
                              child: AnimatedOpacity(
                                opacity: _showCopiedText ? 1.0 : 0.0,
                                duration: AppDuration.copiedBadgeFade,
                                child: BadgeStatus.success(text: 'Copied'),
                              ),
                            )
                          : CompactIconButton(
                              icon: Icons.copy,
                              color: foregroundColor.withValues(
                                alpha: AppOpacity.secondaryText,
                              ),
                              onPressed: () async {
                                await Clipboard.setData(
                                  ClipboardData(text: widget.message),
                                );
                                // Show "Copied" in place of the button
                                if (mounted) {
                                  setState(() => _showCopiedText = true);
                                  // Hide "Copied" after 1.5 seconds
                                  Future.delayed(
                                    AppDuration.copiedBadgeVisible,
                                    () {
                                      if (mounted) {
                                        setState(() => _showCopiedText = false);
                                      }
                                    },
                                  );
                                }
                              },
                              tooltip: 'Copy message',
                            ),
                    ),
                  ],
                  const SizedBox(width: AppSpacing.tiny),
                  CompactIconButton(
                    icon: Icons.close,
                    color: foregroundColor.withValues(
                      alpha: AppOpacity.secondaryText,
                    ),
                    onPressed: _dismiss,
                    tooltip: 'Close message',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Fades the message out, then reports it closed; later calls, from the
  /// close button or the timer, do nothing.
  void _dismiss() {
    if (_dismissing || !mounted) return;
    _dismissing = true;
    _autoDismissTimer?.cancel();
    _animationController.reverse().then((_) {
      if (mounted) widget.onClose?.call();
    });
  }
}
