import 'package:fide/models/pub_outdated.dart';
import 'package:yaml_edit/yaml_edit.dart';

/// Rewrites pubspec constraints to newer versions: text in, text out, with
/// no process or disk access.
abstract final class PubspecUpgrader {
  /// Raises the constraints of the direct and dev dependencies in
  /// [pubspecYaml] that [outdated] reports a newer resolvable version for,
  /// keeping its formatting and comments.
  ///
  /// Returns the new text and the packages raised; a package the pubspec
  /// doesn't declare where pub says it does is left alone.
  static ({String yaml, List<PubOutdatedPackage> upgraded}) upgrade(
    String pubspecYaml,
    PubOutdated outdated,
  ) {
    final editor = YamlEditor(pubspecYaml);
    final upgraded = <PubOutdatedPackage>[];
    for (final package in outdated.upgradable) {
      final path = [package.pubspecSection, package.name];
      try {
        // Parse at the path to make sure it exists
        editor.parseAt(path);
        editor.update(path, package.resolvable);
        upgraded.add(package);
      } on ArgumentError {
        // Not declared where pub says: skip it
      }
    }
    return (yaml: editor.toString(), upgraded: upgraded);
  }
}
