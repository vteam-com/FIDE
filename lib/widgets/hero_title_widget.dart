import 'package:fide/constants/constants.dart';
import 'package:flutter/material.dart';

/// The large title of a screen or page: a [logo], the [title], and an
/// optional line under it.
class HeroTitleWidget extends StatelessWidget {
  /// Creates the title [title].
  const HeroTitleWidget({
    super.key,
    required this.title,
    this.subTitle,
    this.subWidget,
    this.logo,
  });

  /// Shown left of [title]; FIDE's own logo when null.
  final Widget? logo;

  /// Text line under [title]; none when null.
  final String? subTitle;

  /// Widget under [title], after [subTitle], such as a path; none when null.
  final Widget? subWidget;

  /// The headline.
  final String title;

  @override
  Widget build(BuildContext context) {
    final subTitle = this.subTitle;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.huge,
      children: [
        SizedBox(
          height: AppSize.heroLogoHeight,
          child: logo ?? Image.asset('assets/app.png'),
        ),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: AppSpacing.tiny,
            children: [
              Text(
                title,
                style: AppTextStyle.display,
                overflow: TextOverflow.ellipsis,
              ),
              if (subTitle != null)
                Text(subTitle, style: AppTextStyle.secondary(context)),
              ?subWidget,
            ],
          ),
        ),
      ],
    );
  }
}
