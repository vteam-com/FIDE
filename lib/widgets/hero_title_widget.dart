import 'package:flutter/material.dart';

class HeroTitleWidget extends StatelessWidget {
  final String title;
  final String? subTitle;
  final Widget? subWidget;

  const HeroTitleWidget({
    super.key,
    required this.title,
    this.subTitle,
    this.subWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      spacing: 32,
      children: [
        // App Logo
        SizedBox(height: 100, child: Image.asset('assets/app.png')),

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
