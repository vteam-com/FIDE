import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/models/action_outcome.dart';
import 'package:fide/models/app_icon_review.dart';
import 'package:fide/models/locale_number.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/app_icon_fixer.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path/path.dart' as p;

/// The App Icons view's fixes, with the ids of the platforms whose icons
/// are being written.
final appIconFixControllerProvider =
    StateNotifierProvider.autoDispose<AppIconFixController, Set<String>>(
      (ref) => AppIconFixController(
        fixer: ref.read(appIconFixerProvider),
        reloadWritten: ref.read(openDocumentsProvider.notifier).reloadWritten,
      ),
    );

/// Reloads the files at the given absolute paths in the editor.
typedef ReloadWritten = Future<void> Function(Iterable<String> paths);

/// Regenerates platforms' app icons from a master image, one platform at
/// a time; its state is the ids of the platforms being written.
class AppIconFixController extends StateNotifier<Set<String>> {
  final AppIconFixer _fixer;

  final ReloadWritten _reloadWritten;

  /// Creates a controller writing icons with [fixer] and reloading the
  /// files it rewrote with [reloadWritten].
  AppIconFixController({
    required AppIconFixer fixer,
    required ReloadWritten reloadWritten,
  }) : this._(fixer, reloadWritten);

  AppIconFixController._(this._fixer, this._reloadWritten) : super(const {});

  /// Writes the icons of [platforms] in the project at [projectPath] from
  /// the image at [masterPath], then drops the cached previews and reloads
  /// the files rewritten in the editor; the outcome counts the files
  /// written, or lists the platforms that failed.
  Future<ActionOutcome> fix(
    String projectPath,
    Iterable<AppIconPlatformReview> platforms,
    String masterPath,
  ) async {
    _update({...state, for (final platform in platforms) platform.id});
    final written = <String>[];
    final failures = <String>[];
    for (final platform in platforms) {
      try {
        written.addAll(
          await _fixer.fix(
            projectPath,
            fcheck.AppIconPlatform.values.byName(platform.id),
            masterPath,
          ),
        );
      } catch (e) {
        failures.add('${platform.label}: $e');
      }
      _update({...state}..remove(platform.id));
    }
    // The previews show files rewritten in place
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    await _reloadWritten([
      for (final path in written) p.join(projectPath, path),
    ]);
    return failures.isEmpty
        ? ActionOutcome.success('Wrote ${written.length.count('file')}')
        : ActionOutcome.failure(failures.join('\n'));
  }

  /// Replaces the state with [fixing], unless the controller was disposed
  /// while a fix was pending.
  void _update(Set<String> fixing) {
    if (mounted) state = fixing;
  }
}
