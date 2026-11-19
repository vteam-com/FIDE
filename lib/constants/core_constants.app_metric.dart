part of 'core_constants.dart';

/// Miscellaneous integer thresholds, limits, and scale factors used across the app.
class AppMetric {
  static const int terminalMaxLines = 1000;
  static const int colorChannelMax = 255;
  static const int fileSizeDivisor = 1024;

  /// Bytes in a megabyte, each unit [fileSizeDivisor] times the previous.
  static const int bytesPerMegabyte = fileSizeDivisor * fileSizeDivisor;

  static const int mruFolderLimit = 5;

  /// Most matches a project search lists; past it they are only counted,
  /// so a common word can't fill the Search tab with tens of thousands of
  /// rows.
  static const int projectSearchMaxResults = 2000;
  static const int aiContextPreviewChars = 2000;

  /// Most steps the agent takes for an edit: a local model edits in small
  /// steps, and a loop stops well before, after [aiMaxRepeatedCalls].
  static const int aiMaxToolRounds = 50;

  /// Lines shown around an edit in what `replace_in_file` answers.
  static const int aiEditContextLines = 3;

  /// Most characters of the lines `replace_in_file` shows when it can't
  /// replace, where the text, or its first line, is.
  static const int aiEditHintChars = 3000;

  /// Calls the agent repeats, with nothing changed in between, before it
  /// stops: a local model can loop on one, such as `check_build`.
  static const int aiMaxRepeatedCalls = 3;

  /// Most steps the agent takes to answer a question, reading the code it
  /// needs: fewer than an edit, which also writes and checks.
  static const int aiMaxAnswerRounds = 12;
  static const int aiChatHistoryMessages = 6;

  /// Most characters of earlier chat messages sent with a new request,
  /// the latest kept first, so a long reply doesn't fill the local model's
  /// context before the agent starts.
  static const int aiHistoryChars = 12000;

  /// Most paths the agent's `list_files` returns: enough to find a file,
  /// few enough to cost the local model little to read.
  static const int aiMaxListedFiles = 200;

  /// Most characters one `read_file` returns, cut at a line end; the
  /// agent reads on from a later line. A whole large file would cost a
  /// local model tens of seconds to read, again on every later step.
  static const int aiReadFileChars = 16000;

  /// Most characters of build or analyzer errors the agent is sent: the
  /// first errors, which the others often follow from.
  static const int aiBuildErrorChars = 8000;

  /// Most lines the agent's `search` returns.
  static const int aiSearchMaxResults = 50;
  static const int aiCommitDiffChars = 12000;
  static const int aiReviewContextChars = 40000;

  /// Context window of every model request, in tokens: room for Fix
  /// Build's file reads and history. Ollama otherwise gives a model its
  /// full context, whose memory can spill onto the CPU and slow it many
  /// times over, and reloads the model whenever the size changes.
  static const int aiContextTokens = 32768;

  /// Tokens the agent's conversation with the local model may reach
  /// before it drops the output of its oldest tool calls: room left in
  /// [aiContextTokens] for a reply and one more file part. Past the
  /// window, Ollama would cut the start of the conversation, the request
  /// with it, and read the rest again on every step, at a few hundred
  /// tokens per second that deep (on an M4 Max, qwen3-coder reads 1,200
  /// tokens per second near the start, 300 at 24k).
  static const int aiContextBudgetTokens = 24000;

  /// Share of [aiContextBudgetTokens] the agent's conversation is brought
  /// back under once it outgrows it, dropping the oldest outputs first:
  /// the latest ones, which the model is working from, stay, so it
  /// doesn't read them again.
  static const double aiContextKeptShare = 2 / 3;

  /// Characters per token when guessing a conversation's size: code runs
  /// about three, prose four, so this guess errs on the large side.
  static const int aiCharsPerToken = 3;

  /// Shortest tool output the agent drops to stay within
  /// [aiContextBudgetTokens]: shorter ones cost less than the note that
  /// replaces them saves.
  static const int aiDroppableOutputChars = 400;

  /// Times a model request is sent again after a retryable failure, such
  /// as a busy server or a local model's malformed tool call.
  static const int aiRequestRetries = 2;

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

  /// Percent in one whole, to show a factor such as `125%`.
  static const int percent = 100;
  static const int warningScoreThreshold = 80;
  static const int criticalScoreThreshold = 50;

  /// Quality-score points each `dart analyze` error costs.
  static const int dartErrorPoints = 10;

  /// Most quality-score points `dart analyze` errors cost together.
  static const int dartErrorPointsMax = 50;

  /// Quality-score points each `dart analyze` warning costs.
  static const int dartWarningPoints = 2;

  /// Most quality-score points `dart analyze` warnings cost together.
  static const int dartWarningPointsMax = 20;

  /// Quality-score points each `dart analyze` info costs.
  static const int dartInfoPoints = 1;

  /// Most quality-score points `dart analyze` infos cost together.
  static const int dartInfoPointsMax = 10;
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

  /// Newest lines a command output log keeps, as many as the terminal:
  /// a long `flutter run` would otherwise grow it, and the work to show
  /// it, without limit.
  static const int outputLogMaxLines = terminalMaxLines;

  /// Most untracked files whose line counts Git remembers between reloads;
  /// past it the counts are forgotten and read again.
  static const int gitLineCountCacheLimit = 4096;

  const AppMetric._();
}
