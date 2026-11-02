import 'package:fide/models/shortcut_help_entry.dart';
import 'package:fide/widget_services/app_command.dart';
import 'package:fide/widget_services/native_menu_builder.dart';
import 'package:fide/widgets/icon_menu_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// The context and [WidgetRef] of a widget under a fresh provider scope.
  Future<(BuildContext, WidgetRef)> pumpConsumer(WidgetTester tester) async {
    late (BuildContext, WidgetRef) captured;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              captured = (context, ref);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    return captured;
  }

  testWidgets('the File menu opens with the app commands, in their groups', (
    tester,
  ) async {
    final (context, ref) = await pumpConsumer(tester);
    final menus = NativeMenuBuilder(context: context, ref: ref).buildMenus();
    final file = menus.singleWhere((menu) => menu.label == 'File');

    final groups = [
      for (final group in file.menus.whereType<PlatformMenuItemGroup>())
        [for (final item in group.members) item.label],
    ];

    expect(groups.take(AppCommand.groups.length), [
      for (final group in AppCommand.groups)
        [for (final command in group) command.label],
    ]);
  });

  testWidgets('the project menu reads each command as the File menu does', (
    tester,
  ) async {
    final (context, ref) = await pumpConsumer(tester);
    for (final command in AppCommand.values) {
      final row = command.popupItem(context, ref).child! as IconMenuRow;
      final item = command.menuItem(context, ref);

      expect(row.label, item.label);
      expect(row.icon, command.icon);
      expect(item.shortcut, command.shortcut);
    }
  });

  testWidgets('no two menu items share a shortcut', (tester) async {
    final (context, ref) = await pumpConsumer(tester);
    final menus = NativeMenuBuilder(context: context, ref: ref).buildMenus();

    final keys = [
      for (final entry in ShortcutHelpEntry.fromMenus(menus)) ...entry.keys,
    ];

    expect(keys.toSet(), hasLength(keys.length));
  });
}
