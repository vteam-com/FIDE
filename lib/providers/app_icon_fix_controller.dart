import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/models/action_outcome.dart';
import 'package:fide/models/app_icon_review.dart';
import 'package:fide/models/locale_number.dart';
import 'package:fide/models/readable_error.dart';
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
        useMaster: (path) =>
            ref.read(appIconMasterChoiceProvider.notifier).state = path,
      ),
    );

/// Makes the master image at the given absolute path the one icons are
/// generated from.
typedef UseMaster = void Function(String path);

/// Regenerates platforms' app icons from a master image, one platform at
/// a time; its state is the ids of the platforms being written, and
/// [masterId] while the master itself is.
class AppIconFixController extends StateNotifier<Set<String>> {
  /// The state's entry while the master image is being rewritten.
  static const String masterId = 'master';

  final AppIconFixer _fixer;

  final ReloadWritten _reloadWritten;

  final UseMaster _useMaster;

  /// Creates a controller writing icons with [fixer], reloading the files
  /// it rewrote with [reloadWritten] and switching to a rewritten master
  /// with [useMaster].
  AppIconFixController({
    required AppIconFixer fixer,
    required ReloadWritten reloadWritten,
    required UseMaster useMaster,
  }) : this._(fixer, reloadWritten, useMaster);

  AppIconFixController._(this._fixer, this._reloadWritten, this._useMaster)
    : super(const {});

  /// Writes the icons of [platforms] in the project at [projectPath] from
  /// the image at [masterPath], first rewriting that image as a square
  /// PNG large enough when [fixMaster], then drops the cached previews
  /// and reloads the files rewritten in the editor; the outcome counts
  /// the files written, or lists what failed.
  Future<ActionOutcome> fix(
    String projectPath,
    Iterable<AppIconPlatformReview> platforms,
    String masterPath, {
    bool fixMaster = false,
  }) async {
    _update({
      ...state,
      if (fixMaster) masterId,
      for (final platform in platforms) platform.id,
    });
    // Absolute paths: the master may live outside the project
    final written = <String>[];
    final failures = <String>[];
    var source = masterPath;
    if (fixMaster) {
      try {
        source = await _fixer.fixMaster(masterPath);
        written.add(source);
        _useMaster(source);
      } catch (e) {
        failures.add('Master image: ${ReadableError.describe(e)}');
      }
      _update({...state}..remove(masterId));
    }
    for (final platform in platforms) {
      try {
        final files = await _fixer.fix(
          projectPath,
          fcheck.AppIconPlatform.values.byName(platform.id),
          source,
        );
        written.addAll([for (final path in files) p.join(projectPath, path)]);
      } catch (e) {
        failures.add('${platform.label}: ${ReadableError.describe(e)}');
      }
      _update({...state}..remove(platform.id));
    }
    // The previews show files rewritten in place
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    await _reloadWritten(written);
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
