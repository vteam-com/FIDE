part of 'app_icon_fixer.dart';

/// Writes the launcher icon of each density, pointing `android:icon` at
/// it when it names none or a drawable.
class AndroidIconWriter extends PlatformIconWriter {
  /// Creates a stateless writer.
  const AndroidIconWriter();

  @override
  void write(IconWriter writer) {
    const manifestPath = AppIconChecker.androidManifestPath;
    final manifest = writer.read(manifestPath);
    if (manifest == null) {
      throw const AppIconFixException(
        'Missing $manifestPath; recreate the platform with '
        '"flutter create --platforms=android ."',
      );
    }
    final icon = AppIconChecker.androidIcon(manifest);
    var name = icon?.name ?? AppIconChecker.androidDefaultIconName;
    if (icon?.type != 'mipmap') {
      name = AppIconChecker.androidDefaultIconName;
      final reference = 'android:icon="@mipmap/$name"';
      writer.text(
        manifestPath,
        icon == null
            ? manifest.replaceFirst(
                RegExp(r'<application\b'),
                '<application\n        $reference',
              )
            : manifest.replaceFirst(
                RegExp(r'android:icon="@drawable/[\w.]+"'),
                reference,
              ),
      );
    }
    for (final MapEntry(key: folder, value: size)
        in AppIconChecker.androidDensitySizes.entries) {
      writer.png('${AppIconChecker.androidResPath}/$folder/$name.png', size);
    }
  }
}
