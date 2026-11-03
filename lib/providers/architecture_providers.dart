import 'package:fide/models/architecture_graph.dart';
import 'package:fide/models/architecture_layout.dart';
import 'package:fide/providers/architecture_orientation_notifier.dart';
import 'package:fide/providers/project_lifecycle_providers.dart';
import 'package:fide/providers/project_overview_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The open project's architecture graph, its layers stacked in the
/// chosen orientation, from the fCheck analysis behind the project
/// overview; null without a project. Laid out again after each save, when
/// the overview is re-analyzed, and when the orientation changes.
final architectureLayoutProvider = FutureProvider<ArchitectureLayout?>((
  ref,
) async {
  final projectPath = ref.watch(currentProjectPathProvider);
  final orientation = ref.watch(architectureOrientationProvider);
  final overview = await ref.watch(projectOverviewProvider.future);
  if (projectPath == null || overview == null) return null;
  return ArchitectureLayout(
    ArchitectureGraph.fromMetrics(overview.code, projectPath),
    orientation: orientation,
  );
});
