import 'dart:io';
import 'dart:isolate';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/file_system/overlay_file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:fide/models/search_result.dart';
import 'package:fide/providers/compile_errors.dart';
import 'package:fide/providers/flutter_sdk.dart';

part 'reference_finder.reference_worker.dart';
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
  }) async {
    final response = await _request((filePath, line, column, null));
    return response as List<SearchResult>;
  }

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
  }) async {
    final response = await _request((filePath, line, column, newName));
    return response as Map<String, String>;
  }

  /// Sends [request] to the worker and returns its answer, throwing the
  /// error message it answers with instead.
  Future<Object?> _request((String, int, int, String?) request) async {
    final worker = await (_worker ??= _spawn());
    final reply = ReceivePort();
    final (filePath, line, column, newName) = request;
    worker.send((filePath, line, column, newName, reply.sendPort));
    final response = await reply.first;
    reply.close();
    if (response is String) throw Exception(response);
    return response;
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
