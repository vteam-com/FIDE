import 'package:fide/models/dart_imports.dart';
import 'package:fide/models/project_paths.dart';
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

  /// The package `synthetic-package: true` generates the classes into.
  static const String _syntheticPackage = 'flutter_gen';

  /// The folder of that package holding the generated classes.
  static const String _syntheticDir = 'gen_l10n';

  /// A localized file name, such as `app_pt_BR.arb` or
  /// `app_localizations_en.dart`: a prefix ending with `_`, then a locale
  /// such as `en`, `pt_BR`, `zh_Hant_TW` or `es_419`, then an extension.
  static final RegExp _localizedFileName = RegExp(
    r'^(?<prefix>.*_)(?<locale>[a-z]{2,3}(?:_(?:[A-Z][a-z]{3}|[A-Z]{2}|[0-9]{3}))*)\.[a-z]+$',
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

  /// Parses the `l10n.yaml` [content]; the defaults for content that
  /// isn't a YAML map.
  factory L10nConfig.parse(String content) {
    Object? yaml;
    try {
      yaml = loadYaml(content);
    } on YamlException {
      yaml = null;
    }
    if (yaml is! YamlMap) return const L10nConfig();
    final map = yaml;
    String text(String key, String fallback) =>
        map[key] is String ? map[key] as String : fallback;
    return L10nConfig(
      arbDir: text('arb-dir', _defaultArbDir),
      templateArbFile: text('template-arb-file', _defaultTemplateArbFile),
      outputClass: text('output-class', _defaultOutputClass),
      outputFile: text('output-localization-file', _defaultOutputFile),
      outputDir: map['output-dir'] as String?,
      nullableGetter: map['nullable-getter'] != false,
      syntheticPackage: map['synthetic-package'] == true,
    );
  }

  /// The ARB folder of the project at [root].
  String arbDirIn(String root) => p.join(root, arbDir);

  /// File name of the ARB file of [locale], such as `app_fr.arb`, sharing
  /// the template's prefix.
  String arbFileName(String locale) =>
      '${templateParts?.prefix ?? ''}$locale.arb';

  /// Path of the ARB file of [locale] in the project at [root].
  String arbPathFor(String root, String locale) =>
      p.join(arbDirIn(root), arbFileName(locale));

  /// Path of the generated class's file in the project at [root].
  String generatedPathIn(String root) =>
      p.join(root, outputDir ?? arbDir, outputFile);

  /// The import of the generated class for the package [packageName].
  String importUri(String packageName) {
    if (syntheticPackage) {
      return packageUriOf(
        _syntheticPackage,
        p.posix.join(_syntheticDir, outputFile),
      );
    }
    final inLib = p.posix.relative(
      outputDir ?? arbDir,
      from: ProjectPaths.libFolder,
    );
    return packageUriOf(packageName, p.posix.join(inLib, outputFile));
  }

  /// [templateArbFile] split into the file prefix every ARB file shares
  /// and the template's locale (`app_en.arb` → `app_`, `en`); null for a
  /// name without a `_<locale>.arb` suffix.
  ({String prefix, String locale})? get templateParts =>
      localeParts(templateArbFile);

  /// Path of the template ARB file of the project at [root].
  String templatePathIn(String root) => p.join(arbDirIn(root), templateArbFile);

  /// Whether the import [uri] is the generated class's.
  bool isOutputImport(String uri) => p.url.basename(uri) == outputFile;

  /// The locale of a localized [fileName], such as `pt_BR` for
  /// `app_pt_BR.arb`; null for a name without a `_<locale>` suffix.
  static String? localeOf(String fileName) => localeParts(fileName)?.locale;

  /// A localized [fileName] split into its prefix and locale
  /// (`app_pt_BR.arb` → `app_`, `pt_BR`); null for a name without a
  /// `_<locale>` suffix.
  static ({String prefix, String locale})? localeParts(String fileName) {
    final match = _localizedFileName.firstMatch(fileName);
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
