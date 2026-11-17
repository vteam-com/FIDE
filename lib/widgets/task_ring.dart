import 'package:fide/widgets/inline_spinner.dart';
import 'package:material_ui/material_ui.dart';

/// The ring spinning around a task's glyph while the task runs: around a
/// `TaskButton`, and around a side panel tab's icon while the panel's work
/// runs.
///
/// Its slot keeps the ring's [size] whether it spins or not, so nothing
/// moves when it shows.
class TaskRing extends StatelessWidget {
  /// Creates the ring around [child], spinning while [spinning].
  const TaskRing({
    super.key,
    required this.size,
    required this.spinning,
    required this.child,
  });

  /// The glyph the ring surrounds, centered in it.
  final Widget child;

  /// Width and height of the ring and of its slot.
  final double size;

  /// Whether the ring shows and spins.
  final bool spinning;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (spinning) InlineSpinner(size: size),
          child,
        ],
      ),
    );
  }
}
