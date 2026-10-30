import 'package:fide/constants/constants.dart';
import 'package:flutter/material.dart';

/// Represents `HeroTitleWidget`.
class HeroTitleWidget extends StatelessWidget {
  const HeroTitleWidget({
    super.key,
    required this.title,
    this.subTitle,
    this.subWidget,
    this.logo,
  });

  /// Shown left of [title]; FIDE's own logo when null.
  final Widget? logo;

  final String? subTitle;

  final Widget? subWidget;

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.huge,
      children: [
        // App Logo
        SizedBox(
          height: AppSize.heroLogoHeight,
          child: logo ?? Image.asset('assets/app.png'),
        ),

        Flexible(
          child: Text(
            title,
            style: AppTextStyle.display,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
