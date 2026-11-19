import 'dart:io';
import 'dart:isolate';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/file_system/overlay_file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:fide/models/lookup_field.dart';
import 'package:fide/models/search_result.dart';
import 'package:fide/models/text_offsets.dart';
import 'package:fide/services/compile_errors.dart';
import 'package:path/path.dart' as p;

part 'reference_finder.callee_visitor.dart';
part 'reference_finder.callees_request.dart';
part 'reference_finder.check_compiles_request.dart';
part 'reference_finder.declaration_request.dart';
part 'reference_finder.file_texts.dart';
part 'reference_finder.find_references_request.dart';
part 'reference_finder.lookup_field_request.dart';
part 'reference_finder.lookup_fields.dart';
part 'reference_finder.lookup_fields_request.dart';
part 'reference_finder.reference_request.dart';
part 'reference_finder.reference_worker.dart';
part 'reference_finder.rename_request.dart';
part 'reference_finder.usage_visitor.dart';

/// Finds where a project uses a declaration (its consumers), by resolving
/// the code with the Dart analyzer rather than matching text, so `build`
/// finds calls of that `build` only.
///
/// The analysis lives in a background isolate started on first use and kept
/// for later lookups, which then only re-read files changed on disk.
class ReferenceFinder {
  /// The error message of a [find] or [callees] a newer one replaced
  /// before it started.
  static const String superseded = 'A newer lookup replaced this one';

  /// Creates a finder for the project at `projectPath`, resolving against
  /// the Dart SDK `dartSdkPath` finds, such as the session's
  /// `dartSdkPathProvider`.
  ReferenceFinder({required this._projectPath, required this._dartSdkPath});

  /// Root of the Dart SDK bundled with Flutter; null when Flutter isn't
  /// found.
  final Future<String?> Function() _dartSdkPath;

  Isolate? _isolate;

  final String _projectPath;

  Future<SendPort>? _worker;

  /// Stops the background analysis.
  void dispose() => _isolate?.kill(priority: Isolate.immediate);

  /// Uses of the declaration starting at 1-based [line] and [column] of
  /// [filePath], outside the declaration itself, in file then source order.
  ///
  /// Throws when the analysis can't start, the file can't be analyzed or
  /// no declaration starts there (e.g. unsaved edits moved it), and with
  /// [superseded] when a newer [find] is asked before this one starts:
  /// only the latest find is worth computing.
  Future<List<SearchResult>> find({
    required String filePath,
    required int line,
    required int column,
  }) => _request(FindReferencesRequest(filePath, line, column));

  /// What the function or method starting at 1-based [line] and [column]
  /// of [filePath] calls that the project declares: the functions,
  /// methods, constructors and explicit getters and setters it calls or
  /// tears off, each once, in the order first named, as the place each is
  /// declared (a class for its implicit constructor).
  ///
  /// Throws as [find] does, [superseded] included.
  Future<List<SearchResult>> callees({
    required String filePath,
    required int line,
    required int column,
  }) => _request(CalleesRequest(filePath, line, column));

  /// The `String` field the argument starting at [offset] of [filePath]
  /// fills through a `this.` parameter, with every value passed to it and
  /// every read of it in the project, for it to become a lookup function.
  ///
  /// Throws, saying why, when the argument fills no such field, or the
  /// field is read where no `BuildContext` is or is assigned.
  Future<LookupField> lookupField({
    required String filePath,
    required int offset,
  }) => _request(LookupFieldRequest(filePath, offset));

  /// [lookupField] for each of [sites], in their order, answered in one
  /// request: the project is checked for changes once and a field filled
  /// at several sites is looked up once. Each answer holds the field, or
  /// the message saying why there is none.
  ///
  /// Throws when the analysis can't start or the project can't be read.
  Future<List<LookupSiteField>> lookupFields(List<LookupSite> sites) =>
      _request(LookupFieldsRequest(sites));

  /// Throws, saying what breaks, when [contents] would give any of their
  /// files more compile errors than it has now; [action] names the change,
  /// such as `Renaming`. Nothing is written.
  Future<void> checkCompiles(Map<String, String> contents, String action) =>
      _request(CheckCompilesRequest(contents, action));

  /// New contents of every file that renaming the declaration at [line]
  /// and [column] of [filePath] to [newName] changes: the declaration and
  /// each use (for a field, also its `this.` parameters and their named
  /// arguments). Nothing is written.
  ///
  /// Throws, as [find] does, and when [newName] isn't a Dart name or the
  /// renamed code would have more compile errors.
  Future<Map<String, String>> rename({
    required String filePath,
    required int line,
    required int column,
    required String newName,
  }) => _request(RenameRequest(filePath, line, column, newName));

  /// Sends [request] to the worker and returns its answer, throwing the
  /// error message it answers with instead.
  Future<T> _request<T>(ReferenceRequest<T> request) async {
    final worker = await (_worker ??= _spawn());
    final reply = ReceivePort();
    worker.send((request, reply.sendPort));
    final (:answer, :error) = await reply.first as _ReferenceReply;
    reply.close();
    if (error != null) throw Exception(error);
    return request.answerFrom(answer);
  }

  /// Starts the analysis isolate and returns its request port.
  Future<SendPort> _spawn() async {
    final sdkPath = await _dartSdkPath();
    if (sdkPath == null) {
      _worker = null;
      throw Exception('Flutter SDK not found');
    }
    final ready = ReceivePort();
    _isolate = await Isolate.spawn(_ReferenceWorker.main, (
      ready.sendPort,
      _projectPath,
      sdkPath,
    ));
    final port = await ready.first as SendPort;
    ready.close();
    return port;
  }
}
