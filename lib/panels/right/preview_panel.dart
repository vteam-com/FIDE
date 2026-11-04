import 'package:fide/constants/constants.dart';
import 'package:fide/models/preview_item.dart';
import 'package:fide/models/preview_scope.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/editor_navigation.dart';
import 'package:fide/providers/preview_controller.dart';
import 'package:fide/providers/preview_scope_notifier.dart';
import 'package:fide/services/preview_generator.dart';
import 'package:fide/services/preview_project_scanner.dart';
import 'package:fide/widgets/choice_buttons.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:fide/widgets/compact_text_button.dart';
import 'package:fide/widgets/empty_state.dart';
import 'package:fide/widgets/file_icon_utils.dart';
import 'package:fide/widgets/filter_field.dart';
import 'package:fide/widgets/header_bar.dart';
import 'package:fide/widgets/inline_spinner.dart';
import 'package:fide/widgets/loading_indicator.dart';
import 'package:fide/widgets/output_panel.dart';
import 'package:fide/widgets/primary_button.dart';
import 'package:fide/widgets/secondary_button.dart';
import 'package:fide/widgets/section_title.dart';
import 'package:fide/widgets/tree_branch.dart';
import 'package:fide/widgets/tree_row.dart';
import 'package:fide/widgets/zoom_label.dart';
import 'package:fide/panels/right/preview_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

/// The Preview tab: the live widget previews of the selected Dart file,
/// rendered by the project's preview host and updated as files are saved,
/// with a button generating them for a file without; or every preview of
/// the project, collapsed, the one expanded rendered.
class PreviewPanel extends ConsumerStatefulWidget {
  /// Creates the panel.
  const PreviewPanel({super.key});

  @override
  ConsumerState<PreviewPanel> createState() => _PreviewPanelState();
}

class _PreviewPanelState extends ConsumerState<PreviewPanel> {
  /// The previews' zoom, held as a scale so [ZoomLabel] shows and resets
  /// it as it does for the other zoomable views.
  final TransformationController _zoom = TransformationController();

  /// The query filtering the project's previews.
  final TextEditingController _filter = TextEditingController();

  @override
  void initState() {
    super.initState();
    _zoom.addListener(_onZoomChanged);
    _filter.addListener(_onZoomChanged);
    ref.read(previewScopeProvider.notifier).load();
  }

  @override
  void dispose() {
    _zoom.dispose();
    _filter.dispose();
    super.dispose();
  }

  double get _scale => _zoom.value.getMaxScaleOnAxis();

  /// Rebuilds for a new zoom or filter.
  void _onZoomChanged() => setState(() {});

  void _zoomTo(double scale) =>
      _zoom.value = Matrix4.diagonal3Values(scale, scale, AppZoom.actualSize);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(previewControllerProvider);
    return Column(
      children: [
        HeaderBar(child: _buildToolbar(state)),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _configure(context, constraints.maxWidth);
              return _buildBody(state);
            },
          ),
        ),
      ],
    );
  }

  /// Sends the panel's width, pixel ratio, zoom and brightness to the host
  /// once laid out.
  void _configure(BuildContext context, double width) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final brightness = Theme.of(context).brightness;
    final scale = _scale;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(previewControllerProvider.notifier)
          .configure(
            width: width,
            devicePixelRatio: devicePixelRatio,
            zoom: scale,
            appBrightness: brightness,
          );
    });
  }

  /// The scope, brightness, zoom and restart controls, wrapping onto a
  /// second line in a narrow panel.
  Widget _buildToolbar(PreviewState state) {
    final controller = ref.read(previewControllerProvider.notifier);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ChoiceButtons<PreviewScope>(
          values: PreviewScope.values,
          selected: ref.watch(previewScopeProvider),
          icon: (scope) => scope.icon,
          label: (scope) => scope.label,
          onSelected: ref.read(previewScopeProvider.notifier).select,
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CompactIconButton.header(
              icon: state.brightness.icon,
              tooltip: state.brightness.tooltip,
              onPressed: () => controller.setBrightness(state.brightness.next),
            ),
            CompactIconButton.header(
              icon: Icons.zoom_out,
              tooltip: 'Zoom Out',
              onPressed: () => _zoomTo(AppZoom.smaller(_scale)),
            ),
            ZoomLabel(controller: _zoom),
            CompactIconButton.header(
              icon: Icons.zoom_in,
              tooltip: 'Zoom In',
              onPressed: () => _zoomTo(AppZoom.larger(_scale)),
            ),
          ],
        ),
        if (state.isBusy)
          const InlineSpinner()
        else
          CompactIconButton.header(
            icon: Icons.restart_alt,
            tooltip: 'Restart Previews',
            onPressed: controller.restart,
          ),
      ],
    );
  }

  /// What the panel shows for [state]'s scope and status.
  Widget _buildBody(PreviewState state) {
    if (state.scope == PreviewScope.project) return _buildProject(state);
    switch (state.status) {
      case PreviewStatus.noFile:
        return const EmptyState(
          icon: Icons.preview_outlined,
          message: 'Select a Dart file to preview its widgets',
        );
      case PreviewStatus.part:
        return const EmptyState(
          icon: Icons.preview_outlined,
          message: 'This file is a part: select its library to preview it',
        );
      case PreviewStatus.noPreviews:
        return _buildGenerate(state);
      case PreviewStatus.starting when state.items.isEmpty:
        return const LoadingIndicator(
          message:
              'Starting the previews: the first start compiles the '
              'project',
        );
      case PreviewStatus.starting ||
          PreviewStatus.reloading ||
          PreviewStatus.ready ||
          PreviewStatus.failed:
        return _buildPreviews(state);
    }
  }

  /// The previews, grouped, after the failure, if any, and before the
  /// widgets still without one and the errors the previews reported.
  Widget _buildPreviews(PreviewState state) {
    final groups = {for (final item in state.items) item.group};
    final missing = state.scan.widgetsWithoutPreview.length;
    final path = state.filePath ?? '';
    return ListView(
      padding: AppPadding.panelContent,
      children: [
        ?_buildFailure(state),
        for (final group in groups) ...[
          if (groups.length > 1) SectionTitle(group),
          for (final (index, item) in state.items.indexed)
            if (item.group == group) _buildCard(path, item, index),
        ],
        if (missing > 0 && !state.isGenerating)
          Align(
            alignment: Alignment.centerLeft,
            child: CompactTextButton(
              label: missing == 1
                  ? 'Generate a preview for 1 more widget'
                  : 'Generate previews for $missing more widgets',
              onPressed: _generate,
            ),
          ),
        ?_buildLogs(state),
      ],
    );
  }

  /// Every preview of the project by file, collapsed but the one expanded,
  /// which alone is rendered, over the filter.
  Widget _buildProject(PreviewState state) {
    final files = state.projectFiles;
    if (files.isEmpty) {
      return state.isScanning
          ? const LoadingIndicator(message: "Finding the project's previews")
          : const EmptyState(
              icon: Icons.preview_outlined,
              title: 'No Previews',
              message: "The project's lib folder has no widget preview",
            );
    }
    final root = ref.watch(currentProjectPathProvider);
    final query = _filter.text.trim().toLowerCase();
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: AppPadding.panelContent,
            children: [
              ?_buildFailure(state),
              for (final file in files)
                ..._buildProjectFile(state, file, root, query),
              ?_buildLogs(state),
            ],
          ),
        ),
        FilterField(controller: _filter, hintText: 'Filter previews...'),
      ],
    );
  }

  /// [file]'s row, which opens it, then a row per preview matching
  /// [query], the one expanded showing its frames.
  List<Widget> _buildProjectFile(
    PreviewState state,
    PreviewFileScan file,
    String? root,
    String query,
  ) {
    final relative = root == null
        ? file.path
        : p.relative(file.path, from: root);
    final fileMatches = relative.toLowerCase().contains(query);
    final previews = [
      for (final preview in file.scan.previews)
        if (fileMatches || preview.label.toLowerCase().contains(query)) preview,
    ];
    if (previews.isEmpty) return const [];
    return [
      TreeRow(
        icon: FileIconUtils.ofPath(file.path),
        name: relative,
        path: file.path,
        rootPath: root,
        onTap: () => openFile(ref, file.path),
      ),
      for (final preview in previews)
        if (state.expanded == (path: file.path, label: preview.label))
          TreeBranch(
            header: _buildPreviewRow(file.path, preview.label, true),
            isExpanded: true,
            children: [
              if (state.items.isEmpty)
                const InlineSpinner()
              else
                for (final (index, item) in state.items.indexed)
                  _buildCard(file.path, item, index),
            ],
          )
        else
          _buildPreviewRow(file.path, preview.label, false),
    ];
  }

  /// The row of preview [label] of [path], toggling it.
  Widget _buildPreviewRow(String path, String label, bool isExpanded) {
    return TreeRow(
      icon: Icon(
        isExpanded ? Icons.expand_more : Icons.chevron_right,
        size: AppIconSize.medium,
      ),
      name: label,
      depth: 1,
      highlighted: isExpanded,
      onTap: () =>
          ref.read(previewControllerProvider.notifier).toggle(path, label),
    );
  }

  /// Why the previews failed, with a retry; null when they didn't.
  Widget? _buildFailure(PreviewState state) {
    if (state.status != PreviewStatus.failed) return null;
    return OutputPanel(
      title: 'Preview Failed',
      text: state.message,
      isExpanded: true,
      onClear: ref.read(previewControllerProvider.notifier).restart,
    );
  }

  /// The errors the previews reported; null without any.
  Widget? _buildLogs(PreviewState state) {
    if (state.logs.isEmpty) return null;
    return OutputPanel(
      title: 'Preview Errors',
      text: state.logs.join('\n\n'),
      onClear: ref.read(previewControllerProvider.notifier).clearLogs,
    );
  }

  /// The card of [item], the preview at [index], declared in [path], with
  /// a size fix when its code doesn't set its size and can.
  Widget _buildCard(String path, PreviewItem item, int index) {
    final state = ref.read(previewControllerProvider);
    final canFix =
        (item.frame?.isSizeUndetermined ?? false) &&
        (state.scan.annotationOf(item.function, item.annotation)?.canSetSize ??
            false);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.medium),
      child: PreviewCard(
        path: path,
        item: item,
        index: index,
        zoom: _scale,
        onFixSize: canFix
            ? () => ref
                  .read(previewControllerProvider.notifier)
                  .fixSize(path, item)
            : null,
      ),
    );
  }

  /// For a file without previews: generating them for its widgets, by
  /// code for those whose arguments it can pick, by AI for the others.
  Widget _buildGenerate(PreviewState state) {
    final widgets = state.scan.widgets;
    if (widgets.isEmpty) {
      return const EmptyState(
        icon: Icons.preview_outlined,
        message: 'This file has no widget to preview',
      );
    }
    final skipped = const PreviewGenerator().skippedIn(state.scan);
    final generated = widgets.length - skipped.length;
    final controller = ref.read(previewControllerProvider.notifier);
    return EmptyState(
      icon: Icons.preview_outlined,
      title: 'No Previews',
      message: widgets.length == 1
          ? '${widgets.single.name} has no preview yet'
          : '${widgets.length} widgets in this file have no preview yet',
      child: Column(
        spacing: AppSpacing.medium,
        children: [
          if (generated > 0)
            PrimaryButton(
              label: 'Generate Previews',
              icon: Icons.auto_fix_high,
              busy: state.isGenerating,
              onPressed: _generate,
            ),
          if (skipped.isNotEmpty)
            SecondaryButton(
              label: 'Ask AI for ${skipped.map((w) => w.name).join(', ')}',
              icon: Icons.auto_awesome,
              onPressed: () => controller.askAiForPreviews(skipped),
            ),
        ],
      ),
    );
  }

  /// Generates the previews code can write.
  void _generate() =>
      ref.read(previewControllerProvider.notifier).generatePreviews();
}
