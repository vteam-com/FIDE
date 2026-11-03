part of 'constants.dart';

/// Reusable `EdgeInsets` presets for consistent widget padding and margins.
class AppPadding {
  static const EdgeInsets sectionHeader = EdgeInsets.symmetric(
    horizontal: AppSpacing.medium,
    vertical: AppSpacing.tiny,
  );
  static const EdgeInsets listItem = EdgeInsets.symmetric(
    horizontal: AppSpacing.medium,
    vertical: AppSpacing.micro,
  );
  static const EdgeInsets badge = EdgeInsets.symmetric(
    horizontal: AppSpacing.tiny,
    vertical: AppSpacing.micro / 2,
  );

  /// Inset of a full screen's content (welcome, create project, loading).
  static const EdgeInsets screen = EdgeInsets.all(AppSpacing.huge);

  /// Inset of a full page's or overlay's content from its edges.
  static const EdgeInsets pageContent = EdgeInsets.all(AppSpacing.xLarge);

  /// Insets of a tab that shows only its icon.
  static const EdgeInsets tabLabelCompact = EdgeInsets.symmetric(
    horizontal: AppSpacing.medium,
    vertical: AppSpacing.medium,
  );

  /// Insets of a tab that shows its icon and name.
  static const EdgeInsets tabLabelExpanded = EdgeInsets.symmetric(
    horizontal: AppSpacing.medium,
    vertical: AppSpacing.tiny,
  );

  /// Insets of one action's row in an action list.
  static const EdgeInsets actionRow = EdgeInsets.symmetric(
    horizontal: AppSpacing.medium,
    vertical: AppSpacing.micro,
  );

  /// Insets of an action's details, aligned under its title.
  static const EdgeInsets actionRowDetails = EdgeInsets.only(
    left: AppSpacing.medium + AppIconSize.large + AppSpacing.medium,
    right: AppSpacing.medium,
    bottom: AppSpacing.medium,
  );
  static const EdgeInsets selectedBadgeMargin = EdgeInsets.only(
    left: AppSpacing.tiny,
  );
  static const EdgeInsets messageMargin = EdgeInsets.symmetric(
    horizontal: AppSpacing.xLarge,
    vertical: AppSpacing.medium,
  );

  /// Inset of every side panel's content from the panel's top-left edge.
  static const EdgeInsets panelContent = EdgeInsets.all(AppSpacing.medium);
  static const EdgeInsets chipLabel = EdgeInsets.symmetric(
    horizontal: AppSpacing.small,
  );

  const AppPadding._();
}
