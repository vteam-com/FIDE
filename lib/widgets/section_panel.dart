import 'package:fide/widgets/container_counter.dart';
import 'package:flutter/material.dart';

/// A reusable section panel widget with expand/collapse functionality
class SectionPanel extends StatefulWidget {
  const SectionPanel({
    super.key,
    required this.title,
    this.isExpanded = false,
    this.onExpansionToggle,
    this.rightWidget,
    this.child,
    this.contentPadding = const EdgeInsets.only(left: 16.0, bottom: 8.0),
    this.headerPadding = const EdgeInsets.symmetric(
      horizontal: 8.0,
      vertical: 4.0,
    ),
    this.headerBackgroundColor,
    this.titleStyle,
    this.iconColor,
    this.iconExpanded = Icons.expand_more,
    this.iconCollapsed = Icons.chevron_right,
    this.iconSize = 16,
    this.count,
  });

  final String title;
  final bool isExpanded;
  final VoidCallback? onExpansionToggle;
  final Widget? rightWidget;
  final Widget? child;
  final EdgeInsetsGeometry contentPadding;
  final EdgeInsetsGeometry headerPadding;
  final Color? headerBackgroundColor;
  final TextStyle? titleStyle;
  final Color? iconColor;
  final IconData iconExpanded;
  final IconData iconCollapsed;
  final double iconSize;
  final int? count;

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

  void _handleToggle() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    widget.onExpansionToggle?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerBackgroundColor =
        widget.headerBackgroundColor ??
        theme.colorScheme.surfaceContainerHighest;
    final titleStyle =
        widget.titleStyle ??
        TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
          letterSpacing: -1.0,
        );
    final iconColor = widget.iconColor ?? theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        InkWell(
          onTap: _handleToggle,
          child: Container(
            padding: widget.headerPadding,
            color: headerBackgroundColor,
            child: Row(
              spacing: 4,
              children: [
                Icon(
                  _isExpanded ? widget.iconExpanded : widget.iconCollapsed,
                  size: widget.iconSize,
                  color: iconColor,
                ),

                Expanded(
                  child: Text(widget.title.toUpperCase(), style: titleStyle),
                ),

                // optoon widgets
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
    );
  }
}
