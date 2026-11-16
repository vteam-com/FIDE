import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/header_bar.dart';
import 'package:material_ui/material_ui.dart';

/// The strip atop a file viewer (an image, a sound, an image diff): its
/// [leading] controls at the start and its [trailing] ones, such as the
/// zoom and the file's facts, at the end; in a narrow editor the trailing
/// group, then each group's own items, wrap onto further lines.
class ViewerToolbar extends StatelessWidget {
  /// Creates the strip of [leading] then [trailing] items.
  const ViewerToolbar({
    super.key,
    required this.leading,
    this.trailing = const [],
  });

  /// Items at the start of the strip.
  final List<Widget> leading;

  /// Items at the end of the strip.
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    return HeaderBar(
      child: _wrap(
        alignment: WrapAlignment.spaceBetween,
        children: [
          _wrap(children: leading),
          _wrap(children: trailing),
        ],
      ),
    );
  }

  /// [children] in a row, [alignment] along it, wrapping when narrow.
  Widget _wrap({
    WrapAlignment alignment = WrapAlignment.start,
    required List<Widget> children,
  }) {
    return Wrap(
      alignment: alignment,
      spacing: AppSpacing.medium,
      runSpacing: AppSpacing.small,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}
