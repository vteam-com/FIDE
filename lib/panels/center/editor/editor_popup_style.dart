import 'package:code_forge/code_forge.dart';
import 'package:fide/constants/constants.dart';
import 'package:material_ui/material_ui.dart';

/// The look of the code editor's popups, those of the Dart language
/// server: the completion list, drawn as the popup menus are, and the
/// cards of hover documentation and parameter hints, alike.
class EditorPopupStyle {
  const EditorPopupStyle._();

  /// The popups' fill in [colorScheme]: a popup menu's.
  static Color background(ColorScheme colorScheme) =>
      colorScheme.surfaceContainer;

  /// The hover documentation and parameter hint cards of [theme], their
  /// text in the code's color.
  static HoverDetailsStyle hover(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return HoverDetailsStyle(
      elevation: _elevation(theme),
      shape: _shape(theme),
      backgroundColor: background(colorScheme),
      focusColor: theme.focusColor,
      hoverColor: theme.hoverColor,
      splashColor: theme.splashColor,
      textStyle: AppTextStyle.body.copyWith(color: colorScheme.onSurface),
    );
  }

  /// The completion list of [theme]. Each completion is a tree row, which
  /// fills itself when selected, so the list fills none.
  static SuggestionStyle suggestions(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return SuggestionStyle(
      elevation: _elevation(theme),
      shape: _shape(theme),
      backgroundColor: background(colorScheme),
      selectedBackgroundColor: Colors.transparent,
      focusColor: theme.focusColor,
      hoverColor: theme.hoverColor,
      splashColor: theme.splashColor,
      textStyle: AppTextStyle.body.copyWith(color: colorScheme.onSurface),
      itemHeight: AppSize.completionRowHeight,
      iconSize: AppIconSize.medium,
    );
  }

  /// How high the popups float: as a popup menu.
  static double _elevation(ThemeData theme) =>
      theme.popupMenuTheme.elevation ?? AppSpacing.small;

  /// The popups' outline: a popup menu's.
  static ShapeBorder _shape(ThemeData theme) =>
      theme.popupMenuTheme.shape ??
      const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.small)),
      );
}
