import 'dart:io';
import 'dart:math';

import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/constants/constants.dart';
import 'package:fide/models/code_category.dart';
import 'package:fide/models/project_categories.dart';
import 'package:fide/models/project_node.dart';
import 'package:fide/services/arb_service.dart';
import 'package:fide/services/asset_categorizer.dart';
import 'package:fide/services/project_tree_reader.dart';
import 'package:path/path.dart' as p;

part 'project_categorizer.class_counts.dart';

/// Groups a project's files into [CodeCategory] sections.
///
/// Entries of each category's folders go there. Other Dart files under
/// `lib` are sorted by content: an app (`MaterialApp(`) is a view, a widget
/// subclass a widget. Files outside views that call `showDialog` move to
/// dialogs. Assets are grouped apart, by [AssetCategorizer].
class ProjectCategorizer {
  final ProjectTreeReader _reader;

  final AssetCategorizer _assets;

  /// Creates a categorizer that loads unread folders with [_reader] and
  /// groups assets with [_assets].
  const ProjectCategorizer(this._reader, this._assets);

  /// Groups the tree under [root], counting classes from fCheck's analysis
  /// [code] of the project; without it, while it runs, each Dart file
  /// counts as one class.
  Future<ProjectCategories> categorize(
    ProjectNode root, [
    fcheck.ProjectMetrics? code,
  ]) async {
    final nodes = {
      for (final category in CodeCategory.values) category: <ProjectNode>[],
    };
    for (final category in CodeCategory.values) {
      for (final directory in category.directories) {
        final node = _findDirectory(root, directory);
        if (node == null) continue;
        if (node.children.isEmpty) await _reader.loadChildren(node);
        nodes[category]!.addAll(node.children);
      }
    }

    final categorized = {
      for (final list in nodes.values) ..._files(list).map((node) => node.path),
    };
    final lib = _findDirectory(root, 'lib');
    final unmatched = lib == null
        ? const <ProjectNode>[]
        : _files([
            lib,
          ]).where((node) => _isDart(node) && !categorized.contains(node.path));
    for (final file in unmatched) {
      final content = await _read(file);
      if (content == null) continue;
      if (content.contains('MaterialApp(')) {
        nodes[CodeCategory.views]!.add(file);
      } else if (_declaresWidget(content)) {
        nodes[CodeCategory.widgets]!.add(file);
      }
    }

    final viewsWithDialogs = <String>{};
    for (final category in CodeCategory.values) {
      if (category == CodeCategory.dialogs) continue;
      final moved = <ProjectNode>[];
      for (final node in nodes[category]!.where(_isDart)) {
        if (!((await _read(node))?.contains('showDialog') ?? false)) continue;
        if (category == CodeCategory.views) {
          viewsWithDialogs.add(node.path);
        } else {
          moved.add(node);
        }
      }
      nodes[category]!.removeWhere(moved.contains);
      nodes[CodeCategory.dialogs]!.addAll(moved);
    }

    final classes = _ClassCounts(code);
    final counts = {
      for (final entry in nodes.entries)
        entry.key: await _countElements(entry.key, entry.value, classes),
    };

    final multiClassFiles = {
      for (final entry in counts.values) ...entry.multiClassFiles,
    };

    return ProjectCategories(
      nodes: {
        for (final entry in nodes.entries)
          entry.key: entry.value..sort(ProjectNode.compareInTree),
      },
      elementCounts: {
        for (final entry in counts.entries) entry.key: entry.value.elements,
      },
      publicClassCounts: {
        for (final entry in counts.entries)
          entry.key: entry.value.publicClasses,
      },
      sourceFileCounts: {
        for (final entry in nodes.entries)
          entry.key: _files(entry.value).where(_isDart).length,
      },
      viewsWithDialogs: viewsWithDialogs,
      multiClassFiles: multiClassFiles,
      multiClassFolders: _foldersHolding(root.path, multiClassFiles.keys),
      assets: await _assets.categorize(root),
    );
  }

  /// Each folder under [rootPath] holding any of [filePaths], at any depth,
  /// mapped to how many of them it holds.
  static Map<String, int> _foldersHolding(
    String rootPath,
    Iterable<String> filePaths,
  ) {
    final folders = <String, int>{};
    for (final filePath in filePaths) {
      for (
        var folder = p.dirname(filePath);
        p.isWithin(rootPath, folder);
        folder = p.dirname(folder)
      ) {
        folders.update(folder, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    return folders;
  }

  /// Dart files count their top-level classes, at least one each; ARB
  /// files in [category] localization count their translations.
  ///
  /// `publicClasses` counts one per Dart file that follows fCheck's one
  /// class per file rule, and the public classes of each that breaks it,
  /// which `multiClassFiles` maps to that count.
  Future<({int elements, int publicClasses, Map<String, int> multiClassFiles})>
  _countElements(
    CodeCategory category,
    List<ProjectNode> nodes,
    _ClassCounts classes,
  ) async {
    var elements = 0;
    var publicClasses = 0;
    final multiClassFiles = <String, int>{};
    for (final file in _files(nodes)) {
      if (_isDart(file)) {
        elements += max(_ClassCounts.minPerFile, classes.declaredIn(file.path));
        final rulePublicClasses = classes.breakingRuleIn(file.path);
        publicClasses += rulePublicClasses ?? _ClassCounts.minPerFile;
        if (rulePublicClasses != null) {
          multiClassFiles[file.path] = rulePublicClasses;
        }
      } else if (category == CodeCategory.localization &&
          file.path.endsWith('.arb')) {
        final content = await _read(file);
        elements += content == null ? 0 : ArbService.countEntries(content) ?? 0;
      }
    }
    return (
      elements: elements,
      publicClasses: publicClasses,
      multiClassFiles: multiClassFiles,
    );
  }

  /// Whether [content] declares a class extending a `...Widget` type.
  ///
  /// fCheck's public results don't say which files declare widgets yet.
  static bool _declaresWidget(String content) {
    return RegExp(r'class\s+(\w+)\s+extends\s+(\w+)')
        .allMatches(content)
        .any(
          (match) => match
              .group(AppMetric.regexBaseClassGroupIndex)!
              .endsWith('Widget'),
        );
  }

  /// The loaded directory at project-relative [relativePath], or null.
  static ProjectNode? _findDirectory(ProjectNode root, String relativePath) {
    ProjectNode? current = root;
    for (final part in relativePath.split('/')) {
      current = current?.children
          .where((child) => child.isDirectory && child.name == part)
          .firstOrNull;
    }
    return current;
  }

  /// Every file in [nodes] and their loaded subtrees.
  static Iterable<ProjectNode> _files(Iterable<ProjectNode> nodes) sync* {
    for (final node in nodes) {
      if (node.isDirectory) {
        yield* _files(node.children);
      } else {
        yield node;
      }
    }
  }

  static bool _isDart(ProjectNode node) =>
      !node.isDirectory && node.path.endsWith('.dart');

  /// [node]'s content, or null when it can't be read.
  static Future<String?> _read(ProjectNode node) async {
    try {
      return await File(node.path).readAsString();
    } on FileSystemException {
      return null;
    }
  }
}
