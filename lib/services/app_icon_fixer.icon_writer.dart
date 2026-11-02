part of 'app_icon_fixer.dart';

/// Writes icons resized from a master image, and text files, into a
/// project, recording what it wrote.
class _IconWriter {
  _IconWriter._(this.root, this._master);

  /// Reads the master at [masterPath] for the project at [root], cropped
  /// to a centered square.
  factory _IconWriter.load(String root, String masterPath) {
    final img.Image? master;
    try {
      master = img.decodeImage(File(masterPath).readAsBytesSync());
    } on FileSystemException catch (e) {
      throw AppIconFixException('Cannot read $masterPath: ${e.message}');
    }
    if (master == null) {
      throw AppIconFixException('$masterPath is not an image FIDE can read');
    }
    final side = master.width < master.height ? master.width : master.height;
    return _IconWriter._(
      root,
      img.copyCrop(
        master,
        x: (master.width - side) ~/ _sides,
        y: (master.height - side) ~/ _sides,
        width: side,
        height: side,
      ),
    );
  }

  /// Splits the master's extra width or height evenly on both sides.
  static const int _sides = 2;

  /// Project root path.
  final String root;

  /// The square master image.
  final img.Image _master;

  /// Project-relative paths written, in order.
  final List<String> written = [];

  /// The master at [size] pixels, flattened onto white when [opaque].
  img.Image _resized(int size, {bool opaque = false}) {
    final resized = img.copyResize(
      _master,
      width: size,
      height: size,
      interpolation: size < _master.width
          ? img.Interpolation.average
          : img.Interpolation.cubic,
    );
    if (!opaque) return resized;
    const white = AppMetric.colorChannelMax;
    final background = img.Image(width: size, height: size)
      ..clear(img.ColorRgb8(white, white, white));
    return img.compositeImage(background, resized);
  }

  /// Writes the master as a [size]-pixel PNG at project-relative [path],
  /// without alpha channel when [opaque].
  void png(String path, int size, {bool opaque = false}) {
    _bytes(path, img.encodePng(_resized(size, opaque: opaque)));
  }

  /// Writes the master as an ICO holding [sizes] at project-relative
  /// [path].
  void ico(String path, Iterable<int> sizes) {
    _bytes(
      path,
      img.IcoEncoder().encodeImages([
        for (final size in sizes.toList()..sort()) _resized(size),
      ]),
    );
  }

  /// Writes [content] at project-relative [path].
  void text(String path, String content) {
    _file(path).writeAsStringSync(content);
    written.add(path);
  }

  /// Writes [content] as indented JSON at project-relative [path].
  void json(String path, Map<String, Object?> content) {
    text(path, '${const JsonEncoder.withIndent('  ').convert(content)}\n');
  }

  /// The text of project-relative [path], or null when it can't be read.
  String? read(String path) {
    final file = File(p.join(root, path));
    return file.existsSync() ? file.readAsStringSync() : null;
  }

  /// The JSON object at project-relative [path]; null when it is missing
  /// or not a JSON object.
  Map<String, Object?>? readJson(String path) {
    final content = read(path);
    if (content == null) return null;
    try {
      final json = jsonDecode(content);
      return json is Map<String, Object?> ? json : null;
    } on FormatException {
      return null;
    }
  }

  void _bytes(String path, List<int> bytes) {
    _file(path).writeAsBytesSync(bytes);
    written.add(path);
  }

  /// The file at project-relative [path], its folder created.
  File _file(String path) =>
      File(p.join(root, path))..parent.createSync(recursive: true);
}
