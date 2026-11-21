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

  /// Inset of a side panel's content, such as its header bar, from the
  /// panel's edges; its stacked sections take [panelSections].
  static const EdgeInsets panelContent = EdgeInsets.all(AppSpacing.medium);

  /// Inset of a side panel's stacked sections from its edges, and of a
  /// section's content from its card: a section gap above and below, as
  /// between the sections, and the content padding at the sides, where a
  /// side panel has no width to spare.
  static const EdgeInsets panelSections = EdgeInsets.symmetric(
    horizontal: AppSpacing.medium,
    vertical: AppSpacing.sectionGap,
  );
  static const EdgeInsets chipLabel = EdgeInsets.symmetric(
    horizontal: AppSpacing.small,
  );

  const AppPadding._();
}
