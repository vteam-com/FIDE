import 'package:fide/constants/constants.dart';
import 'package:fide/models/asset_kind.dart';
import 'package:fide/models/code_category.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/models/locale_number.dart';
import 'package:fide/models/project_categories.dart';
import 'package:fide/models/project_node.dart';
import 'package:fide/panels/left/shared_panel_utils.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/panel_actions.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/widget_services/filename_widget.dart';
import 'package:fide/widgets/asset_kind_icon.dart';
import 'package:fide/widgets/container_counter.dart';
import 'package:fide/widgets/folder_node.dart';
import 'package:fide/widgets/inline_spinner.dart';
import 'package:fide/widgets/loading_indicator.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/no_project_placeholder.dart';
import 'package:fide/widgets/section_panel.dart';
import 'package:fide/widgets/tree_branch.dart';
import 'package:fide/widgets/tree_row.dart';
import 'package:fide/widgets/warning_count.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

/// OrganizedPanel provides a categorized view of the project
class OrganizedPanel extends ProjectTreePanel {
  const OrganizedPanel({
    super.key,
    super.onFileSelected,
    super.selectedFile,
    super.initialProjectPath,
  });

  @override
  ConsumerState<OrganizedPanel> createState() => _OrganizedPanelState();
}

class _OrganizedPanelState extends ConsumerState<OrganizedPanel>
    with ProjectTreePanelState<OrganizedPanel> {
  /// The grouping of the current tree; null while it is computed.
  ProjectCategories? _categories;

  /// Bumped per categorization so a stale result is dropped.
  int _categorizeGeneration = 0;

  /// The file whose classes are being split into their own files, if any.
  String? _splittingPath;

  @override
  void onProjectTreeChanged() {
    _categories = null;
    _categorize();
  }

  /// Groups the current tree off the build path, counting classes from
  /// the overview's fCheck analysis once there is one, and rebuilds with it.
  Future<void> _categorize() async {
    final root = projectRoot;
    if (root == null) return;
    final generation = ++_categorizeGeneration;
    final categories = await ref
        .read(projectCategorizerProvider)
        .categorize(root, ref.read(projectOverviewProvider).value?.code);
    if (!mounted || generation != _categorizeGeneration) return;
    setState(() => _categories = categories);
  }

  @override
  Widget build(BuildContext context) {
    // Watch for project data from ProjectService
    final currentProjectRoot = ref.watch(currentProjectRootProvider);
    final isProjectLoaded = ref.watch(projectLoadedProvider);
    // Rebuild when the tree changes in place, e.g. Git status arriving
    ref.watch(projectTreeRevisionProvider);

    syncProjectRoot(currentProjectRoot);
    ref.listen(savedFilesRevisionProvider, (_, _) => _categorize());
    // Files were added or removed, e.g. by a class split
    ref.listen(projectTreeRevisionProvider, (_, _) => _categorize());
    // Class counts come from fCheck, analyzing again after each save
    ref.listen(projectOverviewProvider, (_, _) => _categorize());

    return !isProjectLoaded
        ? const NoProjectPlaceholder()
        : buildPanelContent();
  }

  /// Handles `_OrganizedPanelState.buildPanelContent`.
  Widget buildPanelContent() {
    if (projectRoot == null) {
      return const NoProjectPlaceholder();
    }

    /// Handles `_buildOrganizedView`.
    return _buildOrganizedView();
  }

  /// One section per non-empty category, or a spinner while grouping.
  Widget _buildOrganizedView() {
    final categories = _categories;
    if (categories == null) {
      return const LoadingIndicator();
    }

    final sections = [
      for (final MapEntry(key: category, value: nodes)
          in categories.nodes.entries)
        if (nodes.isNotEmpty)
          _buildCategorySection(
            category,
            nodes,
            categories.sourceFileCounts[category] ?? 0,
            categories.elementCounts[category] ?? 0,
            categories.publicClassCounts[category] ?? 0,
          ),
      if (categories.assets.isNotEmpty || _hasAppIcons)
        _buildAssetsSection(categories.assets),
    ];

    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.small),
      child: Column(spacing: AppSpacing.small, children: sections),
    );

    return LayoutBuilder(
      builder: (_, constraints) {
        final isConstrained = constraints.maxHeight.isFinite;

        if (isConstrained) {
          return content;
        }

        // For unconstrained layouts, use a Container with fixed height (no flex)
        return SizedBox(height: AppSize.panelFallbackHeight, child: content);
      },
    );
  }

  /// Handles `_buildCategorySection`.
  Widget _buildCategorySection(
    CodeCategory category,
    List<ProjectNode> nodes,
    int sourceFileCount,
    int elementCount,
    int publicClassCount,
  ) {
    final expansionKey = 'category_${category.name}';
    final isExpanded = expandedState[expansionKey] ?? false;

    // Flutter's rule is one public class per file (private helpers may share
    // it): show the Dart file count, as a warning, only when they differ
    final rightWidget =
        sourceFileCount == 0 || sourceFileCount == publicClassCount
        ? null
        : WarningCount(
            icon: Icons.description,
            count: sourceFileCount,
            message:
                '$sourceFileCount files define $publicClassCount public '
                'classes; expected one public class per file',
          );

    final contentWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final node in nodes) _buildNode(node, category)],
    );

    return SectionPanel(
      title: category.label,
      isExpanded: isExpanded,
      rightWidget: rightWidget,
      count: elementCount,
      child: contentWidget,
      onExpansionChanged: (expanded) => expandedState[expansionKey] = expanded,
    );
  }

  /// The Assets section: one group per kind of asset in [assets].
  Widget _buildAssetsSection(Map<AssetKind, List<ProjectNode>> assets) {
    const expansionKey = 'category_assets';
    final isExpanded = expandedState[expansionKey] ?? false;
    return SectionPanel(
      title: 'Assets',
      isExpanded: isExpanded,
      count: assets.values.fold<int>(0, (sum, files) => sum + files.length),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_hasAppIcons) _buildAppIconsRow(),
          for (final MapEntry(key: kind, value: files) in assets.entries)
            _buildAssetGroup(kind, files),
        ],
      ),
      onExpansionChanged: (expanded) => expandedState[expansionKey] = expanded,
    );
  }

  /// Whether the project has platforms with app icons or icon problems.
  bool get _hasAppIcons {
    final report = ref.watch(appIconReportProvider).value;
    return report != null &&
        (report.slots.isNotEmpty || report.issues.isNotEmpty);
  }

  /// The row opening the App Icons view, flagging the icons' problems.
  Widget _buildAppIconsRow() {
    final isVisible = ref.watch(appIconsVisibleProvider);
    final issueCount = ref.watch(appIconIssuesProvider)?.length ?? 0;
    return TreeRow(
      icon: Icon(
        Icons.apps,
        color: Theme.of(context).colorScheme.primary,
        size: AppIconSize.medium,
      ),
      name: 'App Icons',
      highlighted: isVisible,
      onTap: () => showAppIcons(ref),
      trailing: [
        if (issueCount > 0)
          WarningCount(
            icon: Icons.apps,
            count: issueCount,
            message: '${issueCount.count('app icon problem')}; click to fix',
          ),
      ],
    );
  }

  /// The [kind] group row and, when expanded, its [files].
  Widget _buildAssetGroup(AssetKind kind, List<ProjectNode> files) {
    final expansionKey = 'assets_${kind.name}';
    final isExpanded = expandedState[expansionKey] ?? false;
    final color = Theme.of(context).colorScheme.primary;
    return TreeBranch(
      header: TreeRow(
        icon: Icon(kind.icon, color: color, size: AppIconSize.medium),
        name: kind.label,
        nameStyle: AppTextStyle.body.copyWith(color: isExpanded ? color : null),
        onTap: () => setState(() => expandedState[expansionKey] = !isExpanded),
        trailing: [
          ContainerCounter(
            count: files.length,
            tooltip: '${kind.label} in the project assets',
          ),
        ],
      ),
      isExpanded: isExpanded,
      children: [for (final file in files) _buildNode(file)],
    );
  }

  /// The row for [node] (and its expanded children) in [category], if any.
  Widget _buildNode(ProjectNode node, [CodeCategory? category]) {
    final isExpanded = expandedState[node.path] ?? false;
    final hasDialogs =
        category == CodeCategory.views &&
        (_categories?.viewsWithDialogs.contains(node.path) ?? false);
    final item = FileSystemItem.fromNode(
      node,
      warning: hasDialogs
          ? 'This file contains a showDialog, we suggest to move dialog related code to single file with dialog logic.'
          : null,
    );

    final isSelected = widget.selectedFile?.path == item.path;

    if (node.isDirectory) {
      final multiClassFileCount = _categories?.multiClassFolders[node.path];
      return FolderNode(
        node: node,
        isExpanded: isExpanded,
        rootPath: projectRoot!.path,
        trailing: multiClassFileCount == null
            ? null
            : WarningCount(
                icon: Icons.description,
                count: multiClassFileCount,
                message:
                    '$multiClassFileCount files in this folder define more '
                    'than one public class; expected one public class '
                    'per file',
              ),
        onTap: () => toggleOrOpenNode(node, isExpanded),
        onShowContextMenu: (position) => showNodeContextMenu(node, position),
        children: [
          if (isExpanded)
            for (final child in node.children) _buildNode(child, category),
        ],
      );
    } else {
      final classCount = _categories?.multiClassFiles[node.path];
      return FileNameWidget(
        fileItem: item,
        isSelected: isSelected,
        rootPath: projectRoot!.path,
        onTap: () => handleFileTap(node),
        onContextMenu: (position) => showNodeContextMenu(node, position),
        trailing: _splittingPath == node.path
            ? const InlineSpinner(size: AppSize.compactProgressIndicator)
            : classCount == null
            ? null
            : WarningCount(
                icon: Icons.data_object,
                count: classCount,
                message:
                    'Defines $classCount public classes; '
                    'expected one public class per file.\n'
                    'Click to move the others into their own files.',
                onTap: _splittingPath == null
                    ? () => _splitClasses(node, classCount)
                    : null,
              ),
      );
    }
  }

  /// After confirmation, saves the open files and moves every public class
  /// of [node] but one into its own file, updating imports across the
  /// project.
  Future<void> _splitClasses(ProjectNode node, int classCount) async {
    final confirmed = await MessageBox.confirm(
      context,
      title: 'Split ${node.name}?',
      message:
          'Move ${classCount - 1} of its $classCount public classes into '
          'their own files and update imports across the project?',
      confirmLabel: 'Split',
    );
    if (!confirmed || !mounted) return;

    setState(() => _splittingPath = node.path);
    try {
      var createdFiles = const <String>[];
      await ref.read(openDocumentsProvider.notifier).applyEdits(() async {
        final result = await ref
            .read(classSplitServiceProvider)
            .plan(projectPath: projectRoot!.path, filePath: node.path);
        createdFiles = result.createdFiles;
        return result.files;
      });
      if (!mounted) return;
      MessageBox.showSuccess(
        context,
        'Moved into ${createdFiles.map(p.basename).join(', ')}',
      );
    } catch (e) {
      if (mounted) MessageBox.showError(context, 'Split failed: $e');
    } finally {
      if (mounted) setState(() => _splittingPath = null);
    }
  }
}
