import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/container_counter.dart';
import 'package:fide/widgets/outlined_surface.dart';
import 'package:fide/widgets/surface_header_band.dart';
import 'package:fide/widgets/surface_padding.dart';
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
    final rightWidget = widget.rightWidget;
    final count = widget.count;
    final child = widget.child;

    // One outlined box per section: the filled header band and the content
    // share a rounded outline, so the content reads as the header's own and
    // nested sections show their depth by sitting inside their parent's box
    return OutlinedSurface(
      padding: SurfacePadding.none,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: _toggle,
            child: SurfaceHeaderBand(
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
            Padding(padding: AppPadding.panelContent, child: child),
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
