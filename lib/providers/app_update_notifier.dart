import 'dart:async';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/app_release.dart';
import 'package:fide/providers/open_documents_notifier.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:pub_semver/pub_semver.dart';

/// The FIDE release newer than the one running, or null while FIDE is up
/// to date or can't update itself; checked when first read, at launch,
/// then every [AppDuration.updateCheckInterval]. Kept for the app. A
/// failed check waits for the next one rather than retrying, which would
/// spend GitHub's limit on requests.
final appUpdateProvider = AsyncNotifierProvider<AppUpdateNotifier, AppRelease?>(
  AppUpdateNotifier.new,
  retry: (_, _) => null,
);

/// Whether the newer release downloads and unpacks, until FIDE quits to
/// update. Kept apart from [appUpdateProvider] so watching it, as the
/// update button's ring does, never checks for updates.
final appUpdateInstallingProvider = StateProvider<bool>((_ /*ref*/) => false);

/// Checks GitHub for a FIDE release newer than the running one, and
/// installs it.
class AppUpdateNotifier extends AsyncNotifier<AppRelease?> {
  @override
  Future<AppRelease?> build() async {
    final updater = ref.watch(appUpdaterProvider);
    if (updater == null) return null;
    // Checks again later, whether this check succeeds or not
    final nextCheck = Timer(
      AppDuration.updateCheckInterval,
      ref.invalidateSelf,
    );
    ref.onDispose(nextCheck.cancel);
    final running = Version.parse(await ref.watch(appVersionProvider.future));
    final latest = await updater.latestRelease();
    return latest != null && latest.version > running ? latest : null;
  }

  /// Checks for a newer release again, keeping the one found meanwhile.
  void check() => ref.invalidateSelf();

  /// Downloads and unpacks the newer release, saves the open documents,
  /// then quits FIDE, as its Quit does, for the release to take its place
  /// and start; shown running through [appUpdateInstallingProvider]. Does
  /// nothing without a newer release, or while it installs.
  ///
  /// Throws when the release can't be downloaded or unpacked, FIDE then
  /// running on unchanged; or when a document can't be saved, FIDE then
  /// updating once it quits.
  Future<void> install() async {
    final release = state.value;
    final updater = ref.read(appUpdaterProvider);
    final installing = ref.read(appUpdateInstallingProvider.notifier);
    if (release == null || updater == null || installing.state) return;

    installing.state = true;
    try {
      await updater.stage(release);
      await ref.read(openDocumentsProvider.notifier).saveAll();
      await ref.read(quitAppProvider)();
    } finally {
      installing.state = false;
    }
  }
}
