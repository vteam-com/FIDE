// ignore_for_file:  avoid_print, use_build_context_synchronously

import 'package:fide/models/file_system_item.dart';
import 'package:fide/models/project_node.dart';
import 'package:fide/providers/git_repo_controller.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/desktop_shell.dart';
import 'package:fide/services/file_entry_service.dart';
import 'package:fide/services/git_service.dart';
import 'package:fide/services/project_tree_reader.dart';
import 'package:fide/widgets/icon_menu_row.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/more_menu_button.dart';
import 'package:fide/widgets/no_project_placeholder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

part 'shared_panel_utils.file_operations.dart';
part 'shared_panel_utils.context_menu_handler.dart';
part 'shared_panel_utils.node_action.dart';
part 'shared_panel_utils.project_tree_panel.dart';
part 'shared_panel_utils.project_tree_panel_state.dart';

/// Shared state management for panel widgets
class PanelStateManager {
  final Map<String, bool> _expandedState = {};
  final TextEditingController _filterController = TextEditingController();
  String _filterQuery = '';
  ProjectNode? projectRoot;
  final ProjectTreeReader _reader;

  /// Creates panel state that reads folders with [_reader].
  PanelStateManager(this._reader);

  // Getters
  /// Returns `expandedState`.
  Map<String, bool> get expandedState => _expandedState;

  /// Returns `filterController`.
  TextEditingController get filterController => _filterController;

  /// Returns `filterQuery`.
  String get filterQuery => _filterQuery;

  /// Handles `PanelStateManager.initialize`.
  void initialize() {
    _filterController.addListener(_onFilterChanged);
  }

  /// Handles `PanelStateManager.dispose`.
  void dispose() {
    _filterController.removeListener(_onFilterChanged);
    _filterController.dispose();
  }

  /// Handles `_onFilterChanged`.
  void _onFilterChanged() {
    _filterQuery = _filterController.text.toLowerCase();
    // Clear expansion state when filter changes
    _expandedState.clear();
    // Expand directories that contain matching files when filtering
    if (_filterQuery.isNotEmpty && projectRoot != null) {
      /// Handles `_expandDirectoriesWithMatchingFiles`.
      _expandDirectoriesWithMatchingFiles(projectRoot!);
    }
  }

  /// Handles `_expandDirectoriesWithMatchingFiles`.
  void _expandDirectoriesWithMatchingFiles(ProjectNode node) {
    if (!node.isDirectory || !hasMatchingDescendant(node)) return;
    _expandedState[node.path] = true;
    for (final child in node.children) {
      _expandDirectoriesWithMatchingFiles(child);
    }
  }

  /// Whether [node] or anything below it matches the filter.
  bool hasMatchingDescendant(ProjectNode node) {
    return matchesFilter(node) || node.children.any(hasMatchingDescendant);
  }

  /// Whether [node]'s name matches the filter; everything matches when empty.
  bool matchesFilter(ProjectNode node) {
    return _filterQuery.isEmpty ||
        node.name.toLowerCase().contains(_filterQuery);
  }

  /// Loads [node]'s children if it is a directory that hasn't been loaded.
  Future<LoadChildrenResult> ensureDirectoryLoaded(ProjectNode node) async {
    if (!node.isDirectory || node.children.isNotEmpty) {
      return LoadChildrenResult.success;
    }
    return _reader.loadChildren(node);
  }

  /// Tags [node] with its change in [status], the project's Git status;
  /// leaves it as is while the status is unknown.
  void seedGitStatusForFile(ProjectNode node, GitStatus? status) {
    final root = projectRoot;
    if (root == null || status == null) return;
    node.gitStatus = status.statusOf(p.relative(node.path, from: root.path));
  }
}
