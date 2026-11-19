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
  }) : _isHeader = false;

  /// Creates the toggle for the strip atop a panel, as large as the
  /// [CompactIconButton.header]s beside it.
  const CompactToggleButton.header({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.isOn,
    required this.onChanged,
  }) : _isHeader = true;

  /// Whether the toggle sits in the strip atop a panel.
  final bool _isHeader;

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
    final tooltip = '${this.tooltip} (${isOn ? 'ON' : 'OFF'})';
    void onPressed() => onChanged(!isOn);
    return _isHeader
        ? CompactIconButton.header(
            icon: icon,
            selected: isOn,
            tooltip: tooltip,
            onPressed: onPressed,
          )
        : CompactIconButton(
            icon: icon,
            selected: isOn,
            tooltip: tooltip,
            onPressed: onPressed,
          );
  }
}
