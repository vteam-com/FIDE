import 'package:fide/models/action_outcome.dart';
import 'package:fide/models/file_layout_review.dart';
import 'package:fide/models/import_graph.dart';
import 'package:fide/models/locale_number.dart';
import 'package:fide/models/project_paths.dart';
import 'package:fide/models/readable_error.dart';
import 'package:fide/models/repeated_settings_review.dart';
import 'package:fide/providers/open_documents_notifier.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/blocking_task.dart';
import 'package:fide/services/chat_model.dart';
import 'package:fide/services/code_formatter.dart';
import 'package:fide/services/file_content_reader.dart';
import 'package:fide/services/file_mover.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path/path.dart' as p;

/// Applies the Analyzer tab's changes: the Repeated Widget Settings
/// review's fixes and the File Layout review's moves; its state is the
/// key of the one being written, null while none is.
final analyzerFixControllerProvider =
    StateNotifierProvider.autoDispose<AnalyzerFixController, Object?>((ref) {
      final documents = ref.read(openDocumentsProvider.notifier);
      return AnalyzerFixController(
        applyEdits: documents.applyEdits,
        applyMoves: documents.applyMoves,
        reader: ref.read(fileContentReaderProvider),
        formatter: ref.read(codeFormatterProvider),
        mover: ref.read(fileMoverProvider),
      );
    });

/// Writes the files a project-wide edit returns, keyed by absolute path,
/// as [OpenDocumentsNotifier.applyEdits] does.
typedef ApplyEdits = Future<Map<String, String>> Function(
  Future<Map<String, String>> Function() edit,
);

/// Writes the files a project-wide edit moving files returns, keyed by
/// absolute path, then deletes the moved ones, as
/// [OpenDocumentsNotifier.applyMoves] does.
typedef ApplyMoves = Future<Map<String, String>> Function(
  Map<String, String> moves,
  Future<Map<String, String>> Function() edit,
);

/// Applies [RepeatedSettingsFix]es and [FileMove]s to the project's files, one at a
/// time; its state is the key of the one being written, null while none
/// is, the buttons disabled meanwhile.
class AnalyzerFixController extends StateNotifier<Object?> {
  /// The outcome of a change the user cancelled, before it wrote anything.
  static const String cancelledMessage = 'Cancelled; nothing changed';

  /// Creates a controller writing files with [applyEdits] and
  /// [applyMoves], reading them with [reader], formatting them with
  /// [formatter] and planning moves with [mover].
  AnalyzerFixController({
    required ApplyEdits applyEdits,
    required ApplyMoves applyMoves,
    required FileContentReader reader,
    required CodeFormatter formatter,
    required FileMover mover,
  }) : this._(applyEdits, applyMoves, reader, formatter, mover);

  AnalyzerFixController._(
    this._applyEdits,
    this._applyMoves,
    this._reader,
    this._formatter,
    this._mover,
  ) : super(null);

  final ApplyEdits _applyEdits;

  final ApplyMoves _applyMoves;

  final CodeFormatter _formatter;

  final FileMover _mover;

  final FileContentReader _reader;

  /// Makes [fix]'s edits in the project at [projectPath] and creates its
  /// files, formatting them and the files edited that were formatted; the
  /// outcome counts the places fixed, or says why nothing was, such as a
  /// file edited since the review, one to create already there, or a
  /// Layers issue it would add to [layers], the dependencies between the
  /// files of `lib` in the package [packageName]. While it runs, the state
  /// is [key], or [fix] when null; [task]'s Cancel stops it before it
  /// writes anything.
  Future<ActionOutcome> fix(
    String projectPath,
    RepeatedSettingsFix fix, {
    Object? key,
    ImportGraph layers = const ImportGraph({}),
    String? packageName,
    BlockingTask? task,
  }) => _run(key ?? fix, () async {
    var count = 0;
    await _applyEdits(() async {
      for (final path in fix.created.keys) {
        if (await _reader.exists(p.join(projectPath, path))) {
          throw StateError('$path already exists: pick another name');
        }
      }
      final contents = {
        for (final path in fix.paths)
          path: await _reader.read(p.join(projectPath, path)),
      };
      final applied = fix.applyTo(contents);
      _refuseNewIssues(layers, applied.contents, packageName);
      count = applied.count;
      final files = {
        for (final MapEntry(key: path, value: content)
            in applied.contents.entries)
          p.join(projectPath, path): await _formatted(
            p.join(projectPath, path),
            content,
            before: contents[path],
          ),
      };
      task?.cancelToken.throwIfCancelled();
      return files;
    });
    return 'Fixed ${count.count('place')}';
  });

  /// Moves the files of [moves], with their parts, in the project at
  /// [projectPath], whose package is [packageName], pointing every
  /// directive naming them at their new place; the outcome counts the
  /// files moved, or says why none was, such as a file already where one
  /// goes. [moves] are a [FileLayoutPlan]'s, which adds no dependency
  /// cycle. While it runs, the state is [key]; [task]'s Cancel stops it
  /// before it writes or deletes anything.
  Future<ActionOutcome> move(
    String projectPath,
    List<FileMove> moves, {
    required Object key,
    String? packageName,
    BlockingTask? task,
  }) => _run(key, () async {
    final paths = {for (final move in moves) ...move.paths};
    final absolute = ProjectPaths(projectPath).absoluteOf;
    await _applyMoves(
      {
        for (final MapEntry(key: from, value: to) in paths.entries)
          absolute(from): absolute(to),
      },
      () async {
        final files = await _mover.plan(
          projectPath,
          paths,
          packageName: packageName,
        );
        // Thrown, not empty: an empty plan would still delete the files
        task?.cancelToken.throwIfCancelled();
        return files;
      },
    );
    return 'Moved ${moves.length.count('file')}';
  });

  /// Throws when [changed], files' new text by project-relative path,
  /// would add a Layers issue fCheck reports to [before]; checks nothing
  /// when [before] is empty.
  static void _refuseNewIssues(
    ImportGraph before,
    Map<String, String> changed,
    String? packageName,
  ) {
    if (before.edges.isEmpty) return;
    final after = before.updated({
      for (final MapEntry(key: path, value: content) in changed.entries)
        if (p.posix.isWithin(ProjectPaths.libFolder, path)) path: content,
    }, packageName: packageName);
    final added = ImportGraph.compareIssues(
      before.layerIssues,
      after.layerIssues,
    ).added;
    if (added.isNotEmpty) {
      throw StateError(
        'Not fixed: it would add a Layers issue fCheck reports: '
        '${added.first.message}',
      );
    }
  }

  /// Runs [task] with the state at [key], its outcome a success saying
  /// what [task] returns, or the failure it threw.
  Future<ActionOutcome> _run(Object key, Future<String> Function() task) async {
    _update(key);
    try {
      return ActionOutcome.success(await task());
    } on AiCancelledException {
      return const ActionOutcome.info(cancelledMessage);
    } catch (e) {
      return ActionOutcome.failure(ReadableError.describe(e));
    } finally {
      _update(null);
    }
  }

  /// [content], to be written at [path], formatted when the file was
  /// [before] it, or is new; unchanged when it can't be formatted.
  Future<String> _formatted(
    String path,
    String content, {
    String? before,
  }) async {
    if (before != null &&
        await _formatter.formatOrKeep(path, before) != before) {
      return content;
    }
    return _formatter.formatOrKeep(path, content);
  }

  /// Replaces the state with [running], unless the controller was disposed
  /// while a change was pending.
  void _update(Object? running) {
    if (mounted) state = running;
  }
}
