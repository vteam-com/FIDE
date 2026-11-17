import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/container_counter.dart';
import 'package:fide/widgets/expansion_chevron.dart';
import 'package:fide/widgets/icon_only_labels.dart';
import 'package:fide/widgets/outlined_surface.dart';
import 'package:fide/widgets/priority_row.dart';
import 'package:fide/widgets/section_title.dart';
import 'package:fide/widgets/surface_header_band.dart';
import 'package:fide/widgets/surface_padding.dart';
import 'package:fide/widgets/truncated_text.dart';
import 'package:material_ui/material_ui.dart';

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
    this.builder,
    this.count,
  }) : assert(child == null || builder == null);

  /// Builds the content each time the expanded section builds, instead of
  /// [child]: a collapsed section, or one never opened, builds none of
  /// it, for content costly to build such as a long list.
  final WidgetBuilder? builder;

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
    final rightWidget = widget.rightWidget;
    final count = widget.count;
    final builder = widget.builder;
    final content = builder == null ? widget.child : Builder(builder: builder);
    final extras = [
      ?rightWidget,
      if (count != null) ContainerCounter(count: count),
    ];
    final trailing = extras.isEmpty
        ? null
        : Row(
            mainAxisSize: MainAxisSize.min,
            spacing: AppSpacing.tiny,
            children: extras,
          );

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
              // In a narrow panel the title keeps its room: the actions
              // drop their labels, then hide
              child: PriorityRow(
                spacing: AppSpacing.tiny,
                leading: ExpansionChevron(isExpanded: _isExpanded),
                // A section's heading style, kept on one line
                title: TruncatedText(widget.title, style: SectionTitle.style),
                trailing: trailing,
                compactTrailing: trailing == null
                    ? null
                    : IconOnlyLabels(child: trailing),
              ),
            ),
          ),
          if (_isExpanded && content != null)
            Padding(padding: AppPadding.panelContent, child: content),
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
