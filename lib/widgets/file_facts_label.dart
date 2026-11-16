import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/byte_size.dart';
import 'package:fide/services/file_type_utils.dart';
import 'package:material_ui/material_ui.dart';

/// A viewer toolbar's caption about the file it shows: [facts] such as a
/// sound's sample rate, then the file's size on disk and its format.
class FileFactsLabel extends StatefulWidget {
  /// Creates the caption of [filePath].
  const FileFactsLabel({
    super.key,
    required this.filePath,
    this.facts = const [],
  });

  /// What the viewer knows of the file's content, shown first.
  final List<String> facts;

  /// The file described.
  final String filePath;

  @override
  State<FileFactsLabel> createState() => _FileFactsLabelState();
}

class _FileFactsLabelState extends State<FileFactsLabel> {
  /// Size of [FileFactsLabel.filePath] on disk, read once per file.
  late Future<int> _fileLength;

  @override
  void initState() {
    super.initState();
    _fileLength = File(widget.filePath).length();
  }

  @override
  void didUpdateWidget(FileFactsLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _fileLength = File(widget.filePath).length();
    }
  }

  @override
  Widget build(BuildContext context) {
    final extension = FileTypeUtils.extensionOf(widget.filePath);
    return FutureBuilder<int>(
      future: _fileLength,
      builder: (context, snapshot) => Text(
        [
          ...widget.facts,
          ?snapshot.data?.readableSize,
          extension.toUpperCase(),
        ].join(' • '),
        style: AppTextStyle.secondary(context),
      ),
    );
  }
}
