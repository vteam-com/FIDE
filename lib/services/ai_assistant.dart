import 'dart:io';

import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/constants/constants.dart';
import 'package:fide/models/ai_action.dart';
import 'package:fide/models/text_truncation.dart';
import 'package:fide/services/chat_model.dart';
import 'package:path/path.dart' as p;

part 'ai_assistant.review_findings.dart';

/// Answers the AI panel's actions with suggestions and reviews, writing
/// each action's prompt for the [ChatModel]; the files themselves are
/// edited by `CodeEditAgent`.
class AiAssistant {
  /// Creates an assistant asking [_model].
  const AiAssistant(this._model);

  final ChatModel _model;

  /// Runs [action] on the user's [text], with [context], what the action's
  /// [AiAction.context] collected, such as the selected file's content or
  /// fcheck's findings; [cancel] stops the request.
  ///
  /// Without a context of its own, the action works on [text] as told by
  /// its [AiAction.instruction]; with one, [text] adds to the instruction.
  /// Throws an [AiServiceException] when the request fails.
  Future<String> respond(
    AiAction action,
    String text,
    String context, {
    AiCancelToken? cancel,
  }) {
    if (action.isReview) {
      return review(action.instruction, text, context, cancel: cancel);
    }
    final textIsContext = action.context == AiContext.none;
    return suggest(
      [
        if (action.instruction.isNotEmpty) action.instruction,
        if (!textIsContext) text,
      ].join('\n\n'),
      textIsContext ? text : context,
      think: action.think,
      cancel: cancel,
    );
  }

  /// Reviews the project [findings] (fcheck's results and the code they
  /// point to) as [instructions] say, with the user's [notes] on what to
  /// focus on, and returns the review in Markdown. A thinking model
  /// reasons first, as judging the findings is what the review is for.
  Future<String> review(
    String instructions,
    String notes,
    String findings, {
    AiCancelToken? cancel,
  }) {
    return _model.generate(
      '''
You are a senior Flutter/Dart reviewer.

$instructions

List the most important findings first, as Markdown. Only report problems you can point to in the code.

$notes

$findings''',
      AppDuration.aiReviewTimeout,
      think: true,
      cancel: cancel,
    );
  }

  /// Requests a coding suggestion for [request] with contextual text;
  /// empty when the model has nothing to say. [think] lets a thinking
  /// model reason first.
  Future<String> suggest(
    String request,
    String context, {
    bool think = false,
    AiCancelToken? cancel,
  }) {
    return _model.generate(
      '''
You are a helpful coding assistant. Provide concise, accurate code suggestions.

Context: $context

Request: $request

Please provide a helpful response focused on the coding request.''',
      think ? AppDuration.aiToolStepTimeout : AppDuration.aiSuggestionTimeout,
      think: think,
      cancel: cancel,
    );
  }
}
