import 'dart:io';
import 'dart:math';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/code_category.dart';
import 'package:fide/models/project_categories.dart';
import 'package:fide/models/project_node.dart';
import 'package:fide/providers/localization_service.dart';
import 'package:fide/providers/project_tree_reader.dart';

/// Groups a project's files into [CodeCategory] sections.
///
/// Entries of each category's folders go there. Other Dart files under
/// `lib` are sorted by content: an app (`MaterialApp(`) is a view, a widget
/// subclass a widget. Files outside views that call `showDialog` move to
/// dialogs.
class ProjectCategorizer {
  final ProjectTreeReader _reader;

  /// Creates a categorizer that loads unread folders with [_reader].
  const ProjectCategorizer([this._reader = const ProjectTreeReader()]);

  /// Groups the tree under [root].
  Future<ProjectCategories> categorize(ProjectNode root) async {
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

    final counts = {
      for (final entry in nodes.entries)
        entry.key: await _countElements(entry.key, entry.value),
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
    );
  }

  /// Dart files count their top-level classes, at least one each; ARB
  /// files in [category] localization count their translations.
  ///
  /// `publicClasses` counts only the Dart files' public classes, also at
  /// least one per file, since private helpers may share a file.
  Future<({int elements, int publicClasses})> _countElements(
    CodeCategory category,
    List<ProjectNode> nodes,
  ) async {
    var elements = 0;
    var publicClasses = 0;
    for (final file in _files(nodes)) {
      if (_isDart(file)) {
        final names = _classNames((await _read(file)) ?? '');
        elements += max(_minElementsPerDartFile, names.length);
        publicClasses += max(
          _minElementsPerDartFile,
          names.where((name) => !name.startsWith('_')).length,
        );
      } else if (category == CodeCategory.localization &&
          file.path.endsWith('.arb')) {
        final content = await _read(file);
        elements += content == null ? 0 : ArbService.countEntries(content) ?? 0;
      }
    }
    return (elements: elements, publicClasses: publicClasses);
  }

  /// A Dart file counts as one element even when it declares no class.
  static const int _minElementsPerDartFile = 1;

  /// Matches a top-level class declaration, with any class modifiers,
  /// capturing the class name.
  static final RegExp _classDeclaration = RegExp(
    r'^(?:(?:abstract|base|final|interface|mixin|sealed)\s+)*class\s+(\w+)',
    multiLine: true,
  );

  /// Names of the top-level classes declared in [content].
  static List<String> _classNames(String content) => [
    for (final match in _classDeclaration.allMatches(content)) match.group(1)!,
  ];

  /// Whether [content] declares a class extending a `...Widget` type.
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
