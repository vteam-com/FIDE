import 'dart:typed_data';

import 'package:fide/providers/service_providers.dart';
import 'package:fide/widgets/empty_state.dart';
import 'package:fide/widgets/image_diff.dart';
import 'package:fide/widgets/loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The editor's diff view of an image: its committed version against its
/// working copy.
class EditorScreenImageDiffView extends ConsumerStatefulWidget {
  /// Creates the diff view of the image at [filePath].
  const EditorScreenImageDiffView({super.key, required this.filePath});

  /// The image compared.
  final String filePath;

  @override
  ConsumerState<EditorScreenImageDiffView> createState() =>
      _EditorScreenImageDiffViewState();
}

class _EditorScreenImageDiffViewState
    extends ConsumerState<EditorScreenImageDiffView> {
  /// The committed and working copies of the image, read once per file.
  late Future<({Uint8List? oldBytes, Uint8List newBytes})> _versions;

  @override
  void initState() {
    super.initState();
    _versions = _read();
  }

  @override
  void didUpdateWidget(EditorScreenImageDiffView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) _versions = _read();
  }

  /// Reads both versions of the image.
  Future<({Uint8List? oldBytes, Uint8List newBytes})> _read() async {
    final path = widget.filePath;
    return (
      oldBytes: await ref.read(gitServiceProvider).getBytesAt(path),
      newBytes: await ref.read(fileContentReaderProvider).readBytes(path),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _versions,
      builder: (_, snapshot) {
        final versions = snapshot.data;
        if (snapshot.hasError) {
          return EmptyState.error(
            message: 'Error getting diff: ${snapshot.error}',
          );
        }
        if (versions == null) return const LoadingIndicator();
        return ImageDiff(
          path: widget.filePath,
          oldBytes: versions.oldBytes,
          newBytes: versions.newBytes,
        );
      },
    );
  }
}
