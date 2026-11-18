import 'package:fide/constants/constants.dart';
import 'package:fide/panels/right/preview_card.dart';
import 'package:fide/providers/class_previews_provider.dart';
import 'package:fide/widget_services/preview_viewport.dart';
import 'package:fide/widgets/section_panel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// The Info tab's section showing [previews], the live previews of the
/// widget class [className] declared in [path], at their actual size and
/// as interactive as in the Preview tab.
class WidgetPreviewSection extends ConsumerWidget {
  /// Creates the section of [className]'s [previews].
  const WidgetPreviewSection({
    super.key,
    required this.path,
    required this.className,
    required this.previews,
  });

  /// The widget class previewed.
  final String className;

  /// The file declaring it and its previews, as an absolute path.
  final String path;

  /// The previews building it.
  final List<IndexedPreview> previews;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionPanel(
      title: '$className preview',
      isExpanded: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The width the Preview tab's list would have around these cards
          configurePreviewViewport(
            ref,
            context,
            constraints.maxWidth + AppPadding.panelContent.horizontal,
            AppZoom.actualSize,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.medium,
            children: [
              for (final (:index, :item) in previews)
                PreviewCard(
                  path: path,
                  item: item,
                  index: index,
                  zoom: AppZoom.actualSize,
                ),
            ],
          );
        },
      ),
    );
  }
}
