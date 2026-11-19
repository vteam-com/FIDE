import 'package:fide/constants/constants.dart';
import 'package:fide/theme/app_theme.dart';
import 'package:fide/widgets/section_title.dart';
import 'package:material_ui/material_ui.dart';

/// A wizard step's header: its number in a circle, its title, and a rule
/// to the edge.
class StepHeader extends StatelessWidget {
  /// Creates the header of step [number], titled [title].
  const StepHeader({super.key, required this.number, required this.title});

  /// 1-based step number.
  final int number;

  /// Step title.
  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: AppIconSize.xLarge,
          height: AppIconSize.xLarge,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.primary,
          ),
          child: Center(
            child: Text(
              '$number',
              style: AppTextStyle.bodyStrong.copyWith(
                color: AppTheme.onFill(colorScheme.primary),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.medium),
        SectionTitle(title),
        const SizedBox(width: AppSpacing.xLarge),
        const Expanded(child: Divider()),
      ],
    );
  }
}
