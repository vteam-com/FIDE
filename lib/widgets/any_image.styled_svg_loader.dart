import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fide/services/svg_style_inliner.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Loads an SVG from a file or from bytes with its `<style>` sheet inlined
/// by [SvgStyleInliner], so shapes styled by class render in their colors
/// instead of black. Like `flutter_svg`'s own loaders, it reads and parses
/// the SVG in a background isolate.
class StyledSvgLoader extends SvgLoader<void> {
  /// Creates the loader of the SVG in [file].
  const StyledSvgLoader.file(File this.file) : bytes = null;

  /// Creates the loader of the UTF-8 encoded SVG [bytes].
  const StyledSvgLoader.memory(Uint8List this.bytes) : file = null;

  /// The SVG file; null when decoded from [bytes].
  final File? file;

  /// The UTF-8 encoded SVG; null when read from [file].
  final Uint8List? bytes;

  @override
  String provideSvg(void message) {
    final source = bytes ?? file!.readAsBytesSync();
    return SvgStyleInliner.inline(utf8.decode(source, allowMalformed: true));
  }

  @override
  int get hashCode => Object.hash(file, bytes, theme, colorMapper);

  @override
  bool operator ==(Object other) =>
      other is StyledSvgLoader &&
      other.file == file &&
      other.bytes == bytes &&
      other.theme == theme &&
      other.colorMapper == colorMapper;
}
