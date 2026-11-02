// ignore_for_file: use_build_context_synchronously

import 'package:fide/constants/constants.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/panels/center/center_panel.dart';
import 'package:fide/panels/left/left_panel.dart';
import 'package:fide/panels/right/right_panel.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/editor_navigation.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/widgets/panel_island.dart';
import 'package:fide/widgets/resizable_splitter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

part 'main_layout.state.dart';

/// Represents `MainLayout`.
class MainLayout extends ConsumerStatefulWidget {
  /// Creates the layout.
  const MainLayout({super.key});

  @override
  ConsumerState<MainLayout> createState() => MainLayoutState();
}
