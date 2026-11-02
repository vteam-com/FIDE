import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/container_counter.dart';
import 'package:flutter/material.dart';

/// A collapsible section drawn as one outlined card: a header band over its
/// content; stack sections with spacing between the cards
class SectionPanel extends StatefulWidget {
  const SectionPanel({
    super.key,
    required this.title,
    this.isExpanded = false,
    this.onExpansionToggle,
    this.rightWidget,
    this.child,
    this.contentPadding = AppPadding.sectionContent,
    this.headerPadding = AppPadding.sectionHeader,
    this.headerBackgroundColor,
    this.titleStyle,
    this.iconColor,
    this.iconExpanded = Icons.expand_more,
    this.iconCollapsed = Icons.chevron_right,
    this.iconSize = AppIconSize.medium,
    this.count,
  });

  final Widget? child;

  final EdgeInsetsGeometry contentPadding;

  final int? count;

  final Color? headerBackgroundColor;

  final EdgeInsetsGeometry headerPadding;

  final IconData iconCollapsed;

  final Color? iconColor;

  final IconData iconExpanded;

  final double iconSize;

  final bool isExpanded;

  final VoidCallback? onExpansionToggle;

  final Widget? rightWidget;

  final String title;

  final TextStyle? titleStyle;

  @override
  State<SectionPanel> createState() => _SectionPanelState();
}

class _SectionPanelState extends State<SectionPanel> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isExpanded;
  }

  @override
  void didUpdateWidget(SectionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isExpanded != widget.isExpanded) {
      _isExpanded = widget.isExpanded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerBackgroundColor =
        widget.headerBackgroundColor ??
        theme.colorScheme.surfaceContainerHighest;
    final titleStyle =
        widget.titleStyle ??
        AppTextStyle.captionStrong.copyWith(color: theme.colorScheme.primary);
    final iconColor = widget.iconColor ?? theme.colorScheme.primary;

    // One card per section: the filled header band and the tinted content
    // share a rounded outline, so the content reads as the header's own and
    // nested sections show their depth by sitting inside their parent's card
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: headerBackgroundColor.withValues(alpha: AppOpacity.selected),
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(
            alpha: AppOpacity.divider,
          ),
          width: AppSize.borderThin,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section header
          InkWell(
            onTap: _handleToggle,
            child: Container(
              padding: widget.headerPadding,
              color: headerBackgroundColor,
              child: Row(
                spacing: AppSpacing.tiny,
                children: [
                  Icon(
                    _isExpanded ? widget.iconExpanded : widget.iconCollapsed,
                    size: widget.iconSize,
                    color: iconColor,
                  ),

                  Expanded(
                    child: Text(widget.title.toUpperCase(), style: titleStyle),
                  ),

                  // optional widgets
                  if (widget.rightWidget != null) widget.rightWidget!,

                  // optional count
                  if (widget.count != null)
                    ContainerCounter(count: widget.count!),
                ],
              ),
            ),
          ),
          // Section content
          if (_isExpanded && widget.child != null)
            Padding(padding: widget.contentPadding, child: widget.child),
        ],
      ),
    );
  }

  void _handleToggle() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    widget.onExpansionToggle?.call();
  }
}
