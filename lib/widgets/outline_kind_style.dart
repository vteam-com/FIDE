import 'package:fide/models/outline_kind.dart';
import 'package:material_ui/material_ui.dart';

/// How an [OutlineKind] looks in a file's outline: its icon and the theme
/// color tinting it.
extension OutlineKindStyle on OutlineKind {
  /// Icon shown before the entry.
  IconData get icon => switch (this) {
    OutlineKind.dartClass => Icons.class_,
    OutlineKind.function || OutlineKind.method => Icons.functions,
    OutlineKind.variable => Icons.tag,
    OutlineKind.widget => Icons.widgets,
    OutlineKind.widgetReference => Icons.widgets_outlined,
    OutlineKind.heading1 => Icons.looks_one,
    OutlineKind.heading2 => Icons.looks_two,
    OutlineKind.heading3 => Icons.looks_3,
    OutlineKind.heading4 => Icons.looks_4,
    OutlineKind.heading5 => Icons.looks_5,
    OutlineKind.heading6 => Icons.looks_6,
    OutlineKind.yamlKey => Icons.vpn_key,
  };

  /// [icon]'s color in [scheme].
  Color colorIn(ColorScheme scheme) => switch (this) {
    OutlineKind.dartClass ||
    OutlineKind.widget ||
    OutlineKind.heading1 ||
    OutlineKind.heading4 ||
    OutlineKind.yamlKey => scheme.primary,
    OutlineKind.function ||
    OutlineKind.heading2 ||
    OutlineKind.heading5 => scheme.secondary,
    OutlineKind.method ||
    OutlineKind.heading3 ||
    OutlineKind.heading6 => scheme.tertiary,
    OutlineKind.variable ||
    OutlineKind.widgetReference => scheme.onSurfaceVariant,
  };
}
