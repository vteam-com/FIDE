part of 'constants.dart';

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
