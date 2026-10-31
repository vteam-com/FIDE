import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// The `flutter gen-l10n` settings of a project, from its `l10n.yaml` or
/// Flutter's defaults: where the ARB files are and how the generated class
/// is imported and looked up.
class L10nConfig {
  /// Creates settings; every value defaults to Flutter's.
  const L10nConfig({
    this.arbDir = _defaultArbDir,
    this.templateArbFile = _defaultTemplateArbFile,
    this.outputClass = _defaultOutputClass,
    this.outputFile = _defaultOutputFile,
    this.outputDir,
    this.nullableGetter = true,
    this.syntheticPackage = false,
  });

  static const String _defaultArbDir = 'lib/l10n';
  static const String _defaultTemplateArbFile = 'app_en.arb';
  static const String _defaultOutputClass = 'AppLocalizations';
  static const String _defaultOutputFile = 'app_localizations.dart';

  /// An ARB file name: a prefix ending with `_`, then a locale such as
  /// `en`, `pt_BR`, `zh_Hant_TW` or `es_419`.
  static final RegExp _arbFileName = RegExp(
    r'^(?<prefix>.*_)(?<locale>[a-z]{2,3}(?:_(?:[A-Z][a-z]{3}|[A-Z]{2}|[0-9]{3}))*)\.arb$',
  );

  /// The settings file `flutter gen-l10n` reads.
  static const String fileName = 'l10n.yaml';

  /// Project-relative folder of the ARB files.
  final String arbDir;

  /// Whether `of(context)` returns a nullable instance, needing `!`.
  final bool nullableGetter;

  /// Name of the generated class.
  final String outputClass;

  /// Project-relative folder of the generated files; [arbDir] when null.
  final String? outputDir;

  /// File name of the generated class.
  final String outputFile;

  /// Whether the classes are generated into the `flutter_gen` package.
  final bool syntheticPackage;

  /// File name of the ARB file new messages are added to.
  final String templateArbFile;

  /// Reads the settings of the project at [projectPath]; the defaults when
  /// it has no valid `l10n.yaml`.
  static Future<L10nConfig> read(String projectPath) async {
    final file = File(p.join(projectPath, fileName));
    if (!await file.exists()) return const L10nConfig();
    final Object? yaml = loadYaml(await file.readAsString());
    if (yaml is! YamlMap) return const L10nConfig();
    String text(String key, String fallback) =>
        yaml[key] is String ? yaml[key] as String : fallback;
    return L10nConfig(
      arbDir: text('arb-dir', _defaultArbDir),
      templateArbFile: text('template-arb-file', _defaultTemplateArbFile),
      outputClass: text('output-class', _defaultOutputClass),
      outputFile: text('output-localization-file', _defaultOutputFile),
      outputDir: yaml['output-dir'] as String?,
      nullableGetter: yaml['nullable-getter'] != false,
      syntheticPackage: yaml['synthetic-package'] == true,
    );
  }

  /// The import of the generated class for the package [packageName].
  String importUri(String packageName) {
    if (syntheticPackage) return 'package:flutter_gen/gen_l10n/$outputFile';
    final inLib = p.posix.relative(outputDir ?? arbDir, from: 'lib');
    return 'package:$packageName/$inLib/$outputFile';
  }

  /// [templateArbFile] split into the file prefix every ARB file shares
  /// and the template's locale (`app_en.arb` → `app_`, `en`); null for a
  /// name without a `_<locale>.arb` suffix.
  ({String prefix, String locale})? get templateParts {
    final match = _arbFileName.firstMatch(templateArbFile);
    if (match == null) return null;
    return (
      prefix: match.namedGroup('prefix')!,
      locale: match.namedGroup('locale')!,
    );
  }

  /// The generated class's instance for the `BuildContext` named
  /// [contextName], such as `AppLocalizations.of(context)!`.
  String lookup(String contextName) =>
      '$outputClass.of($contextName)${nullableGetter ? '!' : ''}';
}
