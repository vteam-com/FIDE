part of 'constants.dart';

/// Reusable `EdgeInsets` presets for consistent widget padding and margins.
class AppPadding {
  static const EdgeInsets sectionContent = EdgeInsets.only(left: 16, bottom: 8);
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
  static const EdgeInsets actionTabContainer = EdgeInsets.all(12);
  static const EdgeInsets actionTabContent = EdgeInsets.all(16);
  static const EdgeInsets actionTabDetails = EdgeInsets.all(10);
  static const EdgeInsets actionTabLabel = EdgeInsets.symmetric(horizontal: 8);
  static const EdgeInsets actionTabLabelCompact = EdgeInsets.symmetric(
    horizontal: 8,
    vertical: 8,
  );
  static const EdgeInsets actionTabLabelExpanded = EdgeInsets.symmetric(
    horizontal: 8,
    vertical: 4,
  );
  static const EdgeInsets nestedFolder = EdgeInsets.only(left: 16);
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
  static const EdgeInsets infoCard = EdgeInsets.all(8);
  static const EdgeInsets chipLabel = EdgeInsets.symmetric(horizontal: 6);

  const AppPadding._();
}
