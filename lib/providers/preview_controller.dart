import 'dart:async';
import 'dart:math';

import 'package:fide/models/preview_frame.dart';
import 'package:fide/models/preview_item.dart';
import 'package:fide/models/preview_pointer_phase.dart';
import 'package:fide/models/preview_scan.dart';
import 'package:fide/models/preview_scope.dart';
import 'package:fide/models/preview_settings.dart';
import 'package:fide/providers/ai_request.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/preview_scope_notifier.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/preview_generator.dart';
import 'package:fide/services/preview_host.dart';
import 'package:fide/services/preview_project_scanner.dart';
import 'package:fide/services/preview_registry.dart';
import 'package:fide/services/preview_scanner.dart';
import 'package:fide/services/preview_size_fixer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

part 'preview_controller.preview_state.dart';

/// The source of the preview host FIDE copies into each project.
final previewHostSourceProvider = FutureProvider<String>(
  (_) => rootBundle.loadString('assets/preview_host/main.dart.tmpl'),
);

/// The live previews of the file selected, kept for the open project.
final previewControllerProvider =
    NotifierProvider<PreviewController, PreviewState>(PreviewController.new);

/// Runs the Preview panel: scans the selected file, or the whole project,
/// for its previews, runs the project's [PreviewHost] once there are some,
/// hot reloads it as files are saved, and keeps the frames it sends.
///
/// For the project, only the one preview expanded is rendered, so the
/// list scales to any number of previews.
///
/// The host starts with the panel's first rendered preview and runs until
/// the project closes, so switching files or previews only reloads it.
class PreviewController extends Notifier<PreviewState> {
  /// Most preview errors kept.
  static const int _maxLogs = 20;

  /// Narrowest a preview without a width of its own lays out, however
  /// narrow the panel.
  static const double _minLayoutWidth = 120;

  /// Tallest a preview without a height of its own lays out.
  static const double _maxLayoutHeight = 640;

  /// The height of a preview that sets none and has no natural height,
  /// such as a scroll view.
  static const double _fallbackLayoutHeight = 240;

  /// Width of the panel the previews don't get: the card's frame and the
  /// list's padding.
  static const double _layoutInset = 48;

  /// How the compiler starts an error, after its `file:line:column`.
  static const String _compileError = ': Error: ';

  PreviewHost? _host;
  Future<void> _work = Future.value();
  PreviewSettings? _settings;
  ({double width, double devicePixelRatio, double zoom, Brightness app})?
  _viewport;
  String? _projectPath;

  @override
  PreviewState build() {
    _projectPath = ref.watch(currentProjectPathProvider);
    ref.listen(selectedFileProvider, (_, file) {
      _enqueue(() => _show(file?.path));
    });
    ref.listen(savedFilesRevisionProvider, (_, _) => _enqueue(_refresh));
    ref.listen(previewScopeProvider, (_, scope) {
      _enqueue(() => _setScope(scope));
    });
    ref.onDispose(() {
      final host = _host;
      _host = null;
      unawaited(host?.stop());
    });
    // Reads the selection when it runs, after any change made meanwhile
    _enqueue(() => _show(ref.read(selectedFileProvider)?.path));
    return PreviewState(scope: ref.read(previewScopeProvider));
  }

  /// Tells the host how wide the panel is, its pixel ratio, zoom and
  /// FIDE's brightness, so previews lay out and render to fit.
  void configure({
    required double width,
    required double devicePixelRatio,
    required double zoom,
    required Brightness appBrightness,
  }) {
    _viewport = (
      width: width,
      devicePixelRatio: devicePixelRatio,
      zoom: zoom,
      app: appBrightness,
    );
    _sendSettings();
  }

  /// Renders the previews in [brightness].
  void setBrightness(PreviewBrightness brightness) {
    state = state.copyWith(brightness: brightness);
    _sendSettings();
  }

  /// Forwards a pointer event at [position], in logical pixels of the
  /// preview at [index].
  void pointer(
    int index,
    PreviewPointerPhase phase,
    Offset position, {
    Offset scroll = Offset.zero,
  }) {
    _host?.pointer(
      index,
      phase.name,
      position.dx,
      position.dy,
      dx: scroll.dx,
      dy: scroll.dy,
    );
  }

  /// Hot restarts the previews, resetting their state, or starts them
  /// again when they stopped.
  void restart() => _enqueue(() async {
    final host = _host;
    if (host == null) return _refresh();
    state = state.copyWith(status: PreviewStatus.reloading, message: '');
    _finishReload(await host.reload(full: true));
  });

  /// Expands the project preview [label] of file [path], collapsing the
  /// one expanded, and renders it; collapses it when it is expanded.
  void toggle(String path, String label) {
    final key = (path: path, label: label);
    state = state.copyWith(
      expanded: (key: state.expanded == key ? null : key),
      items: const [],
    );
    _enqueue(_renderProject);
  }

  /// Forgets the errors the previews reported.
  void clearLogs() => state = state.copyWith(logs: const []);

  /// Adds a preview to the file for each widget that has none and whose
  /// arguments can be picked from their types; the saved file then
  /// reloads the previews. Returns what was generated.
  Future<PreviewGeneration?> generatePreviews() async {
    final path = state.filePath;
    if (path == null) return null;
    state = state.copyWith(isGenerating: true);
    PreviewGeneration? generation;
    try {
      await _editFile(path, (content) {
        final result = generation = const PreviewGenerator().generate(
          content,
          const PreviewScanner().scan(content),
        );
        return result.added.isEmpty ? null : result.content;
      });
    } finally {
      if (ref.mounted) state = state.copyWith(isGenerating: false);
    }
    return generation;
  }

  /// Writes the size [item] rendered at in its annotation in [path], so
  /// it no longer follows the panel or the host's default; the saved file
  /// then reloads the previews.
  Future<void> fixSize(String path, PreviewItem item) async {
    final frame = item.frame;
    if (frame == null) return;
    await _editFile(
      path,
      (content) => const PreviewSizeFixer().withSize(
        content,
        label: item.function,
        annotation: item.annotation,
        size: frame.size,
      ),
    );
  }

  /// Rewrites [path] with what [edit] makes of its content, formatted,
  /// through the editor's project-wide edits; nothing when [edit] returns
  /// null.
  Future<void> _editFile(
    String path,
    String? Function(String content) edit,
  ) async {
    await ref.read(openDocumentsProvider.notifier).applyEdits(() async {
      final content = await ref.read(fileContentReaderProvider).read(path);
      final edited = edit(content);
      if (edited == null) return const {};
      final formatter = ref.read(codeFormatterProvider);
      return {path: await formatter.formatOrKeep(path, edited)};
    });
  }

  /// Has the AI panel write previews for [widgets], whose arguments need
  /// sample values only someone who knows the code can pick.
  void askAiForPreviews(List<PreviewWidget> widgets) {
    final path = state.filePath;
    if (path == null || widgets.isEmpty) return;
    final project = _projectPath;
    final file = project == null ? path : p.relative(path, from: project);
    final names = widgets.map((widget) => widget.name).join(', ');
    ref
        .read(aiRequestsProvider)
        .ask(
          'In $file, add a widget preview for each of these widgets: $names. '
          'For each one, write a public top-level function returning the '
          "widget, annotated with @Preview(name: '<widget name>') from "
          "'${PreviewGenerator.previewImport}', and build its required "
          'arguments with realistic sample values. Don\'t change the '
          'widgets themselves.',
        );
  }

  /// Runs [job] after the jobs before it, so starts and reloads never
  /// overlap.
  void _enqueue(Future<void> Function() job) {
    _work = _work.then((_) => ref.mounted ? job() : null).catchError((
      Object error,
    ) {
      if (ref.mounted) {
        state = state.copyWith(status: PreviewStatus.failed, message: '$error');
      }
    });
  }

  /// Lists the previews of [scope].
  Future<void> _setScope(PreviewScope scope) async {
    if (scope == state.scope) return;
    state = state.copyWith(
      scope: scope,
      items: const [],
      message: '',
      status: PreviewStatus.reloading,
    );
    await _refresh();
  }

  /// Shows the previews of [path] when listing the file's.
  Future<void> _show(String? path) async {
    if (state.scope == PreviewScope.project) {
      // Kept for when the panel lists the file's previews again
      state = state.copyWith(filePath: path);
      return;
    }
    if (path == null || p.extension(path) != '.dart') {
      state = PreviewState(
        filePath: path,
        brightness: state.brightness,
        scope: state.scope,
      );
      return;
    }
    if (path != state.filePath) {
      state = PreviewState(
        filePath: path,
        status: PreviewStatus.reloading,
        brightness: state.brightness,
        logs: state.logs,
        scope: state.scope,
      );
    }
    await _refresh();
  }

  /// Scans the file, or the project, again and renders its previews as
  /// saved.
  Future<void> _refresh() =>
      state.scope == PreviewScope.project ? _refreshProject() : _refreshFile();

  /// Scans the file shown again and renders its previews.
  Future<void> _refreshFile() async {
    final path = state.filePath;
    if (path == null || p.extension(path) != '.dart') {
      state = state.copyWith(status: PreviewStatus.noFile);
      return;
    }
    final content = await ref.read(fileContentReaderProvider).read(path);
    final scan = const PreviewScanner().scan(content);
    if (!ref.mounted || state.filePath != path) return;
    if (scan.isPart || scan.previews.isEmpty) {
      state = state.copyWith(
        scan: scan,
        status: scan.isPart ? PreviewStatus.part : PreviewStatus.noPreviews,
        items: const [],
        message: '',
      );
      return;
    }
    await _render(path, scan);
  }

  /// Scans the project again for its previews and renders the one
  /// expanded, if it still exists.
  Future<void> _refreshProject() async {
    final project = _projectPath;
    if (project == null) return;
    state = state.copyWith(isScanning: true);
    final files = await const PreviewProjectScanner().scan(project);
    if (!ref.mounted || state.scope != PreviewScope.project) return;
    final expanded = state.expanded;
    final stillThere =
        expanded != null &&
        files.any(
          (file) =>
              file.path == expanded.path &&
              file.scan.previews.any((d) => d.label == expanded.label),
        );
    state = state.copyWith(
      projectFiles: files,
      isScanning: false,
      expanded: stillThere ? null : (key: null),
    );
    await _renderProject();
  }

  /// Renders the one project preview expanded; with none, empties the
  /// host so it renders nothing.
  Future<void> _renderProject() async {
    final project = _projectPath;
    if (project == null || state.scope != PreviewScope.project) return;
    final expanded = state.expanded;
    final file = expanded == null
        ? null
        : state.projectFiles.where((f) => f.path == expanded.path).firstOrNull;
    if (expanded == null || file == null) {
      state = state.copyWith(
        items: const [],
        message: '',
        status: state.projectFiles.isEmpty
            ? PreviewStatus.noPreviews
            : PreviewStatus.ready,
      );
      final host = _host;
      if (host != null) {
        await (await _registry(project)).writeEmptyRegistry();
        await host.reload();
      }
      return;
    }
    await _render(expanded.path, file.scan.only(expanded.label));
  }

  /// Renders the previews [scan] found in [path], starting the host or
  /// hot reloading it.
  Future<void> _render(String path, PreviewScan scan) async {
    final project = _projectPath;
    if (project == null) return;
    final registry = await _registry(project);
    await registry.writeRegistry(path, scan);
    final host = _host;
    if (host == null) {
      await _start(registry, scan);
      return;
    }
    state = state.copyWith(
      scan: scan,
      status: PreviewStatus.reloading,
      message: '',
    );
    var error = await host.reload();
    if (error != null && !error.contains(_compileError)) {
      // A change hot reload can't apply, such as to a class's shape, needs
      // a restart; a compile error would only fail again
      error = await host.reload(full: true);
    }
    _finishReload(error);
  }

  /// Starts the host of the project [registry] belongs to, for [scan].
  Future<void> _start(PreviewRegistry registry, PreviewScan scan) async {
    state = state.copyWith(
      scan: scan,
      status: PreviewStatus.starting,
      message: '',
    );
    await registry.writeHost(await ref.read(previewHostSourceProvider.future));
    final host = PreviewHost(
      runner: ref.read(processRunnerProvider),
      projectPath: registry.projectPath,
      onPreviews: _onPreviews,
      onFrame: _onFrame,
      onLog: _onLog,
      onExit: _onExit,
    );
    _host = host;
    final settings = _settings;
    if (settings != null) host.configure(settings);
    try {
      await host.start();
    } on Object catch (error) {
      _host = null;
      await host.stop();
      if (!ref.mounted) return;
      state = state.copyWith(
        status: PreviewStatus.failed,
        message: error is StateError ? error.message : '$error',
      );
      return;
    }
    if (!ref.mounted) {
      await host.stop();
      return;
    }
    state = state.copyWith(status: PreviewStatus.ready);
  }

  /// The registry of the project at [projectPath].
  Future<PreviewRegistry> _registry(String projectPath) async {
    final name = await ref
        .read(projectConfigReaderProvider)
        .packageName(projectPath);
    return PreviewRegistry(
      projectPath: projectPath,
      packageName: name ?? p.basename(projectPath),
    );
  }

  /// Shows the outcome of a reload: [error] when it failed.
  void _finishReload(String? error) {
    if (!ref.mounted) return;
    state = state.copyWith(
      status: error == null ? PreviewStatus.ready : PreviewStatus.failed,
      message: error ?? '',
    );
  }

  /// Sends the host the settings for the panel's viewport and the
  /// brightness picked, when they changed.
  void _sendSettings() {
    final viewport = _viewport;
    if (viewport == null) return;
    final settings = PreviewSettings(
      pixelRatio: viewport.devicePixelRatio * viewport.zoom,
      maxWidth: max(
        _minLayoutWidth,
        (viewport.width - _layoutInset) / viewport.zoom,
      ),
      maxHeight: _maxLayoutHeight,
      fallbackHeight: _fallbackLayoutHeight,
      brightness: state.brightness.forced,
      fallbackBrightness: viewport.app,
    );
    if (settings == _settings) return;
    _settings = settings;
    _host?.configure(settings);
  }

  /// Shows the [items] the host lists as [generation].
  void _onPreviews(int generation, List<PreviewItem> items) {
    if (!ref.mounted) return;
    final previous = state.items;
    state = state.copyWith(
      generation: generation,
      items: [
        // Keep the last frames until new ones arrive, so cards don't blink
        for (final (index, item) in items.indexed)
          if (previous.elementAtOrNull(index)
              case PreviewItem(function: final function, :final frame?)
              when function == item.function)
            item.withFrame(frame)
          else
            item,
      ],
    );
  }

  /// Shows [frame] on its preview, unless it is from an older list.
  void _onFrame(PreviewFrame frame) {
    if (!ref.mounted || frame.generation != state.generation) return;
    final items = state.items;
    if (frame.index >= items.length) return;
    state = state.copyWith(
      items: [...items]..[frame.index] = items[frame.index].withFrame(frame),
    );
  }

  /// Keeps an error the previews reported, the latest [_maxLogs] only.
  void _onLog(String message) {
    if (!ref.mounted) return;
    final logs = [...state.logs, message];
    state = state.copyWith(
      logs: logs.skip(max(0, logs.length - _maxLogs)).toList(),
    );
  }

  /// Reports the host stopped by itself, with its last [output].
  void _onExit(String output) {
    _host = null;
    if (!ref.mounted) return;
    state = state.copyWith(
      status: PreviewStatus.failed,
      message: 'The preview host stopped.\n$output',
    );
  }
}
