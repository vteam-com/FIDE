// The SDK's widget CodeForge builds, which needs the SDK's localizations
// ignore: implementation_imports
import 'package:flutter/src/material/selection_area.dart' as sdk;
import 'package:fide/widgets/sdk_material_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets("a widget built with the SDK's Material library builds in the "
      "app's material_ui one", (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SdkMaterialLocalizations(
          child: sdk.SelectionArea(child: Text('code')),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('code'), findsOneWidget);
  });
}
