part of 'app_updater.dart';

/// The macOS [AppUpdater]: the build is the `.app` bundle, zipped with
/// `ditto`; the replacer swaps the whole bundle, so no file of the old
/// version breaks the new one's signature, and opens it.
class MacAppUpdater extends AppUpdater {
  /// Creates the updater of the bundle holding [executable].
  const MacAppUpdater(
    super.client,
    super.runner, {
    required super.executable,
    required super.processId,
  });

  @override
  String get assetName => '${AppName.short}-macos.zip';

  /// The `.app` bundle holding [executable], in its `Contents/MacOS`.
  @override
  String get installPath => p.dirname(p.dirname(p.dirname(executable)));

  /// The folder holding the bundle, where the replacer renames it.
  @override
  String get writtenFolder => p.dirname(installPath);

  @override
  String appIn(String unpacked) => p.join(unpacked, '${AppName.short}.app');

  /// Moves the installed bundle into the staging folder, which the script
  /// deletes, then the new one into its place; puts the installed one
  /// back when that fails.
  @override
  Future<void> startReplacer(String newApp, String staging) =>
      _startShellReplacer(
        r'mv "$3" "$4/previous" && { mv "$2" "$3" || mv "$4/previous" "$3"; }',
        newApp,
        staging,
        ['open', installPath],
      );

  @override
  Future<void> unpack(String archive, String into) =>
      runner.runChecked('ditto', ['-x', '-k', archive, into]);
}
