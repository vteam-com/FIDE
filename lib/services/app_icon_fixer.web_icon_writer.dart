part of 'app_icon_fixer.dart';

/// Writes the favicon, linking it when the page links none, and every
/// manifest icon, adding the sizes browsers need.
class WebIconWriter extends PlatformIconWriter {
  /// Creates a stateless writer.
  const WebIconWriter();

  /// Size of the favicon written.
  static const int _faviconSize = 32;

  /// Favicon linked from a page that links none.
  static const String _defaultFavicon = 'favicon.png';

  @override
  void write(IconWriter writer) {
    final index = writer.read(AppIconChecker.webIndexPath);
    final href = index == null ? null : AppIconChecker.faviconHref(index);
    if (index != null && href == null) {
      writer.text(
        AppIconChecker.webIndexPath,
        index.replaceFirst(
          '</head>',
          '  <link rel="icon" type="image/png" href="$_defaultFavicon"/>\n'
              '</head>',
        ),
      );
    }
    final faviconPath = AppIconChecker.webPath(href ?? _defaultFavicon);
    if (faviconPath != null) writer.png(faviconPath, _faviconSize);

    const manifestPath = AppIconChecker.webManifestPath;
    final hasManifest = writer.read(manifestPath) != null;
    final manifest = writer.readJson(manifestPath);
    if (hasManifest && manifest == null) {
      throw const AppIconFixException(
        '$manifestPath is not valid JSON; fix it, then try again',
      );
    }
    final contents = manifest ?? <String, Object?>{};
    final icons = contents['icons'] is List
        ? contents['icons']! as List
        : (contents['icons'] = <Object?>[]) as List;
    final sizes = <int>{};
    for (final icon in icons.whereType<Map>()) {
      final size = AppIconChecker.squareSize(icon['sizes'])?.round();
      final path = icon['src'] is String
          ? AppIconChecker.webPath(icon['src'] as String)
          : null;
      if (size == null || path == null) continue;
      sizes.add(size);
      writer.png(path, size);
    }
    final missing = AppIconChecker.webRequiredSizes.difference(sizes);
    for (final size in missing) {
      final src = 'icons/Icon-$size.png';
      icons.add({'src': src, 'sizes': '${size}x$size', 'type': 'image/png'});
      writer.png(AppIconChecker.webPath(src)!, size);
    }
    if (!hasManifest || missing.isNotEmpty) writer.json(manifestPath, contents);
  }
}
