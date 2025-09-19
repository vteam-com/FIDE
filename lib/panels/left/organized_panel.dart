// ignore_for_file: deprecated_member_use, avoid_print

import 'package:flutter/material.dart';
import 'package:fide/models/project_node.dart';

import 'base_panel.dart';

/// OrganizedPanel provides a categorized view of the project
class OrganizedPanel extends BasePanel {
  const OrganizedPanel({
    super.key,
    super.onFileSelected,
    super.selectedFile,
    super.onThemeChanged,
    super.onProjectLoaded,
    super.onProjectPathChanged,
    super.initialProjectPath,
    super.showGitPanel = false,
    super.onToggleGitPanel,
  }) : super(panelMode: PanelMode.organized);

  @override
  BasePanelState<OrganizedPanel> createState() => OrganizedPanelState();
}

class OrganizedPanelState extends BasePanelState<OrganizedPanel> {
  @override
  Widget buildPanelContent() {
    if (projectRoot == null) {
      return Container(
        color: Theme.of(context).colorScheme.inverseSurface,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.folder_open, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              const Text('No project loaded'),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: pickDirectory,
                icon: const Icon(Icons.folder_open),
                label: const Text('Open Project'),
              ),
            ],
          ),
        ),
      );
    }

    return _buildOrganizedView();
  }

  Widget _buildOrganizedView() {
    if (projectRoot == null) return const SizedBox();

    // Group files and directories by categories
    final Map<String, List<ProjectNode>> categories = {
      'Root': [],
      'Lib': [],
      'Tests': [],
      'Assets': [],
      'Platforms': [],
      'Output': [],
    };

    // Find lib, test, and assets directories
    ProjectNode? libDir;
    ProjectNode? testDir;
    ProjectNode? assetsDir;

    for (final node in projectRoot!.children) {
      if (node.name == 'lib' && node.isDirectory) {
        libDir = node;
      } else if (node.name == 'test' && node.isDirectory) {
        testDir = node;
      } else if (node.name == 'assets' && node.isDirectory) {
        assetsDir = node;
      }
    }

    // Ensure lib directory contents are loaded
    if (libDir != null) {
      ensureDirectoryLoaded(libDir);
      if (libDir.children.isNotEmpty) {
        categories['Lib']!.addAll(libDir.children);
      }
    }

    // Ensure test directory contents are loaded
    if (testDir != null) {
      ensureDirectoryLoaded(testDir);
      if (testDir.children.isNotEmpty) {
        categories['Tests']!.addAll(testDir.children);
      }
    }

    // Ensure assets directory contents are loaded
    if (assetsDir != null) {
      ensureDirectoryLoaded(assetsDir);
      if (assetsDir.children.isNotEmpty) {
        categories['Assets']!.addAll(assetsDir.children);
      }
    }

    // Categorize remaining nodes
    for (final node in projectRoot!.children) {
      if (node == libDir || node == testDir || node == assetsDir) {
        // Skip lib, test, and assets directories as we already processed their contents
        continue;
      }

      if (node.name == 'android' ||
          node.name == 'ios' ||
          node.name == 'web' ||
          node.name == 'windows' ||
          node.name == 'macos' ||
          node.name == 'linux') {
        categories['Platforms']!.add(node);
      } else if (node.name == 'build' ||
          node.name == '.dart_tool' ||
          node.name == 'benchmark') {
        categories['Output']!.add(node);
      } else {
        categories['Root']!.add(node);
      }
    }

    // Deduplicate categories
    for (final category in categories.keys) {
      final uniqueNodes = <String, ProjectNode>{};
      for (final node in categories[category]!) {
        uniqueNodes[node.path] = node;
      }
      categories[category] = uniqueNodes.values.toList();
    }

    // Build the organized view
    final List<Widget> sections = [];

    for (final category in [
      'Root',
      'Lib',
      'Tests',
      'Assets',
      'Platforms',
      'Output',
    ]) {
      final nodes = categories[category]!;
      if (nodes.isNotEmpty) {
        sections.add(_buildCategorySection(category, nodes));
      }
    }

    return SingleChildScrollView(child: Column(children: sections));
  }

  Widget _buildCategorySection(String category, List<ProjectNode> nodes) {
    final isExpanded = expandedState['category_$category'] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category header
        InkWell(
          onTap: () {
            if (mounted) {
              setState(() {
                expandedState['category_$category'] = !isExpanded;
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.expand_more : Icons.chevron_right,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  category,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${nodes.length})',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Category content
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: nodes.map((node) => _buildNode(node)).toList(),
            ),
          ),
      ],
    );
  }

  // Helper method to build node widget
  Widget _buildNode(ProjectNode node) {
    if (node.isDirectory) {
      return buildDirectoryNode(node);
    } else {
      return buildFileNode(node);
    }
  }
}
