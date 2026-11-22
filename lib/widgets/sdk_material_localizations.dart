// The SDK's own library, not the deprecated `package:flutter/material.dart`,
// which `dart fix` rewrites to material_ui, whose localizations differ
// ignore: implementation_imports
import 'package:flutter/src/material/material_localizations.dart' as sdk;
import 'package:material_ui/material_ui.dart';

/// Gives [child] the Flutter SDK's Material localizations besides the
/// app's material_ui ones, for a package's widgets still built with the
/// SDK's Material library, such as CodeForge's `SelectionArea`: without
/// them, those fail to build.
class SdkMaterialLocalizations extends StatelessWidget {
  /// Creates the localizations of [child].
  const SdkMaterialLocalizations({super.key, required this.child});

  /// The widgets built with the SDK's Material library.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Localizations.override(
      context: context,
      delegates: const [sdk.DefaultMaterialLocalizations.delegate],
      child: child,
    );
  }
}
