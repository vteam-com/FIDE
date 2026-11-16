import 'package:material_ui/material_ui.dart';

/// [child] showing [message] on hover, or [child] alone when [message] is
/// null, for widgets whose hover text is optional.
class OptionalTooltip extends StatelessWidget {
  /// Creates the tooltip of [message] around [child].
  const OptionalTooltip({
    super.key,
    required this.message,
    required this.child,
  });

  /// The widget hovered.
  final Widget child;

  /// The hover text; no tooltip when null.
  final String? message;

  @override
  Widget build(BuildContext context) {
    final message = this.message;
    return message == null ? child : Tooltip(message: message, child: child);
  }
}
