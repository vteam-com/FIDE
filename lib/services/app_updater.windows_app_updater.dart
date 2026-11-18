part of 'app_updater.dart';

/// The Windows [AppUpdater]: the build is the files of the folder holding
/// the executable, zipped; PowerShell unpacks it, and its replacer, once
/// FIDE has quit and freed its files, copies them over the installed ones
/// with `robocopy`, leaving any other file of their folder alone, and
/// starts [executable].
class WindowsAppUpdater extends AppUpdater {
  /// Creates the updater of the folder holding [executable].
  const WindowsAppUpdater(
    super.client,
    super.runner, {
    required super.executable,
    required super.processId,
  });

  @override
  String get assetName => '${AppName.short}-windows.zip';

  /// The folder holding [executable].
  @override
  String get installPath => p.dirname(executable);

  /// The build's files are at the archive's root.
  @override
  String appIn(String unpacked) => unpacked;

  /// `robocopy` retries a file still locked as FIDE exits.
  @override
  Future<void> startReplacer(String newApp, String staging) async {
    final quoted = ProcessRunner.powerShellLiteral;
    await runner.start(
      'powershell',
      ProcessRunner.powerShellArguments(
        [
          'Wait-Process -Id $processId -ErrorAction SilentlyContinue',
          'robocopy ${quoted(newApp)} ${quoted(installPath)} /E /R:10 /W:1 '
              '| Out-Null',
          'Remove-Item -LiteralPath ${quoted(staging)} -Recurse -Force',
          'Start-Process -FilePath ${quoted(executable)}',
        ].join('; '),
      ),
      mode: ProcessStartMode.detached,
    );
  }

  @override
  Future<void> unpack(String archive, String into) => runner.runChecked(
    'powershell',
    ProcessRunner.powerShellArguments(
      'Expand-Archive -LiteralPath ${ProcessRunner.powerShellLiteral(archive)} '
      '-DestinationPath ${ProcessRunner.powerShellLiteral(into)} -Force',
    ),
  );
}
