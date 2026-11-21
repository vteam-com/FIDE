import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:fide/models/dart_imports.dart';
import 'package:fide/models/dart_parse.dart';
import 'package:fide/models/l10n_config.dart';

part 'app_widget_localizer.app_widget_visitor.dart';

/// Reads and rewrites the Dart file that builds a project's app widget
/// (`MaterialApp`, `CupertinoApp` or `WidgetsApp`, `.router` ones
/// included), wherever it is in `lib`, for localization: the app's title,
/// whether it is given localization delegates and locales, and giving it
/// the generated ones.
class AppWidgetLocalizer {
  /// Title kept when the app sets none.
  static const String defaultTitle = 'My App';

  /// ARB key of the app's title, which the title lookup reads.
  static const String titleKey = 'appTitle';

  /// The widgets building an app, which take the localization arguments.
  static const Set<String> _appWidgets = {
    'MaterialApp',
    'CupertinoApp',
    'WidgetsApp',
  };

  /// The named constructor of an app widget driven by a router.
  static const String _routerConstructor = 'router';

  /// The app widget parameter taking the localization delegates.
  static const String _delegatesParameter = 'localizationsDelegates';

  /// The app widget parameter taking the supported locales.
  static const String _localesParameter = 'supportedLocales';

  /// The app widget parameter taking a fixed title.
  static const String _titleParameter = 'title';

  /// The app widget parameter looking the title up.
  static const String _titleLookup = 'onGenerateTitle';

  /// Separates the arguments the localization adds when the app's
  /// arguments share the line of its `(`.
  static const String _inlineSeparator = ', ';

  const AppWidgetLocalizer._();

  /// The string literal [content] passes as its app widget's `title:`;
  /// null when it passes none.
  static String? appTitle(String content) {
    for (final app in _apps(content)) {
      if (_argument(app.arguments, _titleParameter)?.argumentExpression
          case StringLiteral(:final stringValue?)) {
        return stringValue;
      }
    }
    return null;
  }

  /// Whether [content] builds an app widget.
  static bool buildsApp(String content) => _apps(content).isNotEmpty;

  /// Whether [content] builds an app widget given both localization
  /// delegates and supported locales, however it computes them.
  static bool isLocalized(String content) => _apps(content).any(
    (app) =>
        _argument(app.arguments, _delegatesParameter) != null &&
        _argument(app.arguments, _localesParameter) != null,
  );

  /// [content] with its first app widget given the delegates and locales
  /// of the generated class [config] names, imported from [importUri]
  /// unless the file already imports it; when [hasTitleKey] (the ARB files
  /// have [titleKey]), the widget's fixed title is looked up instead. What
  /// the widget already has is left as it is, and [content] is returned
  /// unchanged when it builds no app widget.
  static String localize(
    String content, {
    required L10nConfig config,
    required String importUri,
    required bool hasTitleKey,
  }) {
    final app = _apps(content).firstOrNull;
    if (app == null) return content;
    final arguments = app.arguments;
    final outputClass = config.outputClass;
    final added = [
      if (_argument(arguments, _delegatesParameter) == null)
        '$_delegatesParameter: $outputClass.localizationsDelegates',
      if (_argument(arguments, _localesParameter) == null)
        '$_localesParameter: $outputClass.supportedLocales',
    ];
    final title = _argument(arguments, _titleParameter);
    // A closure can't be part of a constant
    final looksUpTitle =
        hasTitleKey &&
        !app.isConst &&
        title != null &&
        _argument(arguments, _titleLookup) == null;
    if (added.isEmpty && !looksUpTitle) return content;

    var localized = content;
    // From the end, so the offsets still hold: the title comes at or
    // after where the arguments are added
    if (looksUpTitle) {
      localized = localized.replaceRange(
        title.offset,
        title.end,
        '$_titleLookup: (BuildContext context) =>\n'
        '    ${config.lookup('context')}.$titleKey',
      );
    }
    final first = arguments.arguments.firstOrNull;
    final at = first?.offset ?? arguments.rightParenthesis.offset;
    localized = localized.replaceRange(
      at,
      at,
      first == null
          ? added.join(_inlineSeparator)
          : added
                .map((argument) => '$argument${_separator(content, at)}')
                .join(),
    );
    return withImport(localized, importUri, isImported: config.isOutputImport);
  }

  /// The app widgets [content] builds, in source order; parsed only when
  /// it names one.
  static List<_AppWidget> _apps(String content) {
    if (!_appWidgets.any(content.contains)) return const [];
    final visitor = _AppWidgetVisitor();
    parseDart(content).unit.accept(visitor);
    return visitor.apps;
  }

  /// The argument named [name] in [arguments]; null when there is none.
  static NamedArgument? _argument(ArgumentList arguments, String name) =>
      arguments.arguments
          .whereType<NamedArgument>()
          .where((argument) => argument.name.lexeme == name)
          .firstOrNull;

  /// What follows an argument added before the one at [offset] in
  /// [content]: a line break with that argument's indent when it starts
  /// its line, else [_inlineSeparator].
  static String _separator(String content, int offset) {
    final indent = content.substring(
      content.lastIndexOf('\n', offset - 1) + 1,
      offset,
    );
    return indent.trim().isEmpty ? ',\n$indent' : _inlineSeparator;
  }
}
