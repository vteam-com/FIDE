part of 'constants.dart';

/// Shared numeric size values used for dimensions and fixed layout widths.
class AppSize {
  static const double borderThin = 1;
  static const double gutterDividerAlpha = 100;
  static const double titleBarHeight = 40;
  static const double terminalDefaultHeight = 200;
  static const double terminalMinHeight = 100;
  static const double terminalMaxHeight = 400;

  /// Tallest the bottom panel can be dragged.
  static const double bottomPanelMaxHeight = 800;

  /// Height the bottom panel always leaves the editor above it, enough for
  /// its header, find bar, status bar and a few lines.
  static const double editorMinHeight = 240;

  /// Width expanded side panels always leave the editor between them.
  static const double editorMinWidth = 320;
  static const double folderPanelFallbackHeight = 400;
  static const double compactIconButton = 24;
  static const double detailLabelWidth = 90;
  static const double diffLineNumberWidth = 40;
  static const double compactActionButton = 32;

  /// Size of the progress ring around an action's run button.
  static const double actionButtonRing =
      compactActionButton + AppSpacing.medium;
  static const double panelFallbackHeight = 600;
  static const double compactContextButton = 20;
  static const double compactProgressIndicator = 18;
  static const double regularProgressIndicator = 20;
  static const double expandedProgressIndicator = 24;
  static const double platformSelectorLabelBreakpoint = 300;
  static const double macWindowControlsSpacing = 80;
  static const double desktopWindowControlsSpacing = 120;

  /// Size of the main window at launch.
  static const Size initialWindowSize = Size(1200, 800);

  /// Smallest the main window can be resized to.
  static const Size minWindowSize = Size(800, 600);
  static const double diffHeaderDividerHeight = 16;
  static const double diffRowDividerHeight = 20;
  static const double diffLineNumberColumnWidth = 60;
  static const double outlineFallbackHeight = 200;

  /// Gap between workspace panel islands and around the workspace edge.
  static const double islandGap = 6;
  static const double splitterThickness = islandGap;
  static const double splitterGripLength = 40;
  static const double splitterGripThickness = 4;
  static const double heroLogoHeight = 100;
  static const double statCardWidth = 260;
  static const double appIconPreview = 64;
  static const double appIconSlot = 72;
  static const double appIconSlotMinDrawn = 16;
  static const double transparencySquare = 6;
  static const double compactTextButtonMinWidth = 50;
  static const double compactTextButtonHeight = 28;
  static const double initialSidePanelWidth = 250;

  /// Narrowest the left and right panels can be dragged.
  static const double minSidePanelWidth = 150;

  /// Widest the left and right panels can be dragged.
  static const double maxSidePanelWidth = 900;
  static const double statusLogMaxHeight = 300;
  static const double statusIconTall = 25;
  static const double wizardMaxWidth = 600;
  static const double welcomeContentWidth = 700;

  /// Width of a menu listing files by path, such as the editor's open
  /// files; longer paths shorten their folders.
  static const double fileMenuWidth = 400;

  /// Width of the Go to File palette.
  static const double quickOpenWidth = 600;

  /// Tallest the Go to File palette's result list grows.
  static const double quickOpenMaxListHeight = 400;

  /// Width of an issue's best practice and findings dialog.
  static const double issueDetailsWidth = 600;

  /// Share of the window's width a file's diff dialog takes.
  static const double diffDialogWidthFactor = 0.8;

  /// Share of the window's height a file's diff dialog takes.
  static const double diffDialogHeightFactor = 0.6;

  const AppSize._();
}
