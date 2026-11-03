import 'dart:math' as math;

import 'package:fide/constants/constants.dart';
import 'package:fide/models/architecture_focus.dart';
import 'package:fide/models/architecture_layout.dart';
import 'package:fide/models/locale_number.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/panels/center/architecture/architecture_canvas.dart';
import 'package:fide/panels/center/architecture/architecture_details.dart';
import 'package:fide/providers/architecture_providers.dart';
import 'package:fide/providers/editor_navigation.dart';
import 'package:fide/providers/panel_actions.dart';
import 'package:fide/widgets/app_text_field.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:fide/widgets/empty_state.dart';
import 'package:fide/widgets/header_bar.dart';
import 'package:fide/widgets/loading_indicator.dart';
import 'package:fide/widgets/status_indicator.dart';
import 'package:fide/widgets/zoom_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shown in the center panel to explore the open project's architecture
/// as fCheck layers it: every Dart file in its layer's column, linked to
/// the files it imports.
///
/// Hovering or selecting a file highlights what it imports and what
/// imports it; the selected file's details list both, each a jump to that
/// file in the graph or to its source. Double-clicking a file opens it.
/// The toolbar finds a file, zooms, fits the graph to the view, and shows
/// or hides the imports away from the focused file; saving a file lays
/// the graph out again from the new analysis.
class ArchitecturePanel extends ConsumerStatefulWidget {
  /// Creates the view of the open project's architecture.
  const ArchitecturePanel({super.key});

  @override
  ConsumerState<ArchitecturePanel> createState() => _ArchitecturePanelState();
}

class _ArchitecturePanelState extends ConsumerState<ArchitecturePanel>
    with SingleTickerProviderStateMixin {
  /// Glides the view from one zoom and pan to another.
  late final AnimationController _glide = AnimationController(
    vsync: this,
    duration: AppDuration.graphPan,
  )..addListener(_onGlide);

  /// The zoom and pan [_glide] moves through; null before the first glide.
  Animation<Matrix4>? _glideAnimation;

  /// The project whose graph the view was fitted to, so it fits once per
  /// project, not after each re-analysis.
  String? _fittedRoot;

  /// The file under the pointer; null for none.
  String? _hovered;

  /// The Find File box's text, filtering the files.
  final TextEditingController _query = TextEditingController();

  /// The selected file, whose details show; null for none.
  String? _selected;

  /// Whether every import is drawn, or only the focused file's.
  bool _showAllImports = true;

  /// Zoom and pan of the graph.
  final TransformationController _transformation = TransformationController();

  /// Size of the graph's viewport in the last layout.
  Size _viewport = Size.zero;

  @override
  void dispose() {
    _glide.dispose();
    _query.dispose();
    _transformation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ref
        .watch(architectureLayoutProvider)
        .when(
          // Keep showing the graph while a save re-analyzes the project
          skipLoadingOnReload: true,
          data: (layout) => layout == null || layout.nodes.isEmpty
              ? const EmptyState(
                  icon: Icons.account_tree_outlined,
                  message: 'No Dart files import one another yet',
                )
              : _view(layout),
          loading: () =>
              const LoadingIndicator(message: 'Analyzing project with fCheck…'),
          error: (error, _) => EmptyState.error(
            message: 'Could not analyze the project: $error',
          ),
        );
  }

  /// Glides to [target] zoom and pan.
  void _glideTo(Matrix4 target) {
    _glideAnimation = Matrix4Tween(
      begin: _transformation.value,
      end: target,
    ).animate(CurvedAnimation(parent: _glide, curve: Curves.easeOut));
    _glide.forward(from: 0);
  }

  /// Glides to [layout] whole, centered, at most at actual size.
  void _fit(ArchitectureLayout layout) {
    final size = layout.size;
    if (_viewport.isEmpty || size.isEmpty) return;
    final scale = math
        .min(_viewport.width / size.width, _viewport.height / size.height)
        .clamp(ArchitectureCanvas.minScale, AppZoom.actualSize);
    // Centered, or from the top left when larger than the view
    final fitted = Alignment.center.inscribe(
      size * scale,
      Offset.zero & _viewport,
    );
    _glideTo(
      Matrix4.identity()
        ..translateByDouble(
          math.max(0, fitted.left),
          math.max(0, fitted.top),
          0,
          1,
        )
        ..scaleByDouble(scale, scale, scale, 1),
    );
  }

  /// Selects the first file matching the Find File box, and shows it.
  void _findFirst(ArchitectureLayout layout) {
    final matches = ArchitectureFocus(layout.graph, query: _query.text).matches;
    if (matches.isNotEmpty) _select(layout, matches.first, reveal: true);
  }

  /// Fits [layout] once its project's graph first shows.
  void _fitOnce(ArchitectureLayout layout) {
    final root = layout.graph.rootPath;
    if (_fittedRoot == root) return;
    _fittedRoot = root;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fit(layout);
    });
  }

  /// Moves the view along the running glide.
  void _onGlide() {
    if (_glideAnimation case final animation?) {
      _transformation.value = animation.value;
    }
  }

  /// Focuses [file] while the pointer is inside it, and lets go of it
  /// when the pointer leaves it.
  void _onHover(String file, bool isInside) {
    if (isInside) {
      setState(() => _hovered = file);
    } else if (_hovered == file) {
      setState(() => _hovered = null);
    }
  }

  /// Opens [file] in the editor; closing it returns to this view.
  void _open(String file) => openFromCenterView(ref, file);

  /// Glides to [file] in [layout], centered, at least at actual size.
  void _reveal(ArchitectureLayout layout, String file) {
    final rect = layout.nodes[file];
    if (rect == null) return;
    final scale = math.max(
      _transformation.value.getMaxScaleOnAxis(),
      AppZoom.actualSize,
    );
    final center = _viewport.center(Offset.zero) - rect.center * scale;
    _glideTo(
      Matrix4.identity()
        ..translateByDouble(center.dx, center.dy, 0, 1)
        ..scaleByDouble(scale, scale, scale, 1),
    );
  }

  /// Selects [file], or clears the selection with null; [reveal] also
  /// glides to it.
  void _select(ArchitectureLayout layout, String? file, {bool reveal = false}) {
    setState(() => _selected = file);
    if (reveal && file != null) _reveal(layout, file);
  }

  /// The project's name and size, the Find File box and the view's
  /// buttons.
  Widget _toolbar(ArchitectureLayout layout) {
    final graph = layout.graph;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.medium),
      child: Row(
        spacing: AppSpacing.medium,
        children: [
          Text('Architecture', style: AppTextStyle.title),
          // The counts and the Find File box give way on a narrow view
          Expanded(
            child: Text(
              [
                graph.files.length.count('file'),
                graph.edgeCount.count('import'),
                if (graph.isLayered) graph.layerNumbers.length.count('layer'),
              ].join(' • '),
              style: AppTextStyle.secondary(context),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          if (!graph.isLayered)
            Flexible(
              child: StatusIndicator.tone(
                StatusTone.warning,
                label: 'Import cycles: fCheck could not layer the files',
              ),
            ),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSize.architectureFindWidth,
              ),
              child: AppTextField(
                controller: _query,
                hintText: 'Find file…',
                icon: Icons.search,
                clearable: true,
                // Typing shows the matches in place of the selection's files
                onChanged: (_) => setState(() => _selected = null),
                onCleared: () => setState(() {}),
                onSubmitted: (_) => _findFirst(layout),
              ),
            ),
          ),
          CompactIconButton.header(
            icon: Icons.polyline_outlined,
            tooltip: _showAllImports
                ? "Show only the focused file's imports"
                : 'Show every import',
            selected: _showAllImports,
            onPressed: () => setState(() => _showAllImports = !_showAllImports),
          ),
          CompactIconButton.header(
            icon: Icons.zoom_out,
            tooltip: 'Zoom Out',
            onPressed: () => _zoomBy(1 / AppZoom.canvasStep),
          ),
          ZoomLabel(controller: _transformation),
          CompactIconButton.header(
            icon: Icons.zoom_in,
            tooltip: 'Zoom In',
            onPressed: () => _zoomBy(AppZoom.canvasStep),
          ),
          CompactIconButton.header(
            icon: Icons.fit_screen_outlined,
            tooltip: 'Fit to View',
            onPressed: () => _fit(layout),
          ),
          CompactIconButton.header(
            icon: Icons.close,
            tooltip: 'Close',
            onPressed: () => closeCenterView(ref),
          ),
        ],
      ),
    );
  }

  /// The toolbar over the graph of [layout], the selected file's details
  /// beside it.
  Widget _view(ArchitectureLayout layout) {
    // A file gone after a re-analysis is no longer selected or hovered
    final selected = layout.nodes.containsKey(_selected) ? _selected : null;
    final hovered = layout.nodes.containsKey(_hovered) ? _hovered : null;
    final focus = ArchitectureFocus(
      layout.graph,
      file: hovered ?? selected,
      query: _query.text,
    );
    return Column(
      children: [
        HeaderBar.top(child: _toolbar(layout)),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (_ /*context*/, constraints) {
                    _viewport = constraints.biggest;
                    _fitOnce(layout);
                    return ArchitectureCanvas(
                      layout: layout,
                      focus: focus,
                      controller: _transformation,
                      selected: selected,
                      showAllImports: _showAllImports,
                      onHover: _onHover,
                      onSelect: (file) => _select(layout, file),
                      onOpen: _open,
                      onInteractionStart: _glide.stop,
                    );
                  },
                ),
              ),
              if (selected != null) ...[
                const VerticalDivider(width: AppSize.borderThin),
                SizedBox(
                  width: AppSize.architectureDetailsWidth,
                  child: ArchitectureDetails(
                    graph: layout.graph,
                    file: selected,
                    onSelect: (file) => _select(layout, file, reveal: true),
                    onOpen: _open,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Zooms by [factor] around the middle of the view.
  void _zoomBy(double factor) {
    final current = _transformation.value.getMaxScaleOnAxis();
    final scale = (current * factor).clamp(
      ArchitectureCanvas.minScale,
      ArchitectureCanvas.maxScale,
    );
    final step = scale / current;
    final center = _viewport.center(Offset.zero);
    _glideTo(
      Matrix4.identity()
        ..translateByDouble(center.dx, center.dy, 0, 1)
        ..scaleByDouble(step, step, step, 1)
        ..translateByDouble(-center.dx, -center.dy, 0, 1)
        ..multiply(_transformation.value),
    );
  }
}
