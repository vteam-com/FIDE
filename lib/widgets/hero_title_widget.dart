import 'package:fide/models/constants.dart';
import 'package:flutter/material.dart';

/// Represents `HeroTitleWidget`.
class HeroTitleWidget extends StatelessWidget {
  const HeroTitleWidget({
    super.key,
    required this.title,
    this.subTitle,
    this.subWidget,
  });

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
          child: Image.asset('assets/app.png'),
        ),

        Flexible(
          child: Text(
            title,
            style: Theme.of(context).textTheme.headlineLarge,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
