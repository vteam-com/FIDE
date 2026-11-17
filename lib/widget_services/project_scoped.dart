import 'package:fide/providers/app_providers.dart';
import 'package:fide/widgets/no_project_placeholder.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A panel of the open project: [builder] gets the project's path, and
/// the placeholder shows while no project is open.
class ProjectScoped extends ConsumerWidget {
  /// Creates the panel [builder] builds for the open project.
  const ProjectScoped(this.builder, {super.key});

  /// Builds the panel for the project at the given path.
  final Widget Function(String projectPath) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectPath = ref.watch(currentProjectPathProvider);
    return projectPath == null
        ? const NoProjectPlaceholder()
        : builder(projectPath);
  }
}
