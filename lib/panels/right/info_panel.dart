import 'package:fide/models/outline_node.dart';
import 'package:fide/panels/right/file_info_section.dart';
import 'package:fide/panels/right/symbol_info_section.dart';
import 'package:fide/panels/right/widget_preview_section.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/class_previews_provider.dart';
import 'package:fide/providers/outline_controller.dart';
import 'package:fide/providers/outline_providers.dart';
import 'package:fide/widget_services/output_panel.dart';
import 'package:fide/widget_services/project_header.dart';
import 'package:fide/widget_services/project_quality_card.dart';
import 'package:fide/widget_services/spelling_card.dart';
import 'package:fide/widgets/header_bar.dart';
import 'package:fide/widgets/no_project_placeholder.dart';
import 'package:fide/widgets/panel_scroll_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// The Info tab: what is selected, then the open project. The selected
/// file's path, actions and, for an image, its details; the declaration
/// under the editor's cursor, with its callers and what it calls; the
/// live preview of the widget class it is in, when there is one; then the
/// project's [ProjectHeader] and [ProjectQualityCard], the same as the
/// overview's, and what `dart analyze` printed.
class InfoPanel extends ConsumerWidget {
  /// Creates the panel.
  const InfoPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentProjectPath = ref.watch(currentProjectPathProvider);
    final selection = _buildSelection(
      ref,
      hasProject: currentProjectPath != null,
    );
    if (currentProjectPath == null) {
      return selection.isEmpty
          ? const NoProjectPlaceholder()
          : PanelScrollView(children: selection);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The Info tab rings while the project's quality is analyzed
        const HeaderBar(child: ProjectHeader(isRinged: true)),
        Expanded(
          child: PanelScrollView(
            children: [
              ...selection,

              // The project's quality, once fCheck has analyzed it
              if (ref.watch(projectQualityProvider) case final quality?)
                ProjectQualityCard(quality),

              // The project's spelling, once its words are checked
              if (ref.watch(spellingProvider).value case final spelling?)
                SpellingCard(spelling),

              // What dart analyze printed, links opening each place it
              // names, until cleared
              if (ref.watch(dartAnalysisProvider).value case final analysis?
                  when !identical(
                    analysis,
                    ref.watch(clearedDartAnalysisProvider),
                  ))
                OutputPanel(
                  title: 'dart analyze',
                  text: analysis.output,
                  onClear: () =>
                      ref.read(clearedDartAnalysisProvider.notifier).state =
                          analysis,
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// The sections about what is selected: the file, then, in an open
  /// project ([hasProject]), the declaration under the cursor in it and
  /// the previews of the widget class that declaration is in.
  List<Widget> _buildSelection(WidgetRef ref, {required bool hasProject}) {
    final path = ref.watch(detailedFilePathProvider);
    if (path == null) return const [];
    // The App Icons view's picked icon has no outline
    final isSelectedFile = ref.watch(
      selectedFileProvider.select((file) => file?.path == path),
    );
    final hasOutline =
        hasProject &&
        isSelectedFile &&
        ref.watch(outlineParserProvider(path)) != null;
    final (:symbol, :widgetClass) = hasOutline
        ? ref.watch(outlineControllerProvider(path).select(_selectionIn))
        : (symbol: null, widgetClass: null);
    final className = widgetClass?.usedName;
    final previews = className == null
        ? const <IndexedPreview>[]
        : ref.watch(classPreviewsProvider((path: path, className: className)));
    return [
      FileInfoSection(path: path),
      if (symbol != null && symbol.kind.isCountable)
        SymbolInfoSection(path: path, node: symbol),
      if (className != null && previews.isNotEmpty)
        WidgetPreviewSection(
          path: path,
          className: className,
          previews: previews,
        ),
    ];
  }

  /// The declaration under the cursor in [outline] and the class it is
  /// or is in, compared by identity: moving the cursor within it changes
  /// neither.
  static ({OutlineNode? symbol, OutlineNode? widgetClass}) _selectionIn(
    OutlineState outline,
  ) {
    final symbol = outline.selected;
    return (
      symbol: symbol,
      widgetClass: symbol == null ? null : outline.classOf(symbol),
    );
  }
}
