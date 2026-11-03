part of 'core_constants.dart';

/// Miscellaneous integer thresholds, limits, and scale factors used across the app.
class AppMetric {
  static const int terminalMaxLines = 1000;
  static const int colorChannelMax = 255;
  static const int fileSizeDivisor = 1024;
  static const int mruFolderLimit = 5;
  static const int aiContextPreviewChars = 2000;
  static const int aiMaxToolRounds = 25;
  static const int aiChatHistoryMessages = 6;
  static const int aiMaxListedFiles = 500;
  static const int aiMaxReadChars = 40000;
  static const int aiCommitDiffChars = 12000;
  static const int aiReviewContextChars = 40000;

  /// Context window of every model request, in tokens: room for Fix
  /// Build's file reads and history. Ollama otherwise gives a model its
  /// full context, whose memory can spill onto the CPU and slow it many
  /// times over, and reloads the model whenever the size changes.
  static const int aiContextTokens = 32768;

  static const int aiReviewMaxItems = 15;

  /// Texts translated per model request: small enough to stay fast on a
  /// local model, large enough to save round trips.
  static const int aiTranslateBatch = 20;
  static const int aiReviewMinLiteralChars = 3;
  static const int aiReviewDuplicateMinLines = 6;
  static const double aiReviewDuplicateSimilarity = 0.75;
  static const int translationPreviewLines = 5;
  static const int doubleLineLimit = 2;
  static const int largeFileThresholdMb = 10;
  static const int maxAllowedLargeFiles = 3;
  static const int maxScore = 100;
  static const int warningScoreThreshold = 80;
  static const int criticalScoreThreshold = 50;
  static const int missingLockDeduction = 20;
  static const int largeFilesDeduction = 10;
  static const int buildErrorDeductionPer = 10;
  static const int buildErrorDeductionMax = 50;
  static const int buildWarningDeductionPer = 2;
  static const int buildWarningDeductionMax = 20;
  static const int minDirPathDepth = 2;
  static const int outdatedMinColumns = 5;
  static const int outdatedUpgradableColIndex = 2;
  static const int outdatedResolvableColIndex = 3;
  static const int outdatedLatestColIndex = 4;
  static const int aiInputMaxLines = 3;
  static const int duplicateThreshold = 2;
  static const int gitHashShortLength = 7;
  static const int gitCommitDefaultCount = 10;
  static const int daysPerMonth = 30;
  static const int daysPerYear = 365;
  static const int maxMruFolders = 10;
  static const int gitStatusFieldOffset = 3;
  static const int regexBaseClassGroupIndex = 2;
  static const int logPreviewChars = 200;

  /// Steps a loading progress bar spans: the longest flow, project
  /// creation, which has as many `CreationStep`s.
  static const int loadingProgressSteps = 6;

  /// Most files the Go to File palette lists.
  static const int quickOpenMaxResults = 50;

  const AppMetric._();
}
