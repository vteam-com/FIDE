import 'package:fide/constants/constants.dart';
import 'package:fide/models/action_outcome.dart';
import 'package:fide/models/outline_node.dart';
import 'package:fide/models/project_info_state.dart';
import 'package:fide/panels/right/file_info_section.dart';
import 'package:fide/panels/right/symbol_info_section.dart';
import 'package:fide/panels/right/widget_preview_section.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/class_previews_provider.dart';
import 'package:fide/providers/outline_controller.dart';
import 'package:fide/providers/outline_providers.dart';
import 'package:fide/providers/project_info_controller.dart';
import 'package:fide/widget_services/issue_section.dart';
import 'package:fide/widget_services/output_panel.dart';
import 'package:fide/widget_services/project_icon.dart';
import 'package:fide/widgets/badge_status.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/no_project_placeholder.dart';
import 'package:fide/widgets/panel_header.dart';
import 'package:fide/widgets/panel_scroll_view.dart';
import 'package:fide/widgets/refresh_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// The Info tab: what is selected, then the open project. The selected
/// file's path, actions and, for an image, its details; the declaration
/// under the editor's cursor, with its callers and what it calls; the
/// live preview of the widget class it is in, when there is one; then the
/// project's name, version and quality (the same as the overview's).
class InfoPanel extends ConsumerStatefulWidget {
  /// Creates the panel.
  const InfoPanel({super.key});

  @override
  ConsumerState<InfoPanel> createState() => _InfoPanelState();
}

class _InfoPanelState extends ConsumerState<InfoPanel> {
  /// The controller measuring the project, which it does once created.
  ProjectInfoController get _controller =>
      ref.read(projectInfoControllerProvider.notifier);

  /// Shows how an action ended, once it has, while the panel is there.
  Future<void> _show(Future<ActionOutcome?> outcome) async {
    final result = await outcome;
    if (mounted && result != null) {
      MessageBox.showOutcome(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentProjectPath = ref.watch(currentProjectPathProvider);
    final selection = _buildSelection(hasProject: currentProjectPath != null);
    if (currentProjectPath == null) {
      return selection.isEmpty
          ? const NoProjectPlaceholder()
          : PanelScrollView(children: selection);
    }

    final projectMetrics = ref.watch(projectMetricsProvider);
    final info = ref.watch(projectInfoControllerProvider);
    final version = projectMetrics.version;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelHeader(
          leading: ProjectIcon(
            projectPath: currentProjectPath,
            size: AppIconSize.panelHeaderLeading,
          ),
          title: projectMetrics.name ?? 'Unknown Project',
          badge: version == null ? null : BadgeStatus.info(text: 'v$version'),
          subtitle: projectMetrics.description,
          actions: [_buildRefreshButton(info)],
        ),
        Expanded(
          child: PanelScrollView(
            children: [
              ...selection,

              // The project's quality, once fCheck has analyzed it
              if (ref.watch(projectQualityProvider) case final quality?)
                IssueSection(
                  title: 'Quality',
                  issues: quality.issues,
                  emptyLabel: 'No issues detected',
                  rightWidget: BadgeStatus.score(quality.score),
                ),

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
  List<Widget> _buildSelection({required bool hasProject}) {
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

  /// Measures the project and analyzes its quality again. While the
  /// quality is analyzed, the Info tab's ring shows it and the button is
  /// only disabled; measuring alone rings the button.
  Widget _buildRefreshButton(ProjectInfoState info) {
    final isQualityBusy = ref.watch(projectQualityBusyProvider);
    return RefreshButton(
      busy: info.isAnalyzing && !isQualityBusy,
      onPressed: isQualityBusy
          ? null
          : () {
              refreshProjectQuality(ref.invalidate);
              _show(_controller.analyze());
            },
    );
  }
}
