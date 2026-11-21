import 'package:fide/models/language_catalog.dart';
import 'package:fide/widgets/locale_badges.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('LanguageCatalog names any locale for badges, menus and the model', () {
    expect(LanguageCatalog.badgeOf('pt_BR'), 'PT_BR');
    expect(LanguageCatalog.labelOf('fr'), 'French (FR)');
    expect(LanguageCatalog.labelOf('pt_BR'), 'Portuguese (PT_BR)');
    expect(LanguageCatalog.nameOf('fr'), 'French');
    expect(LanguageCatalog.nameOf('pt_BR'), 'Portuguese (pt_BR)');
    expect(LanguageCatalog.nameOf('xx'), 'xx');
    expect(LanguageCatalog.languageOf('zh_Hant_TW'), 'zh');
  });

  /// Shows [badges] in an app.
  Future<void> pump(WidgetTester tester, LocaleBadges badges) =>
      tester.pumpWidget(MaterialApp(home: Scaffold(body: badges)));

  testWidgets('shows the locales alone without callbacks', (tester) async {
    await pump(tester, const LocaleBadges(locales: ['en', 'fr']));

    expect(find.text('EN'), findsOneWidget);
    expect(find.text('FR'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.text(LocaleBadges.addLabel), findsNothing);
  });

  testWidgets('adds a language not shown yet and removes the others', (
    tester,
  ) async {
    final added = <String>[];
    final removed = <String>[];
    await pump(
      tester,
      LocaleBadges(
        locales: const ['en', 'fr'],
        defaultLocale: 'en',
        onAdd: added.add,
        onRemove: removed.add,
      ),
    );

    await tester.tap(find.byTooltip('Remove French'));
    expect(removed, ['fr']);
    expect(find.byTooltip('Remove English'), findsNothing);

    await tester.tap(find.text(LocaleBadges.addLabel));
    await tester.pumpAndSettle();
    expect(find.text(LanguageCatalog.labelOf('fr')), findsNothing);
    await tester.tap(find.text(LanguageCatalog.labelOf('af')));
    await tester.pumpAndSettle();
    expect(added, ['af']);
  });
}
