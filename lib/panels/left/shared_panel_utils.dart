// ignore_for_file:  avoid_print, use_build_context_synchronously

import 'dart:io';

import 'package:fide/constants.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/models/project_node.dart';
import 'package:fide/services/git_service.dart';
import 'package:fide/utils/message_box.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

part 'shared_panel_utils.file_operations.dart';
part 'shared_panel_utils.context_menu_handler.dart';

/// Shared state management for panel widgets
class PanelStateManager {
  final Logger _logger = Logger('PanelStateManager');
  final Map<String, bool> _expandedState = {};
  final TextEditingController _filterController = TextEditingController();
  String _filterQuery = '';
  ProjectNode? projectRoot;
  final GitService _gitService = GitService();
  final Set<String> _loadingDirectories = {};

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
    if (node.isDirectory) {
      bool hasMatchingDescendant = false;

      // Check if this directory or any descendant matches the filter
      if (_matchesFilter(node)) {
        hasMatchingDescendant = true;
      } else {
        // Check descendants recursively
        for (final child in node.children) {
          if (_hasMatchingDescendant(child)) {
            hasMatchingDescendant = true;
            break;
          }
        }
      }

      // If this directory has matching descendants, expand it
      if (hasMatchingDescendant) {
        _expandedState[node.path] = true;
        // Recursively expand all children that have matches
        for (final child in node.children) {
          if (child.isDirectory) {
            _expandDirectoriesWithMatchingFiles(child);
          }
        }
      }
    }
  }

  bool _hasMatchingDescendant(ProjectNode node) {
    // Check if this node matches
    if (_matchesFilter(node)) return true;

    // Check children recursively
    for (final child in node.children) {
      if (_hasMatchingDescendant(child)) return true;
    }

    return false;
  }

  bool _matchesFilter(ProjectNode node) {
    if (_filterQuery.isEmpty) return true;
    return node.name.toLowerCase().contains(_filterQuery);
  }

  /// Handles `PanelStateManager.ensureDirectoryLoaded`.
  Future<void> ensureDirectoryLoaded(ProjectNode node) async {
    if (node.children.isEmpty && node.isDirectory) {
      // Mark this directory as loading
      _loadingDirectories.add(node.path);

      try {
        await node.enumerateContents();
      } catch (e) {
        _logger.warning('Failed to load directory ${node.name}: $e');
      } finally {
        _loadingDirectories.remove(node.path);
      }
    }
  }

  /// Handles `PanelStateManager.seedGitStatusForFile`.
  Future<void> seedGitStatusForFile(ProjectNode node) async {
    if (projectRoot == null) return;

    try {
      // Check if current directory is a Git repository
      final isGitRepo = await _gitService.isGitRepository(projectRoot!.path);
      if (!isGitRepo) return;

      // Get Git status for this specific file
      final gitStatus = await _gitService.getStatus(projectRoot!.path);
      final relativePath = path.relative(node.path, from: projectRoot!.path);

      if (gitStatus.staged.contains(relativePath)) {
        node.gitStatus = GitFileStatus.added;
      } else if (gitStatus.unstaged.contains(relativePath)) {
        node.gitStatus = GitFileStatus.modified;
      } else if (gitStatus.untracked.contains(relativePath)) {
        node.gitStatus = GitFileStatus.untracked;
      } else {
        node.gitStatus = GitFileStatus.clean;
      }
    } catch (e) {
      _logger.severe('Error seeding Git status for file: $e');
    }
  }
}
