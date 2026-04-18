part of 'constants.dart';

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
