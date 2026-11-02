part of 'constants.dart';

/// Reusable `EdgeInsets` presets for consistent widget padding and margins.
class AppPadding {
  static const EdgeInsets wizardButton = EdgeInsets.symmetric(
    horizontal: AppSpacing.huge,
    vertical: AppSpacing.xLarge,
  );
  static const EdgeInsets sectionContent = EdgeInsets.all(AppSpacing.medium);
  static const EdgeInsets sectionHeader = EdgeInsets.symmetric(
    horizontal: 8,
    vertical: 4,
  );
  static const EdgeInsets listItem = EdgeInsets.symmetric(
    horizontal: 8,
    vertical: 2,
  );
  static const EdgeInsets badge = EdgeInsets.symmetric(
    horizontal: 4,
    vertical: 1,
  );
  static const EdgeInsets actionTabContent = EdgeInsets.all(16);
  static const EdgeInsets actionTabLabel = EdgeInsets.symmetric(horizontal: 8);
  static const EdgeInsets actionTabLabelCompact = EdgeInsets.symmetric(
    horizontal: 8,
    vertical: 8,
  );
  static const EdgeInsets actionTabLabelExpanded = EdgeInsets.symmetric(
    horizontal: 8,
    vertical: 4,
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
  static const EdgeInsets selectedBadgeMargin = EdgeInsets.only(left: 4);
  static const EdgeInsets messageMargin = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 8,
  );
  static const EdgeInsets diffHeader = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 8,
  );
  static const EdgeInsets diffRow = EdgeInsets.symmetric(
    horizontal: 8,
    vertical: 2,
  );

  /// Inset of every side panel's content from the panel's top-left edge.
  static const EdgeInsets panelContent = EdgeInsets.all(AppSpacing.medium);
  static const EdgeInsets chipLabel = EdgeInsets.symmetric(horizontal: 6);

  const AppPadding._();
}
