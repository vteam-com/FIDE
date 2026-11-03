import 'package:fide/models/architecture_focus.dart';
import 'package:flutter/material.dart';

/// How an [ArchitectureRole] looks, giving a file's box and the imports
/// drawn to it the same color.
extension ArchitectureRoleStyle on ArchitectureRole {
  /// The color of a file's outline and of its imports in this role: the
  /// primary color for the focused file and what it imports, the tertiary
  /// one for what imports it, and the divider color otherwise.
  Color color(ThemeData theme) => switch (this) {
    ArchitectureRole.focused ||
    ArchitectureRole.callee => theme.colorScheme.primary,
    ArchitectureRole.caller => theme.colorScheme.tertiary,
    ArchitectureRole.plain || ArchitectureRole.dimmed => theme.dividerColor,
  };
}
