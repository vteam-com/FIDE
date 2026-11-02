import 'package:fide/constants/constants.dart';
import 'package:fide/models/text_truncation.dart';
import 'package:fide/services/chat_model.dart';

/// Has the model write the Git panel's commit messages.
class CommitMessageWriter {
  /// Creates a writer asking [_model].
  const CommitMessageWriter(this._model);

  final ChatModel _model;

  /// Writes a one-line commit message stating the intent of the changes
  /// in [diff], cut to [AppMetric.aiCommitDiffChars]; [cancel] stops it.
  ///
  /// Throws an [AiServiceException] when the request fails.
  Future<String> write(String diff, {AiCancelToken? cancel}) async {
    final changes = diff.truncated(AppMetric.aiCommitDiffChars);
    final response = await _model.generate(
      '''
Write a short, one-line git commit message stating the intent of these changes.
Reply with the message only: no quotes, no prefix, no explanation.

$changes''',
      AppDuration.aiGenerateTimeout,
      cancel: cancel,
    );
    final line = response
        .split('\n')
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '');
    return line.unquoted;
  }
}
