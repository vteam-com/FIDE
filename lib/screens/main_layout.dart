// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/document_state.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/panels/center/center_panel.dart';
import 'package:fide/panels/center/editor/editor_screen.dart';
import 'package:fide/panels/left/left_panel.dart';
import 'package:fide/panels/right/right_panel.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/providers/file_type_utils.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/resizable_splitter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:highlight/highlight.dart';
import 'package:highlight/languages/dart.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:highlight/languages/json.dart';
import 'package:highlight/languages/plaintext.dart';
import 'package:highlight/languages/yaml.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

part 'main_layout.state.dart';

/// Represents `MainLayout`.
class MainLayout extends ConsumerStatefulWidget {
  final Function(ThemeMode)? onThemeChanged;
  final Function(String)? onFileOpened;

  const MainLayout({super.key, this.onThemeChanged, this.onFileOpened});

  @override
  ConsumerState<MainLayout> createState() => MainLayoutState();
}
