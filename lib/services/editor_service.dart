import 'package:flutter_riverpod/flutter_riverpod.dart';

class EditorService extends StateNotifier<String?> {
  EditorService() : super(null);

  void openFile(String path) {
    state = path;
  }

  void closeFile() {
    state = null;
  }
  
  void updateCurrentPath(String newPath) {
    if (state != null) {
      state = newPath;
    }
  }
}

final editorServiceProvider = StateNotifierProvider<EditorService, String?>(
  (ref) => EditorService(),
);
