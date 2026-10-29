// ignore_for_file: use_build_context_synchronously

import 'package:fide/constants/constants.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/panels/center/center_panel.dart';
import 'package:fide/panels/left/left_panel.dart';
import 'package:fide/panels/right/right_panel.dart';
import 'package:fide/providers/active_editor.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/editor_navigation.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/widgets/panel_island.dart';
import 'package:fide/widgets/resizable_splitter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

part 'main_layout.state.dart';

/// Represents `MainLayout`.
class MainLayout extends ConsumerStatefulWidget {
  /// Loads a project folder through the app's loading flow.
  final Future<bool> Function(String directoryPath) onOpenProject;

  /// Picks a folder and loads it as a project.
  final VoidCallback onOpenFolder;

  final Function(String)? onFileOpened;

  const MainLayout({
    super.key,
    required this.onOpenProject,
    required this.onOpenFolder,
    this.onFileOpened,
  });

  @override
  ConsumerState<MainLayout> createState() => MainLayoutState();
}
