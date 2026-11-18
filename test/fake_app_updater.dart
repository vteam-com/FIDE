import 'package:fide/models/app_release.dart';
import 'package:fide/services/app_updater.dart';
import 'package:fide/services/process_runner.dart';
import 'package:http/http.dart' as http;
import 'package:pub_semver/pub_semver.dart';

/// An [AppUpdater] whose latest release the test sets, logging what it
/// does to [log] instead of reaching GitHub.
class FakeAppUpdater extends LinuxAppUpdater {
  /// Creates an updater logging to [log], with no release out yet.
  FakeAppUpdater(this.log)
    : super(
        http.Client(),
        const ProcessRunner(),
        executable: '/opt/fide/bundle/fide',
        processId: 1,
      );

  /// What the updater did, in order: `check`, then `stage <version>`.
  final List<String> log;

  /// What [latestRelease] answers.
  AppRelease? latest;

  /// What [latestRelease] and [stage] throw, when set.
  Object? failure;

  @override
  Future<AppRelease?> latestRelease() async {
    log.add('check');
    if (failure case final failure?) throw failure;
    return latest;
  }

  @override
  Future<void> stage(AppRelease release) async {
    if (failure case final failure?) throw failure;
    log.add('stage ${release.version}');
  }
}

/// Release [version], downloading from anywhere.
AppRelease releaseOf(String version) => AppRelease(
  version: Version.parse(version),
  downloadUrl: Uri.parse('https://example.com/$version'),
);
