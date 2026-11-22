import 'dart:io';
import 'dart:isolate';

import 'package:fide/models/dart_imports.dart';
import 'package:fide/models/project_files.dart';
import 'package:fide/models/project_paths.dart';
import 'package:fide/models/text_case.dart';
import 'package:fide/models/unique_name.dart';
import 'package:fide/services/preview_sampler.dart';
import 'package:fide/services/preview_scanner.dart';
import 'package:fide/services/preview_type_resolver.dart';

/// A widget [PreviewGenerator] couldn't preview, and the [type] of an
/// argument it requires that has no sample code can pick.
typedef PreviewSkip = ({String widget, String type});

/// What [PreviewGenerator.generate] did: the file's new content, the
/// preview functions it added, and the widgets it couldn't preview.
typedef PreviewGeneration = ({
  String content,
  List<String> added,
  List<PreviewSkip> skipped,
});

/// Writes a `@Preview` function for each widget of a file that has none,
/// by code alone, without AI: [PreviewSampler] picks each required
/// argument's sample from its type, building the project's own classes
/// and importing what they need.
class PreviewGenerator {
  /// Creates the generator.
  const PreviewGenerator();

  /// The library declaring `Preview`.
  static const String previewImport = 'package:flutter/widget_previews.dart';

  /// Adds the previews to the file at [path] of the project at
  /// [projectPath], whose content is [content], in a background isolate
  /// reading the libraries it imports and the project's other files.
  Future<PreviewGeneration> generateFile({
    required String projectPath,
    required String path,
    required String content,
  }) => Isolate.run(() async {
    final lib = ProjectPaths(projectPath).libDir;
    final files = Directory(lib).existsSync()
        ? await ProjectFiles.walk(
            lib,
            extension: ProjectFiles.dartExtension,
          ).map((file) => file.path).toList()
        : <String>[];
    final resolver = PreviewTypeResolver.ofProject(
      projectPath,
      projectFiles: files..sort(),
      contents: {path: content},
    );
    return const PreviewGenerator().generate(path, resolver);
  });

  /// Adds the previews to the file at [path], whose content and imported
  /// libraries [resolver] reads.
  PreviewGeneration generate(String path, PreviewTypeResolver resolver) {
    final content = resolver.contentOf(path);
    final scan = resolver.scanOf(path);
    final names = {...scan.topLevelNames};
    final imports = <String>{previewImport};
    final functions = <String>[];
    final added = <String>[];
    final skipped = <PreviewSkip>[];
    for (final widget in scan.widgetsWithoutPreview) {
      final sampler = PreviewSampler(resolver, target: path);
      final call = sampler.build(widget);
      if (call == null) {
        skipped.add((widget: widget.name, type: sampler.missing ?? ''));
        continue;
      }
      imports.addAll(sampler.imports);
      final name = _uniqueName(widget.name, names);
      names.add(name);
      added.add(name);
      functions.add(
        '/// A preview of [${widget.name}].\n'
        "@Preview(name: '${widget.name}')\n"
        'Widget $name() => $call;\n',
      );
    }
    if (functions.isEmpty) {
      return (content: content, added: added, skipped: skipped);
    }
    var withPreviews = '${content.trimRight()}\n\n${functions.join('\n')}';
    for (final uri in imports.toList()..sort()) {
      withPreviews = withImport(
        withPreviews,
        uri,
        isImported: (imported) => imported == uri,
      );
    }
    return (content: withPreviews, added: added, skipped: skipped);
  }

  /// A preview function name for [className] not in [taken], such as
  /// `myWidgetPreview`.
  static String _uniqueName(String className, Set<String> taken) {
    final base = '${className.uncapitalized}${PreviewScanner.previewClass}';
    return uniqueName(base, taken.contains);
  }
}
