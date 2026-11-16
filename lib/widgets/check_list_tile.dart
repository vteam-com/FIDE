import 'package:material_ui/material_ui.dart';

/// A dense list row with its checkbox first, such as a language to support
/// or a string a fix should take.
///
/// The one checkbox row of the app.
class CheckListTile extends StatelessWidget {
  /// Creates the row for [title], checked when [value].
  const CheckListTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.trailing,
  });

  /// Called with the new check state; the row is disabled when null.
  final ValueChanged<bool>? onChanged;

  /// Shown under [title]; none when null.
  final Widget? subtitle;

  /// The row's main text.
  final Widget title;

  /// Shown at the end of the row, such as a button; none when null.
  final Widget? trailing;

  /// Whether the box is checked.
  final bool value;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return CheckboxListTile(
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      value: value,
      onChanged: onChanged == null
          ? null
          : (checked) => onChanged(checked ?? false),
      title: title,
      subtitle: subtitle,
      secondary: trailing,
    );
  }
}
