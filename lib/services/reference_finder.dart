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
import 'package:fide/models/lookup_field.dart';
import 'package:fide/models/search_result.dart';
import 'package:fide/services/compile_errors.dart';
import 'package:fide/services/flutter_sdk.dart';
import 'package:path/path.dart' as p;

part 'reference_finder.check_compiles_request.dart';
part 'reference_finder.find_references_request.dart';
part 'reference_finder.lookup_field_request.dart';
part 'reference_finder.lookup_fields.dart';
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
  /// Creates a finder for the project at `projectPath`, resolving against
  /// the Dart SDK `flutterSdk` bundles.
  ReferenceFinder({required this._projectPath, required this._flutterSdk});

  final FlutterSdk _flutterSdk;

  Isolate? _isolate;

  final String _projectPath;

  Future<SendPort>? _worker;

  /// Stops the background analysis.
  void dispose() => _isolate?.kill(priority: Isolate.immediate);

  /// Uses of the declaration starting at 1-based [line] and [column] of
  /// [filePath], outside the declaration itself, in file then source order.
  ///
  /// Throws when the analysis can't start, the file can't be analyzed or
  /// no declaration starts there (e.g. unsaved edits moved it).
  Future<List<SearchResult>> find({
    required String filePath,
    required int line,
    required int column,
  }) => _request(FindReferencesRequest(filePath, line, column));

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
    final sdkPath = await _flutterSdk.dartSdkPath();
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
