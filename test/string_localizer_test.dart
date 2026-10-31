import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/models/arb_keys.dart';
import 'package:fide/models/arb_message.dart';
import 'package:fide/models/l10n_config.dart';
import 'package:fide/models/hardcoded_string.dart';
import 'package:fide/providers/string_localizer.dart';
import 'package:flutter_test/flutter_test.dart';

/// The site of [literal] in [content], as fCheck reports it.
fcheck.HardcodedStringSite _siteOf(
  String content,
  String literal, {
  List<String> textParts = const [],
  List<String> interpolations = const [],
  String? buildContextName = 'context',
  String? calleeName = 'Text',
  String? argumentName,
  List<int> constKeywordOffsets = const [],
}) => fcheck.HardcodedStringSite(
  offset: content.indexOf(literal),
  length: literal.length,
  textParts: textParts.isEmpty
      ? [literal.substring(1, literal.length - 1)]
      : textParts,
  interpolations: interpolations,
  isWidgetOutput: true,
  buildContextName: buildContextName,
  calleeName: calleeName,
  argumentName: argumentName,
  constKeywordOffsets: constKeywordOffsets,
);

/// [site] in the file `/p/lib/page.dart`.
HardcodedString _string(fcheck.HardcodedStringSite site) =>
    HardcodedString(path: '/p/lib/page.dart', line: 1, site: site);

void main() {
  group('ArbMessage', () {
    test('turns interpolations into named placeholders', () {
      const content = r"Text('Error: $error in ${file.name}')";
      final message = ArbMessage.fromSite(
        _siteOf(
          content,
          r"'Error: $error in ${file.name}'",
          textParts: ['Error: ', ' in ', ''],
          interpolations: ['error', 'file.name'],
        ),
      );

      expect(message.text, 'Error: {error} in {name}');
      expect(
        message.lookup('l10n', 'errorIn'),
        'l10n.errorIn(error, file.name)',
      );
      expect(message.keyBase, 'errorIn');
      expect(message.metadata.keys, ['placeholders']);
    });

    test('cannot express text with braces', () {
      const content = "Text('{json}')";
      final message = ArbMessage.fromSite(_siteOf(content, "'{json}'"));

      expect(message.isExpressible, isFalse);
    });
  });

  group('ArbKeys', () {
    test('reuses the key of the same message and avoids clashes', () {
      final keys = ArbKeys({'cancel': 'Cancel', 'unknownVenue': 'Other'});
      const content = "Text('Cancel') Text('Unknown Venue') Text('of')";
      ArbMessage message(String literal) =>
          ArbMessage.fromSite(_siteOf(content, literal));

      expect(keys.keyFor(message("'Cancel'")), 'cancel');
      expect(keys.keyFor(message("'Unknown Venue'")), 'unknownVenue2');
      expect(keys.keyFor(message("'of'")), 'ofText');
      expect(keys.added.keys, ['unknownVenue2', 'ofText']);
    });
  });

  group('StringLocalizer.rewriteSource', () {
    test('replaces the string, drops const and adds the import', () {
      const content = '''
import 'package:flutter/material.dart';

Widget build(BuildContext context) => const Center(child: Text('Hi there'));
''';
      final rewrite = StringLocalizer.rewriteSource(
        content,
        [
          _string(
            _siteOf(
              content,
              "'Hi there'",
              constKeywordOffsets: [content.indexOf('const')],
            ),
          ),
        ],
        config: const L10nConfig(),
        keys: ArbKeys({}),
        importUri: 'package:app/l10n/app_localizations.dart',
      );

      expect(rewrite.localized, 1);
      expect(rewrite.content, '''
import 'package:app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

Widget build(BuildContext context) => Center(child: Text(AppLocalizations.of(context)!.hiThere));
''');
    });

    test('leaves strings whose file changed since the analysis', () {
      const analyzed = "Text('Hi there')";
      final site = _siteOf(analyzed, "'Hi there'");
      final rewrite = StringLocalizer.rewriteSource(
        'Text(other)',
        [_string(site)],
        config: const L10nConfig(),
        keys: ArbKeys({}),
        importUri: 'package:app/l10n/app_localizations.dart',
      );

      expect(rewrite.localized, 0);
      expect(rewrite.changed, 1);
      expect(rewrite.content, 'Text(other)');
    });
  });

  group('L10nConfig', () {
    test('splits the template ARB name into prefix and locale', () {
      expect(const L10nConfig().templateParts, (prefix: 'app_', locale: 'en'));
      expect(
        const L10nConfig(templateArbFile: 'intl_pt_BR.arb').templateParts,
        (prefix: 'intl_', locale: 'pt_BR'),
      );
      expect(const L10nConfig(templateArbFile: 'my_app_en.arb').templateParts, (
        prefix: 'my_app_',
        locale: 'en',
      ));
      expect(
        const L10nConfig(templateArbFile: 'strings.arb').templateParts,
        isNull,
      );
    });

    test('imports from the ARB folder and looks up with !', () {
      const config = L10nConfig();

      expect(
        config.importUri('my_app'),
        'package:my_app/l10n/app_localizations.dart',
      );
      expect(config.lookup('ctx'), 'AppLocalizations.of(ctx)!');
      expect(
        const L10nConfig(nullableGetter: false).lookup('ctx'),
        'AppLocalizations.of(ctx)',
      );
    });
  });
}
