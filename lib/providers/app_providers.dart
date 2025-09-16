import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/file_system_item.dart';
import '../models/project_node.dart';

// State management for the selected file
final selectedFileProvider = StateProvider<FileSystemItem?>((ref) => null);

// State management for project loading
final projectLoadedProvider = StateProvider<bool>((ref) => false);

// State management for current project path
final currentProjectPathProvider = StateProvider<String?>((ref) => null);

// State management for current project root
final currentProjectRootProvider = StateProvider<ProjectNode?>((ref) => null);

// Theme mode provider
final themeModeProvider = StateProvider<ThemeMode>((ref) {
  // Try to get saved theme mode from shared preferences
  // For now, default to system
  return ThemeMode.system;
});
