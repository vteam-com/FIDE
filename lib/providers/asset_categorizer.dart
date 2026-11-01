import 'package:fide/models/asset_kind.dart';
import 'package:fide/models/project_node.dart';
import 'package:fide/models/project_paths.dart';
import 'package:fide/models/pubspec.dart';
import 'package:fide/providers/project_tree_reader.dart';
import 'package:path/path.dart' as p;

/// Groups a project's assets by [AssetKind].
///
/// Assets are the files and folders listed under `flutter: assets:` and
/// `flutter: fonts:` in `pubspec.yaml`, plus the conventional `assets`
/// folder at the project root, read at any depth.
class AssetCategorizer {
  final ProjectTreeReader _reader;

  /// Creates a categorizer that loads unread folders with [_reader].
  const AssetCategorizer([this._reader = const ProjectTreeReader()]);

  /// The conventional project-relative assets folder, listed or not.
  static const String _assetsFolder = 'assets';

  /// The assets under [root], by kind, each list in path order; kinds
  /// without assets are left out.
  Future<Map<AssetKind, List<ProjectNode>>> categorize(ProjectNode root) async {
    final pubspec = await Pubspec.read(ProjectPaths(root.path).pubspec);
    final declared = {
      _assetsFolder,
      ...?(pubspec == null ? null : declaredAssets(pubspec.flutterSection)),
    };

    final assets = <String, ProjectNode>{};
    for (final relativePath in declared) {
      final node = await _find(root, relativePath);
      if (node == null) continue;
      if (node.isDirectory) await _reader.loadTree(node);
      for (final file in _files(node)) {
        assets[file.path] = file;
      }
    }

    final kinds = <AssetKind, List<ProjectNode>>{};
    final sorted = assets.values.toList()
      ..sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
    for (final file in sorted) {
      final kind = AssetKind.of(p.relative(file.path, from: root.path));
      kinds.putIfAbsent(kind, () => []).add(file);
    }
    return {for (final kind in AssetKind.values) kind: ?kinds[kind]};
  }

  /// Project-relative paths listed in a pubspec [flutterSection]: each
  /// `assets:` entry (a path, or a map with a `path:`) and each font
  /// `asset:`.
  static Set<String> declaredAssets(Map<String, Object?> flutterSection) {
    final assets = flutterSection['assets'];
    final fonts = flutterSection['fonts'];
    return {
      if (assets is List)
        for (final entry in assets) ...[
          if (entry case final String path) path,
          if (entry case {'path': final String path}) path,
        ],
      if (fonts is List)
        for (final family in fonts)
          if (family case {'fonts': final List familyFonts})
            for (final font in familyFonts)
              if (font case {'asset': final String path}) path,
    };
  }

  /// The node at project-relative [relativePath] under [root], loading
  /// folders on the way; null when it doesn't exist or leaves the project.
  Future<ProjectNode?> _find(ProjectNode root, String relativePath) async {
    final normalized = p.normalize(relativePath);
    if (p.isAbsolute(normalized) || normalized.startsWith('..')) return null;
    ProjectNode? current = root;
    for (final part in p.split(normalized)) {
      if (current == null || current.isFile) return null;
      if (current.children.isEmpty) await _reader.loadChildren(current);
      current = current.children
          .where((child) => child.name == part)
          .firstOrNull;
    }
    return current;
  }

  /// [node] when it is a file, else every hidden-free file in its subtree.
  static Iterable<ProjectNode> _files(ProjectNode node) sync* {
    if (node.isHidden) return;
    if (node.isFile) {
      yield node;
      return;
    }
    for (final child in node.children) {
      yield* _files(child);
    }
  }
}
