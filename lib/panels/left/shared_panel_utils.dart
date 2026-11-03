// ignore_for_file:  avoid_print, use_build_context_synchronously

import 'package:fide/models/file_system_item.dart';
import 'package:fide/models/project_node.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/git_repo_controller.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/desktop_shell.dart';
import 'package:fide/services/file_entry_service.dart';
import 'package:fide/services/git_service.dart';
import 'package:fide/widgets/icon_menu_item.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/no_project_placeholder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

part 'shared_panel_utils.file_operations.dart';
part 'shared_panel_utils.context_menu_handler.dart';
part 'shared_panel_utils.node_action.dart';
part 'shared_panel_utils.project_tree_panel_state.dart';
