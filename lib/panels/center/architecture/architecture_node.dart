import 'package:fide/constants/constants.dart';
import 'package:fide/models/architecture_focus.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/panels/center/architecture/architecture_role_style.dart';
import 'package:fide/widgets/file_icon_utils.dart';
import 'package:fide/widgets/outlined_surface.dart';
import 'package:fide/widgets/status_indicator.dart';
import 'package:fide/widgets/surface_padding.dart';
import 'package:fide/widgets/tree_row.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

/// One file of the architecture graph: its [TreeRow], as the file lists
/// show it, in an [OutlinedSurface] outlined in its [role]'s color, flagged
/// when fCheck reports [issues] about it.
/// Pressing it selects it at once, pressing it again quickly opens it, and
/// hovering it focuses it.
class ArchitectureNode extends StatefulWidget {
  /// Creates the box of the file at [path].
  const ArchitectureNode({
    super.key,
    required this.path,
    required this.rootPath,
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

  /// How the file relates to the focused one.
  final ArchitectureRole role;

  /// The project folder; the tooltip shows [path] relative to it.
  final String rootPath;

  @override
  State<ArchitectureNode> createState() => _ArchitectureNodeState();
}

class _ArchitectureNodeState extends State<ArchitectureNode> {
  /// When the box was last pressed, to tell a double click; null before.
  DateTime? _lastTap;

  @override
  Widget build(BuildContext context) {
    final ArchitectureNode(:path, :rootPath, :role, :isSelected, :issues) =
        widget;
    final isPlain =
        role == ArchitectureRole.plain || role == ArchitectureRole.dimmed;
    final highlight = !isPlain
        ? role.color(Theme.of(context))
        : widget.isMatch && role == ArchitectureRole.plain
        ? ArchitectureRole.focused.color(Theme.of(context))
        : null;
    return MouseRegion(
      onEnter: (_) => widget.onHover?.call(true),
      onExit: (_) => widget.onHover?.call(false),
      child: Opacity(
        opacity: role == ArchitectureRole.dimmed ? AppOpacity.faint : 1,
        child: OutlinedSurface(
          padding: SurfacePadding.none,
          highlight: highlight,
          child: TreeRow(
            icon: FileIconUtils.ofPath(path),
            name: p.basename(path),
            path: path,
            rootPath: rootPath,
            note: issues.isEmpty ? null : issues.join('\n\n'),
            highlighted: isSelected || role == ArchitectureRole.focused,
            onTap: _onTap,
            trailing: [
              if (issues.isNotEmpty) StatusIndicator.tone(StatusTone.warning),
            ],
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
