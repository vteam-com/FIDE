import 'package:fide/constants/constants.dart';
import 'package:fide/models/commit_digest.dart';
import 'package:fide/models/model_reply.dart';
import 'package:fide/services/chat_model.dart';

/// Has the model write the Git panel's commit messages.
class CommitMessageWriter {
  /// Creates a writer asking [_model].
  const CommitMessageWriter(this._model);

  /// What follows the area a message starts with, as in `Git panel: …`.
  static const String _areaEnd = ': ';

  /// What the message says after its start, whatever the style.
  static const String _effect =
      'say what now happens or what the user can now do: the main change '
      'first, its action and effect, naming the folders, files or commands '
      'concerned.';

  final ChatModel _model;

  /// The request for the commit message of [changes], `git diff --stat`
  /// followed by the unified diff, read through a [CommitDigest] of
  /// [AppMetric.aiCommitDiffChars], in the style of [examples], the
  /// project's recent commit messages, as many as
  /// [AppMetric.aiCommitStyleChars] hold.
  ///
  /// The message starts with the area of the app the changes concern when
  /// most of [examples] do, or there are none; code decides, as the model
  /// told to start so does whatever the examples show.
  static String promptFor(String changes, {List<String> examples = const []}) {
    final digest = CommitDigest(
      changes,
      maxChars: AppMetric.aiCommitDiffChars,
    ).text;
    final style = <String>[];
    var styleChars = 0;
    for (final example in examples) {
      final line = '- ${example.trim()}';
      if (styleChars + line.length > AppMetric.aiCommitStyleChars) break;
      style.add(line);
      styleChars += line.length;
    }
    return [
      'Write the one-line git commit message of the changes summarized '
          'below.',
      if (style.isEmpty || _startWithAreas(examples))
        'Start with the part of the app they change, as its user sees it (a '
            'panel, tab, view or feature, not a class or file), and a colon. '
            'Then $_effect'
      else
        'Start with a verb in the imperative, as the recent messages do, and '
            '$_effect',
      'Avoid vague verbs such as Implement, Update, Improve or Refactor.',
      if (style.isNotEmpty) ...[
        "Write it in the style of this project's recent commit messages:",
        ...style,
      ],
      'Reply with the message only: no quotes, no prefix, no explanation.',
      '',
      digest,
    ].join('\n');
  }

  /// Writes a one-line commit message stating the intent of [changes]
  /// (see [promptFor]), in the style of [examples]; [cancel] stops it.
  ///
  /// Throws an [AiServiceException] when the request fails.
  Future<String> write(
    String changes, {
    List<String> examples = const [],
    AiCancelToken? cancel,
  }) async {
    final response = await _model.generate(
      promptFor(changes, examples: examples),
      AppDuration.aiGenerateTimeout,
      cancel: cancel,
    );
    final line = response
        .split('\n')
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '');
    return line.unquoted;
  }

  /// Whether most of [examples] start with an area and a colon.
  static bool _startWithAreas(List<String> examples) {
    final withAreas = examples.where((e) => e.contains(_areaEnd)).length;
    return withAreas > examples.length - withAreas;
  }
}
