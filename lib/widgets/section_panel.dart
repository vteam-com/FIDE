import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/container_counter.dart';
import 'package:flutter/material.dart';

/// A collapsible section drawn as one outlined card: a header band over its
/// content; stack sections with spacing between the cards.
///
/// The panel owns its expansion: it starts as [isExpanded] and reports each
/// change to [onExpansionChanged], for callers that remember it.
class SectionPanel extends StatefulWidget {
  /// Creates a section titled [title], expanded at first when [isExpanded].
  const SectionPanel({
    super.key,
    required this.title,
    this.isExpanded = false,
    this.onExpansionChanged,
    this.rightWidget,
    this.child,
    this.count,
  });

  /// The content shown while the section is expanded.
  final Widget? child;

  /// Shown as a counter at the end of the header; none when null.
  final int? count;

  /// Whether the section starts expanded.
  final bool isExpanded;

  /// Called with the new expansion each time the header is tapped.
  final ValueChanged<bool>? onExpansionChanged;

  /// Shown at the end of the header, before [count], such as actions.
  final Widget? rightWidget;

  /// The section heading, shown in capitals.
  final String title;

  @override
  State<SectionPanel> createState() => _SectionPanelState();
}

class _SectionPanelState extends State<SectionPanel> {
  late bool _isExpanded = widget.isExpanded;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final headerBackgroundColor = colorScheme.surfaceContainerHighest;
    final rightWidget = widget.rightWidget;
    final count = widget.count;
    final child = widget.child;

    // One card per section: the filled header band and the tinted content
    // share a rounded outline, so the content reads as the header's own and
    // nested sections show their depth by sitting inside their parent's card
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: headerBackgroundColor.withValues(alpha: AppOpacity.selected),
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: AppOpacity.divider),
          width: AppSize.borderThin,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: _toggle,
            child: Container(
              padding: AppPadding.sectionHeader,
              color: headerBackgroundColor,
              child: Row(
                spacing: AppSpacing.tiny,
                children: [
                  Icon(
                    _isExpanded ? Icons.expand_more : Icons.chevron_right,
                    size: AppIconSize.medium,
                    color: colorScheme.primary,
                  ),
                  Expanded(
                    child: Text(
                      widget.title.toUpperCase(),
                      style: AppTextStyle.captionStrong.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  ?rightWidget,
                  if (count != null) ContainerCounter(count: count),
                ],
              ),
            ),
          ),
          if (_isExpanded && child != null)
            Padding(padding: AppPadding.sectionContent, child: child),
        ],
      ),
    );
  }

  /// Flips the expansion and reports it.
  void _toggle() {
    setState(() => _isExpanded = !_isExpanded);
    widget.onExpansionChanged?.call(_isExpanded);
  }
}
