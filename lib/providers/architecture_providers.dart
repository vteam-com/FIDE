import 'package:fide/models/architecture_graph.dart';
import 'package:fide/models/architecture_layout.dart';
import 'package:fide/providers/architecture_orientation_notifier.dart';
import 'package:fide/providers/project_lifecycle_providers.dart';
import 'package:fide/providers/project_overview_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The open project's architecture graph, from the fCheck analysis behind
/// the project overview; null without a project. Built again after each
/// save, when the overview is re-analyzed, but not when only the
/// orientation of its layout changes.
final architectureGraphProvider = FutureProvider<ArchitectureGraph?>((
  ref,
) async {
  final projectPath = ref.watch(currentProjectPathProvider);
  final overview = await ref.watch(projectOverviewProvider.future);
  if (projectPath == null || overview == null) return null;
  return ArchitectureGraph.fromMetrics(overview.code, projectPath);
});

/// The open project's [architectureGraphProvider], its layers stacked in
/// the chosen orientation; null without a project. Laid out again when
/// the graph or the orientation changes.
final architectureLayoutProvider = FutureProvider<ArchitectureLayout?>((
  ref,
) async {
  final orientation = ref.watch(architectureOrientationProvider);
  final graph = await ref.watch(architectureGraphProvider.future);
  if (graph == null) return null;
  return ArchitectureLayout(graph, orientation: orientation);
});
