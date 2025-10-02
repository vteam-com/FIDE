// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class PlatformSelector extends StatelessWidget {
  final Set<String> supportedPlatforms;
  final String selectedPlatform;
  final Function(String) onPlatformSelected;

  const PlatformSelector({
    super.key,
    required this.supportedPlatforms,
    required this.selectedPlatform,
    required this.onPlatformSelected,
  });

  @override
  Widget build(BuildContext context) {
    final platforms = [
      {
        'name': 'Android',
        'id': 'android',
        'asset': 'assets/platform_android.svg',
      },
      {'name': 'iOS', 'id': 'ios', 'asset': 'assets/platform_ios.svg'},
      {'name': 'Web', 'id': 'web', 'asset': 'assets/platform_web.svg'},
      {'name': 'macOS', 'id': 'macos', 'asset': 'assets/platform_macos.svg'},
      {'name': 'Linux', 'id': 'linux', 'asset': 'assets/platform_linux.svg'},
      {
        'name': 'Windows',
        'id': 'windows',
        'asset': 'assets/platform_windows.svg',
      },
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: platforms
              .map(
                (p) => Tooltip(
                  message: supportedPlatforms.contains(p['id'])
                      ? p['name'] as String
                      : '${p['name']} (not configured)',
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: selectedPlatform == p['id']
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: InkWell(
                      onTap: () => onPlatformSelected(p['id'] as String),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        child: ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            selectedPlatform == p['id']
                                ? Theme.of(context).colorScheme.primary
                                : supportedPlatforms.contains(p['id'])
                                ? Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.8)
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.3),
                            BlendMode.srcIn,
                          ),
                          child: SvgPicture.asset(
                            p['asset'] as String,
                            width: 21,
                            height: 21,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
