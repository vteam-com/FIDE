import 'package:fide/widgets/compact_icon_button.dart';
import 'package:material_ui/material_ui.dart';

/// A [CompactIconButton] flipping a setting: in the primary color while
/// [isOn], its tooltip saying whether it is on.
class CompactToggleButton extends StatelessWidget {
  /// Creates the toggle of [tooltip]'s setting, showing [icon].
  const CompactToggleButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.isOn,
    required this.onChanged,
  });

  /// The glyph shown.
  final IconData icon;

  /// Whether the setting is on.
  final bool isOn;

  /// Called with the setting's new value on tap.
  final ValueChanged<bool> onChanged;

  /// Hover text naming the setting.
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return CompactIconButton(
      icon: icon,
      selected: isOn,
      tooltip: '$tooltip (${isOn ? 'ON' : 'OFF'})',
      onPressed: () => onChanged(!isOn),
    );
  }
}
