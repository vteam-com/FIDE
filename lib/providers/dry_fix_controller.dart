import 'package:fide/models/action_outcome.dart';
import 'package:fide/models/dry_review.dart';
import 'package:fide/models/locale_number.dart';
import 'package:fide/providers/open_documents_notifier.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/code_formatter.dart';
import 'package:fide/services/file_content_reader.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path/path.dart' as p;

/// Applies the DRY Review's fixes; its state is the key of the one being
/// written, null while none is.
final dryFixControllerProvider =
    StateNotifierProvider.autoDispose<DryFixController, Object?>(
      (ref) => DryFixController(
        applyEdits: ref.read(openDocumentsProvider.notifier).applyEdits,
        reader: ref.read(fileContentReaderProvider),
        formatter: ref.read(codeFormatterProvider),
      ),
    );

/// Writes the files a project-wide edit returns, keyed by absolute path,
/// as [OpenDocumentsNotifier.applyEdits] does.
typedef ApplyEdits = Future<Map<String, String>> Function(
  Future<Map<String, String>> Function() edit,
);

/// Applies [DryFix]es to the project's files, one at a time; its state is
/// the key of the one being written, so only the button that started it
/// shows it running, null while none is.
class DryFixController extends StateNotifier<Object?> {
  /// Creates a controller writing files with [applyEdits], reading them
  /// with [reader] and formatting them with [formatter].
  DryFixController({
    required ApplyEdits applyEdits,
    required FileContentReader reader,
    required CodeFormatter formatter,
  }) : this._(applyEdits, reader, formatter);

  DryFixController._(this._applyEdits, this._reader, this._formatter)
    : super(null);

  final ApplyEdits _applyEdits;

  final CodeFormatter _formatter;

  final FileContentReader _reader;

  /// Makes [fix]'s edits in the project at [projectPath] and creates its
  /// files, formatting them and the files edited that were formatted; the
  /// outcome counts the places fixed, or says why nothing was, such as a
  /// file edited since the review or one to create already there. While
  /// it runs, the state is [key], or [fix] when null.
  Future<ActionOutcome> fix(
    String projectPath,
    DryFix fix, {
    Object? key,
  }) async {
    _update(key ?? fix);
    try {
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
        count = applied.count;
        return {
          for (final MapEntry(key: path, value: content)
              in applied.contents.entries)
            p.join(projectPath, path): await _formatted(
              p.join(projectPath, path),
              content,
              before: contents[path],
            ),
        };
      });
      return ActionOutcome.success('Fixed ${count.count('place')}');
    } catch (e) {
      return ActionOutcome.failure('$e');
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
  /// while a fix was pending.
  void _update(Object? running) {
    if (mounted) state = running;
  }
}
