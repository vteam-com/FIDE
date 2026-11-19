part of 'core_constants.dart';

/// Common animation and timing durations used by UI interactions.
class AppDuration {
  /// How long a section takes to expand or collapse.
  static const Duration expand = Duration(milliseconds: 200);

  static const Duration splitterHover = Duration(milliseconds: 150);
  static const Duration editorScroll = Duration(milliseconds: 100);

  /// How long the architecture graph takes to glide to a file or to fit
  /// the view.
  static const Duration graphPan = Duration(milliseconds: 300);

  /// How long the workspace gradient takes to glide to the active panel.
  static const Duration gradientMove = Duration(milliseconds: 300);
  static const Duration tooltipWait = Duration(seconds: 1);
  static const Duration messageAnimation = Duration(milliseconds: 300);
  static const Duration copiedBadgeFade = Duration(milliseconds: 200);
  static const Duration copiedBadgeVisible = Duration(milliseconds: 1500);
  static const Duration messageSuccess = Duration(seconds: 4);
  static const Duration messageWarning = Duration(seconds: 6);
  static const Duration messageError = Duration(seconds: 8);
  static const Duration messageInfo = Duration(seconds: 4);
  static const Duration buildStatusResetDelay = Duration(seconds: 5);
  static const Duration aiSuggestionTimeout = Duration(seconds: 30);
  static const Duration aiGenerateTimeout = Duration(seconds: 60);
  static const Duration aiToolStepTimeout = Duration(seconds: 180);
  static const Duration aiReviewTimeout = Duration(seconds: 300);
  static const Duration aiModelKeepAlive = Duration(minutes: 30);

  static const Duration ollamaStartupDelay = Duration(seconds: 3);
  static const Duration projectCreateTimeout = Duration(seconds: 60);
  static const Duration aiProjectCreateTimeout = Duration(seconds: 120);
  static const Duration gitInitTimeout = Duration(seconds: 10);
  static const Duration gitOperationTimeout = Duration(seconds: 30);
  static const Duration loginShellTimeout = Duration(seconds: 30);

  /// How often a running FIDE asks GitHub whether a newer release is out,
  /// well within GitHub's limit on unauthenticated requests.
  static const Duration updateCheckInterval = Duration(hours: 4);

  /// How long after the login shell's `PATH` failed to read it is read
  /// again, in the background.
  static const Duration loginShellRetryInterval = Duration(minutes: 1);
  static const Duration projectLoadDelay = Duration(milliseconds: 150);

  /// How long a burst of edits or file system events must pause before
  /// the views depending on them update.
  static const Duration updateDebounce = Duration(milliseconds: 150);

  /// How long saves must pause, as when the AI agent writes file after
  /// file, before the project's quality is analyzed again.
  static const Duration saveBurstPause = Duration(milliseconds: 500);

  /// Longest new output waits before it is shown, a command's lines or
  /// the words of an AI reply, so a burst updates the view a few times,
  /// not once per line or word.
  static const Duration outputLogPublish = Duration(milliseconds: 50);

  /// How long saves and file changes must pause before Git reads the
  /// repository again: longer than [updateDebounce], so a save and the
  /// tree update it causes read it once.
  static const Duration gitReloadDebounce = Duration(milliseconds: 300);

  const AppDuration._();
}
