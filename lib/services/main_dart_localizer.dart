import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:fide/models/dart_imports.dart';
import 'package:logging/logging.dart';

part 'main_dart_localizer.material_app_title_visitor.dart';

/// Reads and rewrites the text of a project's `main.dart` for
/// localization: its `MaterialApp` title, whether the generated
/// `AppLocalizations` are wired in, and wiring them.
class MainDartLocalizer {
  static final Logger _logger = Logger('MainDartLocalizer');

  /// Title kept when `main.dart` sets none.
  static const String defaultTitle = 'My App';

  /// The generated class every localized app uses.
  static const String _localizationsClass = 'AppLocalizations';

  /// The `MaterialApp` argument wiring the generated delegates.
  static const String _delegates =
      'localizationsDelegates: $_localizationsClass.localizationsDelegates';

  /// The `MaterialApp` argument listing the generated locales.
  static const String _locales =
      'supportedLocales: $_localizationsClass.supportedLocales';

  /// The `MaterialApp` argument looking the title up.
  static const String _titleLookup = 'onGenerateTitle';

  /// A plain `title: '...'` argument.
  static final RegExp _titleArgument = RegExp(r"title\s*:\s*'([^']*)'");

  /// A `MaterialApp(` call.
  static final RegExp _materialApp = RegExp(r'MaterialApp\s*\(');

  const MainDartLocalizer._();

  /// The string literal [content] passes as `MaterialApp(title:)`; null
  /// when it passes none or does not parse.
  static String? appTitle(String content) {
    try {
      final visitor = _MaterialAppTitleVisitor();
      parseString(content: content).unit.accept(visitor);
      return visitor.title;
    } catch (e) {
      _logger.severe('Error parsing main.dart: $e');
      return null;
    }
  }

  /// Whether [content] wires the generated localizations into its app.
  static bool isLocalized(String content) =>
      content.contains(_localizationsClass) &&
      content.contains('localizationsDelegates') &&
      content.contains('supportedLocales');

  /// [content] with the generated localizations imported from
  /// [importUri], the title looked up with `onGenerateTitle` (keeping the
  /// old one as the fallback) and the delegates and locales passed to
  /// `MaterialApp`; what it already has is left as it is.
  static String localize(String content, {required String importUri}) {
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
        "      $_localizationsClass.of(context)?.appTitle ?? '$title'",
      );
    }
    if (!localized.contains(_delegates)) {
      if (_materialApp.firstMatch(localized) case final match?) {
        localized = localized.replaceRange(
          match.end,
          match.end,
          '\n  $_delegates,\n  $_locales,\n',
        );
      }
    }
    return localized;
  }
}
