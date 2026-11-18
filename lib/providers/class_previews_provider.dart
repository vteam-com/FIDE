import 'package:fide/models/preview_item.dart';
import 'package:fide/models/preview_scope.dart';
import 'package:fide/providers/preview_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One preview the Preview host renders: its place in the host's list and
/// what it is.
typedef IndexedPreview = ({int index, PreviewItem item});

/// The previews of the file at `path` that build the widget class
/// `className`, while the Preview controller renders that file's previews;
/// empty otherwise. Watching it starts the controller, which follows the
/// selected file and starts the host when that file has previews.
final classPreviewsProvider = Provider.autoDispose
    .family<List<IndexedPreview>, ({String path, String className})>((ref, of) {
      final state = ref.watch(previewControllerProvider);
      if (state.scope != PreviewScope.file || state.filePath != of.path) {
        return const [];
      }
      final labels = {
        for (final declaration in state.scan.previews)
          if (declaration.builds(of.className)) declaration.label,
      };
      return [
        for (final (index, item) in state.items.indexed)
          if (labels.contains(item.function)) (index: index, item: item),
      ];
    });
