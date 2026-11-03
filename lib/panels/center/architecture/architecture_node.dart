import 'package:fide/constants/constants.dart';
import 'package:fide/models/architecture_focus.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/panels/center/architecture/architecture_role_style.dart';
import 'package:fide/theme/app_theme.dart';
import 'package:fide/widgets/file_icon_utils.dart';
import 'package:fide/widgets/status_tone_style.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

/// One file of the architecture graph: its icon and name in a box outlined
/// in its [role]'s color, flagged when fCheck reports [issues] about it.
/// Pressing it selects it at once, pressing it again quickly opens it, and
/// hovering it focuses it.
class ArchitectureNode extends StatefulWidget {
  /// Creates the box of the file at [path].
  const ArchitectureNode({
    super.key,
    required this.path,
    required this.relativePath,
    required this.role,
    this.isSelected = false,
    this.isMatch = false,
    this.issues = const [],
    this.onHover,
    this.onSelect,
    this.onOpen,
  });

  /// Whether the file matches the filter, outlined to stand out.
  final bool isMatch;

  /// Whether the file is the selected one, filled and in bold.
  final bool isSelected;

  /// fCheck's layering findings about the file.
  final List<String> issues;

  /// Called with true when the pointer enters the box, false when it
  /// leaves.
  final ValueChanged<bool>? onHover;

  /// Opens the file in the editor.
  final VoidCallback? onOpen;

  /// Selects the file.
  final VoidCallback? onSelect;

  /// Absolute path of the file.
  final String path;

  /// [path] relative to the project, shown as the tooltip.
  final String relativePath;

  /// How the file relates to the focused one.
  final ArchitectureRole role;

  @override
  State<ArchitectureNode> createState() => _ArchitectureNodeState();
}

class _ArchitectureNodeState extends State<ArchitectureNode> {
  /// When the box was last pressed, to tell a double click; null before.
  DateTime? _lastTap;

  @override
  Widget build(BuildContext context) {
    final ArchitectureNode(
      :path,
      :relativePath,
      :role,
      :isSelected,
      :isMatch,
      :issues,
      :onHover,
    ) = widget;
    final theme = Theme.of(context);
    final isStrong = isSelected || role == ArchitectureRole.focused;
    final outline = isMatch && role == ArchitectureRole.plain
        ? ArchitectureRole.focused.color(theme)
        : role.color(theme);
    final warning = StatusTone.warning;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHover?.call(true),
      onExit: (_) => onHover?.call(false),
      child: GestureDetector(
        onTap: _onTap,
        child: Tooltip(
          message: [relativePath, ...issues].join('\n\n'),
          waitDuration: AppDuration.tooltipWait,
          child: Opacity(
            opacity: role == ArchitectureRole.dimmed ? AppOpacity.faint : 1,
            child: Container(
              padding: AppPadding.listItem,
              decoration: BoxDecoration(
                color: isStrong
                    ? AppTheme.selectedFill(context)
                    : theme.colorScheme.surface,
                border: Border.all(
                  color: outline,
                  width: role == ArchitectureRole.plain && !isMatch
                      ? AppSize.borderThin
                      : AppBorderWidth.medium,
                ),
                borderRadius: BorderRadius.circular(AppRadius.tiny),
              ),
              child: Row(
                spacing: AppSpacing.tiny,
                children: [
                  FileIconUtils.ofPath(path, size: AppIconSize.small),
                  Expanded(
                    child: Text(
                      p.basename(path),
                      style: isStrong
                          ? AppTextStyle.bodyStrong
                          : AppTextStyle.body,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  if (issues.isNotEmpty)
                    Icon(
                      warning.icon,
                      size: AppIconSize.small,
                      color: warning.color,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Selects the file, or opens it when pressed again within a double
  /// click; a double-tap recognizer would delay every selection instead.
  void _onTap() {
    final now = DateTime.now();
    final last = _lastTap;
    final isDoubleClick =
        last != null && now.difference(last) < kDoubleTapTimeout;
    _lastTap = isDoubleClick ? null : now;
    (isDoubleClick ? widget.onOpen : widget.onSelect)?.call();
  }
}
