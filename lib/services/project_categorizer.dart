import 'dart:io';
import 'dart:math';

import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/constants/constants.dart';
import 'package:fide/models/code_category.dart';
import 'package:fide/models/file_stamp.dart';
import 'package:fide/models/project_categories.dart';
import 'package:fide/models/project_node.dart';
import 'package:fide/models/project_paths.dart';
import 'package:fide/services/arb_service.dart';
import 'package:fide/services/asset_categorizer.dart';
import 'package:fide/services/file_type_utils.dart';
import 'package:fide/services/project_tree_reader.dart';
import 'package:path/path.dart' as p;

part 'project_categorizer.class_counts.dart';
part 'project_categorizer.file_facts.dart';

/// Groups a project's files into [CodeCategory] sections.
///
/// Entries of each category's folders go there. Other Dart files under
/// `lib` are sorted by content: an app (`MaterialApp(`) is a view, a widget
/// subclass a widget. Files outside views that call `showDialog` move to
/// dialogs. Assets are grouped apart, by [AssetCategorizer].
///
/// Each file is read at most once per run, and not again in later runs
/// while it keeps its date and size.
class ProjectCategorizer {
  final ProjectTreeReader _reader;

  final AssetCategorizer _assets;

  /// Reads a file's content.
  final Future<String> Function(String path) _readFile;

  /// The facts of the files read, by path, kept across runs.
  final Map<String, _FileFacts> _facts = {};

  /// Creates a categorizer that loads unread folders with [_reader],
  /// groups assets with [_assets] and reads files with [_readFile]
  /// (from disk by default).
  ProjectCategorizer(
    this._reader,
    this._assets, {
    this._readFile = _readFromDisk,
  });

  /// The content of the file at [path] on disk.
  static Future<String> _readFromDisk(String path) => File(path).readAsString();

  /// Groups the tree under [root], counting classes from fCheck's analysis
  /// [code] of the project; without it, while it runs, each Dart file
  /// counts as one class.
  Future<ProjectCategories> categorize(
    ProjectNode root, [
    fcheck.ProjectMetrics? code,
  ]) async {
    final read = <String, Future<_FileFacts?>>{};
    Future<_FileFacts?> factsOf(ProjectNode node) =>
        read.putIfAbsent(node.path, () => _factsOf(node.path));

    final nodes = {
      for (final category in CodeCategory.values) category: <ProjectNode>[],
    };
    for (final category in CodeCategory.values) {
      for (final directory in category.directories) {
        final node = root.descendantAt(directory);
        if (node == null || node.isFile) continue;
        if (node.children.isEmpty) await _reader.loadChildren(node);
        nodes[category]!.addAll(node.children);
      }
    }

    final categorized = {
      for (final list in nodes.values) ..._files(list).map((node) => node.path),
    };
    final lib = root.descendantAt(ProjectPaths.libFolder);
    final unmatched = lib == null || lib.isFile
        ? const <ProjectNode>[]
        : lib.files().where(
            (node) => _isDart(node) && !categorized.contains(node.path),
          );
    for (final file in unmatched) {
      final facts = await factsOf(file);
      if (facts == null) continue;
      if (facts.isApp) {
        nodes[CodeCategory.views]!.add(file);
      } else if (facts.declaresWidget) {
        nodes[CodeCategory.widgets]!.add(file);
      }
    }

    final viewsWithDialogs = <String>{};
    for (final category in CodeCategory.values) {
      if (category == CodeCategory.dialogs) continue;
      final moved = <ProjectNode>{};
      for (final node in nodes[category]!.where(_isDart)) {
        if (!((await factsOf(node))?.showsDialog ?? false)) continue;
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
        entry.key: await _countElements(
          entry.key,
          entry.value,
          classes,
          factsOf,
        ),
    };
    // Forget the files no longer in the project
    _facts.removeWhere((path, _) => !read.containsKey(path));

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
  /// which `multiClassFiles` maps to that count. ARB files are read
  /// through [factsOf].
  Future<({int elements, int publicClasses, Map<String, int> multiClassFiles})>
  _countElements(
    CodeCategory category,
    List<ProjectNode> nodes,
    _ClassCounts classes,
    Future<_FileFacts?> Function(ProjectNode node) factsOf,
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
          file.path.endsWith(ArbService.arbExtension)) {
        elements += (await factsOf(file))?.arbEntries ?? 0;
      }
    }
    return (
      elements: elements,
      publicClasses: publicClasses,
      multiClassFiles: multiClassFiles,
    );
  }

  /// Every file in [nodes] and their loaded subtrees.
  static Iterable<ProjectNode> _files(Iterable<ProjectNode> nodes) =>
      nodes.expand((node) => node.files());

  static bool _isDart(ProjectNode node) =>
      !node.isDirectory && FileTypeUtils.isDartFile(node.path);

  /// The facts of the file at [path], read again only when it changed
  /// since the last run; null when it can't be read.
  Future<_FileFacts?> _factsOf(String path) async {
    try {
      final stat = await File(path).stat();
      if (stat.type == FileSystemEntityType.notFound) return null;
      final cached = _facts[path];
      if (cached != null && cached.isCurrent(stat)) return cached;
      return _facts[path] = _FileFacts(path, await _readFile(path), stat);
    } on FileSystemException {
      return null;
    }
  }
}
