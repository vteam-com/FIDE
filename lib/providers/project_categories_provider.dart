import 'package:fide/models/project_categories.dart';
import 'package:fide/models/project_node.dart';
import 'package:fide/providers/project_lifecycle_providers.dart';
import 'package:fide/providers/project_overview_providers.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The project tree under a root grouped by what its files are, for the
/// Organized tab: grouped again when the tree changes in place and each
/// time fCheck's analysis counts the classes, which it does again once
/// saves pause, so a save regroups the files once.
final projectCategoriesProvider = FutureProvider.autoDispose
    .family<ProjectCategories, ProjectNode>((ref, root) {
      ref.watch(projectTreeRevisionProvider);
      final code = ref.watch(
        projectOverviewProvider.select((overview) => overview.value?.code),
      );
      return ref.read(projectCategorizerProvider).categorize(root, code);
    });
