import 'dart:convert';
import 'dart:io';

import 'package:fide/models/app_release.dart';
import 'package:fide/services/app_updater.dart';
import 'package:fide/services/process_runner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

/// Records the commands run and started instead of running them; a run
/// command calls [onRun], as unpacking would create the build's files.
class _RecordingRunner extends ProcessRunner {
  _RecordingRunner({this.onRun});

  final void Function(List<String> command)? onRun;
  final List<List<String>> ran = [];
  final List<List<String>> started = [];
  final List<ProcessStartMode> modes = [];

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool runInShell = false,
  }) async {
    final command = [executable, ...arguments];
    ran.add(command);
    onRun?.call(command);
    return ProcessResult(0, 0, '', '');
  }

  @override
  Future<Process> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool runInShell = false,
    ProcessStartMode mode = ProcessStartMode.normal,
  }) async {
    started.add([executable, ...arguments]);
    modes.add(mode);
    return Process.start('true', const []);
  }
}

/// The release 2.0.0 whose build downloads from [_downloadUrl].
final AppRelease _release = AppRelease(
  version: Version(2, 0, 0),
  downloadUrl: _downloadUrl,
);

final Uri _downloadUrl = Uri.parse(
  'https://github.com/vteam-com/FIDE/releases/download/v2.0.0/build',
);

/// A client serving the build at [_downloadUrl], and nothing else.
final MockClient _buildServer = MockClient(
  (request) async => request.url == _downloadUrl
      ? http.Response('archive', HttpStatus.ok)
      : http.Response('', HttpStatus.notFound, reasonPhrase: 'Not Found'),
);

/// The temporary folders [AppUpdater.stage] downloads into.
Set<String> _stagingFolders() => {
  for (final entry in Directory.systemTemp.listSync())
    if (p.basename(entry.path).startsWith('fide_update_')) entry.path,
};

/// The id of a process that has ended.
Future<int> _endedProcessId() async {
  final process = await Process.start('true', const []);
  await process.exitCode;
  return process.pid;
}

/// Runs, for real, the shell replacer [command] that [_RecordingRunner]
/// recorded, its relaunch replaced by touching [marker].
Future<void> _runReplacer(List<String> command, String marker) async {
  // sh -c script sh pid newApp installPath staging relaunch...
  const relaunchStart = 8;
  final result = await Process.run('sh', [
    ...command.sublist(1, relaunchStart),
    'touch',
    marker,
  ]);
  expect(result.exitCode, 0, reason: '${result.stderr}');
}

void main() {
  late Directory temp;

  setUp(() async => temp = await Directory.systemTemp.createTemp('updater'));
  tearDown(() => temp.delete(recursive: true));

  /// Writes [content] to [path] under [temp], creating its folders.
  String write(String path, String content) {
    final file = File(p.join(temp.path, path))
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
    return file.path;
  }

  /// The text of [path] under [temp].
  String read(String path) => File(p.join(temp.path, path)).readAsStringSync();

  group('per operating system', () {
    AppUpdater updater(String operatingSystem, String executable) =>
        AppUpdater.forOperatingSystem(
          operatingSystem,
          _buildServer,
          _RecordingRunner(),
          executable: executable,
          processId: 1,
        );

    test('macOS replaces the whole app bundle', () {
      final mac = updater(
        'macos',
        '/Applications/FIDE.app/Contents/MacOS/FIDE',
      );

      expect(mac, isA<MacAppUpdater>());
      expect(mac.assetName, 'FIDE-macos.zip');
      expect(mac.installPath, '/Applications/FIDE.app');
      expect(mac.writtenFolder, '/Applications');
      expect(mac.appIn('/tmp/u'), '/tmp/u/FIDE.app');
    });

    test('Linux and other Unixes update the bundle folder', () {
      for (final os in ['linux', 'freebsd']) {
        final linux = updater(os, '/opt/fide/bundle/fide');

        expect(linux, isA<LinuxAppUpdater>());
        expect(linux.assetName, 'FIDE-linux.tar.gz');
        expect(linux.installPath, '/opt/fide/bundle');
        expect(linux.writtenFolder, '/opt/fide/bundle');
        expect(linux.appIn('/tmp/u'), '/tmp/u/bundle');
      }
    });

    test('Windows updates the folder of the executable', () {
      final windows = updater('windows', '/apps/FIDE/fide.exe');

      expect(windows, isA<WindowsAppUpdater>());
      expect(windows.assetName, 'FIDE-windows.zip');
      expect(windows.installPath, '/apps/FIDE');
      expect(windows.appIn('/tmp/u'), '/tmp/u');
    });
  });

  group('latestRelease', () {
    AppUpdater updater(http.Client client) => AppUpdater.forOperatingSystem(
      'linux',
      client,
      _RecordingRunner(),
      executable: '/opt/fide/bundle/fide',
      processId: 1,
    );

    test('reads the latest release from GitHub', () async {
      final client = MockClient((request) async {
        expect(request.url, AppUpdater.latestReleaseUrl);
        return http.Response(
          jsonEncode({
            'tag_name': 'v1.4.0',
            'assets': [
              {
                'name': 'FIDE-linux.tar.gz',
                'browser_download_url': 'https://example.com/linux',
              },
            ],
          }),
          HttpStatus.ok,
        );
      });

      final release = await updater(client).latestRelease();

      expect(release?.version, Version(1, 4, 0));
      expect(release?.downloadUrl, Uri.parse('https://example.com/linux'));
    });

    test('throws when GitHub answers with an error', () async {
      final client = MockClient(
        (_) async => http.Response(
          '',
          HttpStatus.forbidden,
          reasonPhrase: 'rate limit exceeded',
        ),
      );

      await expectLater(
        updater(client).latestRelease(),
        throwsA(
          isA<HttpException>().having(
            (error) => error.message,
            'message',
            'api.github.com answered 403 rate limit exceeded',
          ),
        ),
      );
    });
  });

  group('stage', () {
    late String executable;
    late _RecordingRunner runner;

    setUp(() {
      executable = write('install/bundle/fide', 'old');
      // Unpacking creates the bundle folder the Linux build holds
      runner = _RecordingRunner(
        onRun: (command) =>
            Directory(p.join(command.last, 'bundle')).createSync(),
      );
    });

    LinuxAppUpdater updater({http.Client? client, ProcessRunner? using}) =>
        LinuxAppUpdater(
          client ?? _buildServer,
          using ?? runner,
          executable: executable,
          processId: 42,
        );

    test('downloads and unpacks the build, then starts the replacer', () async {
      await updater().stage(_release);

      final unpack = runner.ran.single;
      final staging = p.dirname(unpack.last);
      // Deletes only the staging folder the replacer would have deleted
      expect(p.basename(staging), startsWith('fide_update_'));
      addTearDown(() => Directory(staging).delete(recursive: true));
      expect(unpack, [
        'tar',
        '-xzf',
        p.join(staging, 'FIDE-linux.tar.gz'),
        '-C',
        p.join(staging, 'unpacked'),
      ]);
      expect(File(unpack[2]).readAsStringSync(), 'archive');
      final replacer = runner.started.single;
      expect(replacer.take(2), ['sh', '-c']);
      expect(replacer.skip(3), [
        'sh',
        '42',
        p.join(staging, 'unpacked', 'bundle'),
        p.dirname(executable),
        staging,
        executable,
      ]);
      expect(runner.modes.single, ProcessStartMode.detached);
    });

    test('a failed download leaves nothing behind', () async {
      final before = _stagingFolders();
      final failing = MockClient(
        (_) async => http.Response('', HttpStatus.notFound),
      );

      await expectLater(
        updater(client: failing).stage(_release),
        throwsA(isA<HttpException>()),
      );

      expect(runner.ran, isEmpty);
      expect(runner.started, isEmpty);
      expect(_stagingFolders(), before);
    });

    test('a build without the app starts no replacer', () async {
      final before = _stagingFolders();

      await expectLater(
        updater(using: _RecordingRunner()).stage(_release),
        throwsA(isA<StateError>()),
      );

      expect(_stagingFolders(), before);
    });

    test('an install FIDE cannot write in downloads nothing', () async {
      final install = p.dirname(executable);
      await Process.run('chmod', ['555', install]);
      addTearDown(() => Process.run('chmod', ['755', install]));
      var requests = 0;
      final counting = MockClient((_) async {
        requests++;
        return http.Response('', HttpStatus.ok);
      });

      await expectLater(
        updater(client: counting).stage(_release),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains("can't write in $install"),
          ),
        ),
      );

      expect(requests, 0);
    }, skip: Platform.isWindows ? 'chmod is POSIX' : null);
  });

  group('the shell replacer, run', () {
    late String marker;

    setUp(() => marker = p.join(temp.path, 'relaunched'));

    test('macOS swaps the bundle once FIDE has ended, then opens it', () async {
      write('Applications/FIDE.app/version', 'old');
      write('staging/unpacked/FIDE.app/version', 'new');
      final runner = _RecordingRunner();
      final mac = MacAppUpdater(
        _buildServer,
        runner,
        executable: p.join(
          temp.path,
          'Applications/FIDE.app/Contents/MacOS/FIDE',
        ),
        processId: await _endedProcessId(),
      );

      await mac.startReplacer(
        p.join(temp.path, 'staging/unpacked/FIDE.app'),
        p.join(temp.path, 'staging'),
      );
      expect(runner.started.single.skip(8), ['open', mac.installPath]);
      await _runReplacer(runner.started.single, marker);

      expect(read('Applications/FIDE.app/version'), 'new');
      expect(Directory(p.join(temp.path, 'staging')).existsSync(), isFalse);
      expect(File(marker).existsSync(), isTrue);
    }, skip: Platform.isWindows ? 'sh is POSIX' : null);

    test(
      'macOS keeps the installed bundle when the new one cannot move in',
      () async {
        write('Applications/FIDE.app/version', 'old');
        write('staging/archive', '');
        final runner = _RecordingRunner();
        final mac = MacAppUpdater(
          _buildServer,
          runner,
          executable: p.join(
            temp.path,
            'Applications/FIDE.app/Contents/MacOS/FIDE',
          ),
          processId: await _endedProcessId(),
        );

        await mac.startReplacer(
          p.join(temp.path, 'staging/unpacked/FIDE.app'),
          p.join(temp.path, 'staging'),
        );
        await _runReplacer(runner.started.single, marker);

        expect(read('Applications/FIDE.app/version'), 'old');
        expect(File(marker).existsSync(), isTrue);
      },
      skip: Platform.isWindows ? 'sh is POSIX' : null,
    );

    test('Linux waits for FIDE to end, copies the build over the bundle and '
        'starts it', () async {
      write('bundle/fide', 'old');
      write('bundle/notes.txt', 'mine');
      write('staging/unpacked/bundle/fide', 'new');
      write('staging/unpacked/bundle/lib/libapp.so', 'new');
      final fide = await Process.start('sleep', ['1']);
      final runner = _RecordingRunner();
      final linux = LinuxAppUpdater(
        _buildServer,
        runner,
        executable: p.join(temp.path, 'bundle/fide'),
        processId: fide.pid,
      );

      await linux.startReplacer(
        p.join(temp.path, 'staging/unpacked/bundle'),
        p.join(temp.path, 'staging'),
      );
      expect(runner.started.single.skip(8), [linux.executable]);
      await _runReplacer(runner.started.single, marker);

      expect(await fide.exitCode, 0, reason: 'replaced once FIDE ended');
      expect(read('bundle/fide'), 'new');
      expect(read('bundle/lib/libapp.so'), 'new');
      expect(read('bundle/notes.txt'), 'mine');
      expect(Directory(p.join(temp.path, 'staging')).existsSync(), isFalse);
      expect(File(marker).existsSync(), isTrue);
    }, skip: Platform.isWindows ? 'sh is POSIX' : null);
  });

  test('Windows unpacks and replaces with PowerShell', () async {
    final runner = _RecordingRunner();
    final windows = WindowsAppUpdater(
      _buildServer,
      runner,
      executable: "/Users/o'neil/FIDE/fide.exe",
      processId: 7,
    );

    await windows.unpack('/Temp/u/FIDE-windows.zip', '/Temp/u/unpacked');
    await windows.startReplacer('/Temp/u/unpacked', '/Temp/u');

    expect(runner.ran.single, [
      'powershell',
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      "Expand-Archive -LiteralPath '/Temp/u/FIDE-windows.zip' "
          "-DestinationPath '/Temp/u/unpacked' -Force",
    ]);
    expect(runner.started.single.take(4), [
      'powershell',
      '-NoProfile',
      '-NonInteractive',
      '-Command',
    ]);
    expect(
      runner.started.single.last,
      [
        'Wait-Process -Id 7 -ErrorAction SilentlyContinue',
        "robocopy '/Temp/u/unpacked' '/Users/o''neil/FIDE' /E /R:10 /W:1 "
            '| Out-Null',
        "Remove-Item -LiteralPath '/Temp/u' -Recurse -Force",
        "Start-Process -FilePath '/Users/o''neil/FIDE/fide.exe'",
      ].join('; '),
    );
    expect(runner.modes.single, ProcessStartMode.detached);
  });
}
