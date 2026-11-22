import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/model_reply.dart';
import 'package:fide/models/text_truncation.dart';
import 'package:fide/services/commit_message_writer.dart';
import 'package:fide/services/ollama_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// How many commits to replay, from `FIDE_AI_REPLAY`; null skips the
/// replay, which needs the local Ollama model and takes minutes.
final int? _count = int.tryParse(Platform.environment['FIDE_AI_REPLAY'] ?? '');

/// The message recommended for the staged change, when one is staged: the
/// File Layout review, written by hand.
const String _stagedReference =
    'Analyzer tab: File Layout review moves screens to lib/views, pure '
    'widgets to lib/widgets and plain models to lib/models, rewriting every '
    'import (Move / Move All)';

/// Words too common to tell two messages apart.
const Set<String> _stopWords = {
  'about',
  'from',
  'into',
  'its',
  'that',
  'the',
  'their',
  'them',
  'then',
  'they',
  'this',
  'when',
  'with',
};

/// Shortest word compared.
const int _minWordLength = 4;

/// Longest area name, the text before a message's colon.
const int _maxAreaLength = 40;

/// Commit subjects left out of the replay, which say nothing a diff tells.
final RegExp _skipped = RegExp(r'^(Release v|Merge )');

/// A word of a message.
final RegExp _word = RegExp(r'[a-z0-9_./]+');

/// The request the writer sent before the digest: the head of the diff.
String _headPrompt(String changes) => '''
Write a short, one-line git commit message stating the intent of these changes.
Reply with the message only: no quotes, no prefix, no explanation.

${changes.truncated(AppMetric.aiCommitDiffChars)}''';

/// Runs git with [args] in this repository; its output.
String _git(List<String> args) {
  final result = Process.runSync('git', args);
  if (result.exitCode != 0) throw StateError('git $args: ${result.stderr}');
  return result.stdout.toString();
}

/// The area of [message], the text before its colon; null without one.
String? _areaOf(String message) {
  final colon = message.indexOf(':');
  if (colon <= 0 || colon > _maxAreaLength) return null;
  return message.substring(0, colon).trim().toLowerCase();
}

/// The words of [message] worth comparing.
Set<String> _wordsOf(String message) => {
  for (final match in _word.allMatches(message.toLowerCase()))
    if (match[0]!.length >= _minWordLength && !_stopWords.contains(match[0]))
      match[0]!,
};

/// The share of [reference]'s words [message] has.
double _recall(String message, String reference) {
  final wanted = _wordsOf(reference);
  if (wanted.isEmpty) return 0;
  return _wordsOf(message).intersection(wanted).length / wanted.length;
}

/// Whether [message] names the area [reference] names: their areas
/// share a word, plural or not.
bool _sameArea(String message, String reference) {
  final wanted = _areaOf(reference);
  final area = _areaOf(message);
  if (wanted == null || area == null) return false;
  Set<String> stems(String area) => {
    for (final word in _wordsOf(area)) word.replaceFirst(_plural, ''),
  };
  return stems(area).intersection(stems(wanted)).isNotEmpty;
}

/// The ending of a plural word.
final RegExp _plural = RegExp(r's$');

/// One change to replay: its diff, the project's messages before it, and
/// the message written for it by hand.
typedef _Case = ({
  String name,
  String changes,
  List<String> examples,
  String reference,
});

/// What a request answered, and how long it took.
typedef _Answer = ({String message, Duration took});

void main() {
  test(
    'replays recent commits through the local model, before and after '
    'the digest',
    () async {
      final model = OllamaClient(http.Client());
      final cases = <_Case>[
        if (_git(['diff', '--cached', '--name-only']).trim().isNotEmpty)
          (
            name: 'staged',
            changes:
                _git(['diff', '--cached', '-M', '--stat']) +
                _git(['diff', '--cached', '-M']),
            examples: _git([
              'log',
              '-${AppMetric.aiCommitStyleExamples}',
              '--format=%s',
            ]).trim().split('\n'),
            reference: _stagedReference,
          ),
        for (final sha
            in _git([
                  'log',
                  '--no-merges',
                  '-n',
                  '${_count! * 2}',
                  '--format=%H',
                ])
                .trim()
                .split('\n')
                .where(
                  (sha) => !_skipped.hasMatch(
                    _git(['log', '-1', '--format=%s', sha]),
                  ),
                )
                .take(_count!))
          (
            name: sha.substring(0, 7),
            changes:
                _git(['diff', '-M', '--stat', '$sha^', sha]) +
                _git(['diff', '-M', '$sha^', sha]),
            examples: _git([
              'log',
              '-${AppMetric.aiCommitStyleExamples}',
              '--format=%s',
              '$sha^',
            ]).trim().split('\n'),
            reference: _git(['log', '-1', '--format=%s', sha]).trim(),
          ),
      ];

      Future<_Answer> ask(String prompt) async {
        final watch = Stopwatch()..start();
        final reply = await model.generate(
          prompt,
          AppDuration.aiGenerateTimeout,
        );
        final line = reply
            .split('\n')
            .map((line) => line.trim())
            .firstWhere((line) => line.isNotEmpty, orElse: () => '');
        return (message: line.unquoted, took: watch.elapsed);
      }

      // Loading the model is no request's time
      await model.generate('Reply OK.', AppDuration.aiGenerateTimeout);
      var beforeWords = 0.0, afterWords = 0.0;
      var beforeAreas = 0, afterAreas = 0;
      var beforeTime = Duration.zero, afterTime = Duration.zero;
      for (final change in cases) {
        final before = await ask(_headPrompt(change.changes));
        final after = await ask(
          CommitMessageWriter.promptFor(
            change.changes,
            examples: change.examples,
          ),
        );
        final scores = [
          for (final answer in [before, after])
            (
              words: _recall(answer.message, change.reference),
              area: _sameArea(answer.message, change.reference),
            ),
        ];
        beforeWords += scores.first.words;
        afterWords += scores.last.words;
        if (scores.first.area) beforeAreas++;
        if (scores.last.area) afterAreas++;
        beforeTime += before.took;
        afterTime += after.took;
        print(
          '\n${change.name} (${change.changes.length} chars)\n'
          '  by hand: ${change.reference}\n'
          '  before:  ${before.message}\n'
          '           ${(scores.first.words * 100).round()}% of its words, '
          'area ${scores.first.area ? 'named' : 'missed'}, '
          '${before.took.inMilliseconds} ms\n'
          '  after:   ${after.message}\n'
          '           ${(scores.last.words * 100).round()}% of its words, '
          'area ${scores.last.area ? 'named' : 'missed'}, '
          '${after.took.inMilliseconds} ms',
        );
      }
      final n = cases.length;
      print(
        '\n${model.model}, $n changes\n'
        '  before: ${(beforeWords / n * 100).round()}% of the words, '
        'area named $beforeAreas/$n, '
        '${beforeTime.inMilliseconds ~/ n} ms each\n'
        '  after:  ${(afterWords / n * 100).round()}% of the words, '
        'area named $afterAreas/$n, '
        '${afterTime.inMilliseconds ~/ n} ms each',
      );
    },
    skip: _count == null
        ? 'set FIDE_AI_REPLAY to the number of commits to replay on the '
              'local Ollama model'
        : null,
    timeout: Timeout.none,
  );
}
