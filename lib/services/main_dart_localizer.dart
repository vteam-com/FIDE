import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:fide/models/dart_imports.dart';
import 'package:fide/models/dart_parse.dart';

part 'main_dart_localizer.material_app_title_visitor.dart';

/// Reads and rewrites the text of a project's `main.dart` for
/// localization: its `MaterialApp` title, whether the generated
/// localizations class (`output-class` in `l10n.yaml`) is wired in, and
/// wiring it.
class MainDartLocalizer {
  /// Title kept when `main.dart` sets none.
  static const String defaultTitle = 'My App';

  /// ARB key of the app's title, which the title lookup reads.
  static const String titleKey = 'appTitle';

  /// The `MaterialApp` parameter taking the generated delegates.
  static const String _delegatesParameter = 'localizationsDelegates';

  /// The `MaterialApp` parameter taking the generated locales.
  static const String _localesParameter = 'supportedLocales';

  /// The `MaterialApp` argument looking the title up.
  static const String _titleLookup = 'onGenerateTitle';

  /// A plain `title: '...'` argument.
  static final RegExp _titleArgument = RegExp(r"title\s*:\s*'([^']*)'");

  /// A `MaterialApp(` call.
  static final RegExp _materialApp = RegExp(r'MaterialApp\s*\(');

  const MainDartLocalizer._();

  /// The string literal [content] passes as `MaterialApp(title:)`; null
  /// when it passes none.
  static String? appTitle(String content) {
    final visitor = _MaterialAppTitleVisitor();
    parseDart(content).unit.accept(visitor);
    return visitor.title;
  }

  /// Whether [content] wires the generated localizations class
  /// [outputClass] into its app.
  static bool isLocalized(String content, {required String outputClass}) =>
      content.contains(outputClass) &&
      content.contains(_delegatesParameter) &&
      content.contains(_localesParameter);

  /// [content] with the generated localizations class [outputClass]
  /// imported from [importUri], the title looked up with
  /// `onGenerateTitle` (keeping the old one as the fallback) and the
  /// delegates and locales passed to `MaterialApp`; what it already has is
  /// left as it is.
  static String localize(
    String content, {
    required String importUri,
    required String outputClass,
  }) {
    final delegates =
        '$_delegatesParameter: $outputClass.localizationsDelegates';
    var localized = withImport(
      content,
      importUri,
      isImported: (uri) => uri == importUri,
    );
    if (!localized.contains(_titleLookup)) {
      final title =
          _titleArgument.firstMatch(localized)?.group(1) ?? defaultTitle;
      localized = localized.replaceAll(
        _titleArgument,
        '$_titleLookup: (BuildContext context) =>\n'
        "      $outputClass.of(context)?.$titleKey ?? '$title'",
      );
    }
    if (!localized.contains(delegates)) {
      if (_materialApp.firstMatch(localized) case final match?) {
        localized = localized.replaceRange(
          match.end,
          match.end,
          '\n  $delegates,\n'
          '  $_localesParameter: $outputClass.supportedLocales,\n',
        );
      }
    }
    return localized;
  }
}
