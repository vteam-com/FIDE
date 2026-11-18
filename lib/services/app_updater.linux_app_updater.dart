part of 'app_updater.dart';

/// The Linux [AppUpdater]: the build is the `bundle` folder, in a
/// `tar.gz`; the replacer copies its files over the installed ones,
/// leaving any other file of their folder alone, and starts [executable].
class LinuxAppUpdater extends AppUpdater {
  /// Creates the updater of the bundle holding [executable].
  const LinuxAppUpdater(
    super.client,
    super.runner, {
    required super.executable,
    required super.processId,
  });

  @override
  String get assetName => '${AppName.short}-linux.tar.gz';

  /// The bundle folder holding [executable].
  @override
  String get installPath => p.dirname(executable);

  @override
  String appIn(String unpacked) => p.join(unpacked, 'bundle');

  @override
  Future<void> startReplacer(String newApp, String staging) =>
      _startShellReplacer(r'cp -Rf "$2/." "$3/"', newApp, staging, [
        executable,
      ]);

  @override
  Future<void> unpack(String archive, String into) =>
      runner.runChecked('tar', ['-xzf', archive, '-C', into]);
}
