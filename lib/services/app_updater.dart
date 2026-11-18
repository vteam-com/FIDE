import 'dart:convert';
import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/app_release.dart';
import 'package:fide/models/flutter_platform.dart';
import 'package:fide/services/process_runner.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

part 'app_updater.linux_app_updater.dart';
part 'app_updater.mac_app_updater.dart';
part 'app_updater.windows_app_updater.dart';

/// Keeps FIDE up to date: finds its latest release on GitHub, downloads the
/// build of the operating system it runs on, and puts it in the running
/// app's place.
///
/// FIDE can't replace itself while it runs: [stage] starts a replacer,
/// detached so it outlives FIDE, which waits for FIDE to quit, puts the
/// new build in its place and starts it.
///
/// One implementation per operating system, as the Release workflow
/// packages each build its own way; [AppUpdater.forOperatingSystem] picks
/// it.
abstract class AppUpdater {
  /// Creates the updater of the app run from [executable] as process
  /// [processId], downloading with [client] and running its commands with
  /// [runner].
  const AppUpdater(
    this.client,
    this.runner, {
    required this.executable,
    required this.processId,
  });

  /// The updater of [operatingSystem], as [Platform.operatingSystem] names
  /// it; other Unix desktops get the one of Linux.
  factory AppUpdater.forOperatingSystem(
    String operatingSystem,
    http.Client client,
    ProcessRunner runner, {
    required String executable,
    required int processId,
  }) => switch (FlutterPlatform.fromId(operatingSystem)) {
    FlutterPlatform.macos => MacAppUpdater(
      client,
      runner,
      executable: executable,
      processId: processId,
    ),
    FlutterPlatform.windows => WindowsAppUpdater(
      client,
      runner,
      executable: executable,
      processId: processId,
    ),
    _ => LinuxAppUpdater(
      client,
      runner,
      executable: executable,
      processId: processId,
    ),
  };

  /// Where GitHub's API describes FIDE's latest release.
  static final Uri latestReleaseUrl = Uri.https(
    'api.github.com',
    '/repos/${AppName.repository}/releases/latest',
  );

  /// Prefix of the temporary folder a build is downloaded and unpacked in.
  static const String _stagingPrefix = 'fide_update_';

  /// The folder of the staging folder the build unpacks into, apart from
  /// its archive.
  static const String _unpackedFolder = 'unpacked';

  /// The file [stage] writes, then deletes, to find out whether FIDE can
  /// write in [writtenFolder].
  static const String _writeProbe = '.fide_update_probe';

  /// Downloads the release's description and its build.
  final http.Client client;

  /// The running app's executable, as [Platform.resolvedExecutable] names
  /// it.
  final String executable;

  /// The running app's process id: the replacer waits for it to end.
  final int processId;

  /// Runs the commands unpacking the build and replacing the app.
  final ProcessRunner runner;

  /// Name of this operating system's build among a release's files, as
  /// the Release workflow names it.
  String get assetName;

  /// The installed app an update replaces.
  String get installPath;

  /// The folder the replacer writes in, which FIDE must be able to write:
  /// [installPath] itself, unless the replacer swaps it whole.
  String get writtenFolder => installPath;

  /// The new app in [unpacked], the folder its build unpacked into.
  String appIn(String unpacked);

  /// The latest release, or null when it has no build of this operating
  /// system; throws when GitHub can't be reached or answers with an error.
  Future<AppRelease?> latestRelease() async {
    final response = await client.get(latestReleaseUrl);
    _checkAnswered(response, latestReleaseUrl);
    return AppRelease.fromGitHub(jsonDecode(response.body), assetName);
  }

  /// Downloads [release]'s build into a staging folder, unpacks it, then
  /// starts the replacer; FIDE must quit for the replacer to go on.
  ///
  /// Throws, leaving nothing behind, when FIDE can't write in
  /// [writtenFolder] or a step fails.
  Future<void> stage(AppRelease release) async {
    await _checkWritable();
    final staging = await Directory.systemTemp.createTemp(_stagingPrefix);
    try {
      final archive = p.join(staging.path, assetName);
      await _download(release.downloadUrl, archive);
      final unpacked = p.join(staging.path, _unpackedFolder);
      await Directory(unpacked).create();
      await unpack(archive, unpacked);
      final newApp = appIn(unpacked);
      if (!await FileSystemEntity.isDirectory(newApp)) {
        throw StateError(
          '$assetName of ${release.version} holds no ${p.basename(newApp)}',
        );
      }
      await startReplacer(newApp, staging.path);
    } catch (_) {
      await staging.delete(recursive: true);
      rethrow;
    }
  }

  /// Starts the replacer, detached: once FIDE has quit, it puts [newApp]
  /// in place of [installPath], deletes the [staging] folder holding the
  /// download, then starts the new app.
  Future<void> startReplacer(String newApp, String staging);

  /// Unpacks the build [archive] into the folder [into].
  Future<void> unpack(String archive, String into);

  /// Throws when FIDE can't write in [writtenFolder], such as a folder of
  /// another user or a read-only disk.
  Future<void> _checkWritable() async {
    final probe = File(p.join(writtenFolder, _writeProbe));
    try {
      await probe.writeAsString('');
      await probe.delete();
    } on FileSystemException {
      throw StateError(
        "${AppName.short} can't write in $writtenFolder: move "
        '${AppName.short} to a folder you can write in, then update again',
      );
    }
  }

  /// Downloads [url] into the file [path].
  Future<void> _download(Uri url, String path) async {
    final response = await client.send(http.Request('GET', url));
    if (response.statusCode != HttpStatus.ok) {
      await response.stream.drain<void>();
    }
    _checkAnswered(response, url);
    await response.stream.pipe(File(path).openWrite());
  }

  /// Starts the replacer of macOS and Linux, a shell script: once FIDE
  /// has quit, [replace] puts the new app (`$2`) in place of the installed
  /// one (`$3`); the script then deletes the staging folder (`$4`) and
  /// runs [relaunch].
  Future<void> _startShellReplacer(
    String replace,
    String newApp,
    String staging,
    List<String> relaunch,
  ) async {
    final script = [
      r'while kill -0 "$1" 2>/dev/null; do sleep 1; done',
      replace,
      r'rm -rf "$4"',
      'shift 4',
      r'exec "$@"',
    ].join('\n');
    await runner.start('sh', [
      '-c',
      script,
      'sh',
      '$processId',
      newApp,
      installPath,
      staging,
      ...relaunch,
    ], mode: ProcessStartMode.detached);
  }

  /// Throws when [response], from [url], is no success.
  static void _checkAnswered(http.BaseResponse response, Uri url) {
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        '${url.host} answered ${response.statusCode} '
                '${response.reasonPhrase ?? ''}'
            .trim(),
        uri: url,
      );
    }
  }
}
