import 'package:flutter/material.dart';

/// Shared numeric size values used for dimensions and fixed layout widths.
class AppSize {
  static const double borderThin = 1;
  static const double gutterDividerAlpha = 100;
  static const double titleBarHeight = 40;
  static const double terminalDefaultHeight = 200;
  static const double terminalMinHeight = 100;
  static const double terminalMaxHeight = 400;
  static const double folderPanelFallbackHeight = 400;
  static const double largePreviewIcon = 64;
  static const double compactIconButton = 24;
  static const double platformDetailLabelWidth = 70;
  static const double diffLineNumberWidth = 40;
  static const double compactActionButton = 32;
  static const double panelFallbackHeight = 600;
  static const double actionTabContentHeight = 220;
  static const double compactContextButton = 20;
  static const double compactProgressIndicator = 18;
  static const double regularProgressIndicator = 20;
  static const double expandedProgressIndicator = 24;
  static const double tabLabelBreakpoint = 240;
  static const double platformSelectorLabelBreakpoint = 300;
  static const double macWindowControlsSpacing = 80;
  static const double desktopWindowControlsSpacing = 120;
  static const double diffHeaderDividerHeight = 16;
  static const double diffRowDividerHeight = 20;
  static const double diffLineNumberColumnWidth = 60;
  static const double outlineFallbackHeight = 200;
  static const double splitterThickness = 8;
  static const double splitterGripLength = 40;
  static const double splitterGripThickness = 4;
  static const double heroLogoHeight = 100;
  static const double compactTextButtonMinWidth = 50;
  static const double compactTextButtonHeight = 28;
  static const double actionButtonHeight = 36;
  static const double compactButtonHeight = 30;
  static const double initialSidePanelWidth = 250;
  static const double statusLogMaxHeight = 300;
  static const double statusIconTall = 25;
  static const double wizardMaxWidth = 600;
  static const double welcomeContentWidth = 700;
  static const double largeActionButtonHeight = 56;

  const AppSize._();
}

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

/// Shared spacing scale used for gaps, separators, and compact layout rhythm.
class AppSpacing {
  static const double micro = 2;
  static const double narrow = 3;
  static const double tiny = 4;
  static const double small = 6;
  static const double medium = 8;
  static const double regular = 10;
  static const double large = 12;
  static const double xLarge = 16;
  static const double xxLarge = 24;
  static const double huge = 32;

  const AppSpacing._();
}

/// Standard icon sizes used throughout the UI.
class AppIconSize {
  static const double tiny = 12;
  static const double small = 14;
  static const double medium = 16;
  static const double mediumLarge = 18;
  static const double large = 20;
  static const double largeCompact = 22;
  static const double xLarge = 24;
  static const double emptyState = 48;

  const AppIconSize._();
}

/// Standard text sizes used across labels, metadata, and body content.
class AppFontSize {
  static const double micro = 9;
  static const double badge = 10;
  static const double metadata = 11;
  static const double caption = 12;
  static const double body = 13;
  static const double label = 14;
  static const double title = 16;

  const AppFontSize._();
}

/// Shared corner radii for cards, chips, and panel elements.
class AppRadius {
  static const double tiny = 4;
  static const double small = 6;
  static const double medium = 8;

  const AppRadius._();
}

/// Common animation and timing durations used by UI interactions.
class AppDuration {
  static const Duration editorScroll = Duration(milliseconds: 100);
  static const Duration tooltipWait = Duration(seconds: 1);
  static const Duration messageAnimation = Duration(milliseconds: 300);
  static const Duration copiedBadgeFade = Duration(milliseconds: 200);
  static const Duration copiedBadgeVisible = Duration(milliseconds: 1500);
  static const Duration messageSuccess = Duration(seconds: 4);
  static const Duration messageWarning = Duration(seconds: 6);
  static const Duration messageError = Duration(seconds: 8);
  static const Duration messageInfo = Duration(seconds: 4);

  static const Duration buildStatusResetDelay = Duration(seconds: 5);
  static const Duration loadingUpdateBatch = Duration(milliseconds: 50);
  static const Duration aiSuggestionTimeout = Duration(seconds: 30);
  static const Duration aiGenerateTimeout = Duration(seconds: 60);
  static const Duration ollamaStartupDelay = Duration(seconds: 3);
  static const Duration projectCreateTimeout = Duration(seconds: 60);
  static const Duration aiProjectCreateTimeout = Duration(seconds: 120);
  static const Duration gitInitTimeout = Duration(seconds: 10);
  static const Duration gitOperationTimeout = Duration(seconds: 30);
  static const Duration projectLoadDelay = Duration(milliseconds: 500);

  const AppDuration._();
}

/// Shared opacity values for emphasis, muted states, and overlays.
class AppOpacity {
  static const double prominent = 0.9;
  static const double faint = 0.4;
  static const double subtle = 0.1;
  static const double selected = 0.2;
  static const double divider = 0.3;
  static const double disabled = 0.5;
  static const double muted = 0.6;
  static const double secondaryText = 0.7;
  static const double emphasis = 0.8;

  const AppOpacity._();
}

/// Integer alpha channel values for APIs that expect 0-255 transparency.
class AppAlpha {
  static const int overlay = 100;
  static const int badgeFill = 150;
  static const int badgeText = 160;
  static const int pathPrefix = 200;
  static const int splitterHover = 50;

  const AppAlpha._();
}

/// Reusable border width values for thin and emphasized strokes.
class AppBorderWidth {
  static const double medium = 2;
  static const double emphasized = 1.5;

  const AppBorderWidth._();
}

/// Named `TextStyle.height` multipliers for consistent line spacing.
class AppLineHeight {
  static const double tight = 1.2;
  static const double compact = 1.3;
  static const double relaxed = 1.4;

  const AppLineHeight._();
}

/// Miscellaneous integer thresholds, limits, and scale factors used across the app.
class AppMetric {
  static const int terminalMaxLines = 1000;
  static const int colorChannelMax = 255;
  static const int fileSizeDivisor = 1024;
  static const int removePrefixLength = 7;
  static const int mruFolderLimit = 5;
  static const int aiContextPreviewChars = 2000;
  static const int translationPreviewLines = 5;
  static const int doubleLineLimit = 2;
  static const int largeFileThresholdMb = 10;
  static const int maxAllowedLargeFiles = 3;
  static const int maxScore = 100;
  static const int warningScoreThreshold = 80;
  static const int criticalScoreThreshold = 50;
  static const int missingLockDeduction = 20;
  static const int buildErrorDeductionPer = 10;
  static const int buildErrorDeductionMax = 50;
  static const int buildWarningDeductionPer = 2;
  static const int buildWarningDeductionMax = 20;
  static const int minDirPathDepth = 2;
  static const int outdatedMinColumns = 5;
  static const int outdatedUpgradableColIndex = 2;
  static const int outdatedResolvableColIndex = 3;
  static const int outdatedLatestColIndex = 4;
  static const int markdownMaxHeadingLevel = 6;
  static const int aiInputMaxLines = 3;
  static const int duplicateThreshold = 2;
  static const int rightPanelTabCount = 4;
  static const int gitHashShortLength = 7;
  static const int gitCommitDefaultCount = 10;
  static const int maxMruFolders = 10;
  static const int gitStatusFieldOffset = 3;
  static const int regexBaseClassGroupIndex = 2;
  static const int logPreviewChars = 200;
  static const int projectCreateStepValidate = 1;
  static const int projectCreateStepFlutterCreate = 2;
  static const int projectCreateStepLocalization = 3;
  static const int projectCreateStepCodegen = 4;
  static const int projectCreateStepGitInit = 5;
  static const int projectCreateStepVerification = 6;

  const AppMetric._();
}

/// Configuration constants specific to the code editor view.
class EditorConfig {
  static const double imagePreviewMaxWidthFactor = AppOpacity.emphasis;
  static const double imagePreviewMaxHeightFactor = AppOpacity.secondaryText;
  static const double scrollableExtentMax = 1000000;
  static const double scrollableExtentMin = 100;
  static const double lineHeight = 20;
  static const int contextLinesAboveTarget = 3;

  const EditorConfig._();
}

/// ANSI colour palette for the embedded terminal widget.
class TerminalPalette {
  static const Color background = Color(0xFF1E1E1E);
  static final Color red = Colors.redAccent;
  static const Color green = Color(0xFF5AF78E);
  static const Color yellow = Color(0xFFF3F99D);
  static const Color blue = Color(0xFF57C7FF);
  static const Color magenta = Color(0xFFFF6AC1);
  static const Color cyan = Color(0xFF9AEDFE);
  static const Color white = Color(0xFFF1F1F0);
  static const Color brightBlack = Color(0xFF686868);
  static const Color brightWhite = Color(0xFFFFFFFF);

  const TerminalPalette._();
}

/// One-off named colours that do not belong to the Material colour scheme.
class AppColor {
  static const Color nativeDependencyAccent = Color(0xFF007ACC);
  static const Color popupBorderLight = Color(0xFFCCCCCC);
  static const Color popupBorderDark = Color(0xFF4A4A4A);
  static const Color sidePanelSurfaceLight = Color(0xFFFFFFFF);
  static const Color sidePanelSurfaceDark = Color(0xFF252526);
  static const Color sidePanelDividerLight = Color(0xFFE5E5E5);
  static const Color sidePanelDividerDark = Color(0xFF3E3E42);

  const AppColor._();
}

/// Material swatch shade keys (50–900) for selecting tinted colour variants.
class AppShade {
  static const int ultraLight = 50;
  static const int light = 100;
  static const int muted = 200;
  static const int soft = 300;
  static const int mild = 400;
  static const int neutral = 500;
  static const int medium = 600;
  static const int strong = 700;
  static const int deep = 800;
  static const int darkest = 900;

  const AppShade._();
}

/// Zero-based tab indices for the left-panel tab controller.
class AppPanelIndex {
  static const int explorer = 0;
  static const int organized = 1;
  static const int git = organized + 1;
  static const int search = git + 1;
  static const int run = search + 1;
  static const int test = run + 1;

  const AppPanelIndex._();
}
