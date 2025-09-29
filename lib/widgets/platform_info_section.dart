// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class PlatformInfoSection extends StatelessWidget {
  final String selectedPlatform;
  final bool isSupported;
  final bool canBuild;
  final String projectPath;
  final String currentHostPlatform;

  const PlatformInfoSection({
    super.key,
    required this.selectedPlatform,
    required this.isSupported,
    required this.canBuild,
    required this.projectPath,
    required this.currentHostPlatform,
  });

  String _getLastBuildTime() {
    final buildDir = Directory('$projectPath/build');
    if (!buildDir.existsSync()) return 'Never';

    DateTime? latestTime;
    try {
      var files = buildDir.listSync(recursive: true);
      for (var file in files) {
        if (file.statSync().modified.isAfter(
          latestTime ?? DateTime.fromMillisecondsSinceEpoch(0),
        )) {
          latestTime = file.statSync().modified;
        }
      }
    } catch (e) {
      return 'Unknown';
    }

    return latestTime?.toString().split('.').first ?? 'Unknown';
  }

  String _getBuildLocation() {
    final buildDir = Directory('$projectPath/build');
    if (!buildDir.existsSync()) return 'No build directory found';

    final platformSubdir = '$projectPath/build/$selectedPlatform';
    if (Directory(platformSubdir).existsSync()) {
      return platformSubdir;
    }

    var files = buildDir.listSync(recursive: false, followLinks: false);
    for (var file in files) {
      if (file.path.contains(selectedPlatform) ||
          selectedPlatform.contains(file.path.split('/').last.toLowerCase())) {
        return file.path;
      }
    }

    return buildDir.path;
  }

  String _getAppSize() {
    final buildDir = Directory(_getBuildLocation());
    if (!buildDir.existsSync()) return 'Not built';

    try {
      var totalSize = 0;
      var files = buildDir.listSync(recursive: true);
      for (var file in files) {
        if (file is File) {
          totalSize += file.statSync().size;
        }
      }

      if (totalSize == 0) return '0 B';

      final units = ['B', 'KB', 'MB', 'GB'];
      var i = 0;
      var size = totalSize.toDouble();
      while (size > 1024 && i < units.length - 1) {
        size /= 1024;
        i++;
      }

      return '${size.toStringAsFixed(1)} ${units[i]}';
    } catch (e) {
      return 'Unknown';
    }
  }

  String _getEnableInstructions() {
    if (isSupported) return 'Platform is already configured';

    switch (selectedPlatform) {
      case 'android':
        return 'Android support is typically enabled by default.\nEnsure Android Studio or SDK is installed.';
      case 'ios':
        return 'iOS support requires macOS and Xcode.\nInstall Xcode from App Store.';
      case 'web':
        return 'Run: flutter config --enable-web';
      case 'windows':
        return 'Run: flutter config --enable-windows-desktop';
      case 'linux':
        return 'Run: flutter config --enable-linux-desktop';
      case 'macos':
        return 'Run: flutter config --enable-macos-desktop';
      default:
        return 'Platform not recognized';
    }
  }

  String _getFixInstructions() {
    if (isSupported && canBuild) return 'No issues detected';

    if (!isSupported) {
      return 'Enable the platform first using the instructions above.';
    }

    if (!canBuild) {
      switch (selectedPlatform) {
        case 'ios':
          return 'iOS builds require a macOS machine with Xcode installed.';
        case 'windows':
          return 'Windows builds require a Windows machine with Visual Studio.';
        case 'linux':
          return 'Linux builds require a Linux machine.';
        case 'macos':
          return 'macOS builds require a macOS machine with Xcode.';
        default:
          return 'Current host platform cannot build for this target.';
      }
    }

    return 'Check Flutter doctor and resolve any reported issues.';
  }

  String _getPlatformIconPath() {
    for (var platform in [
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
    ]) {
      if (platform['id'] == selectedPlatform) {
        return platform['asset'] as String;
      }
    }
    return 'assets/platform_linux.svg'; // fallback
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ExpansionTile(
        title: Row(
          children: [
            Icon(
              isSupported
                  ? canBuild
                        ? Icons.info_outline
                        : Icons.warning_amber_rounded
                  : Icons.error_outline,
              size: 16,
              color: isSupported
                  ? canBuild
                        ? Theme.of(context).colorScheme.primary
                        : Colors.orange
                  : Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 8),
            Text(
              selectedPlatform,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        initiallyExpanded: false,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Platform Icon Row
                Row(
                  children: [
                    Text(
                      'Icon: ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    SvgPicture.asset(
                      _getPlatformIconPath(),
                      width: 16,
                      height: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getPlatformIconPath(),
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withOpacity(0.8),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Status indicators
                Row(
                  children: [
                    Icon(
                      isSupported ? Icons.check_circle : Icons.cancel,
                      size: 14,
                      color: isSupported
                          ? Colors.green
                          : Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Supported: ${isSupported ? 'Yes' : 'No'}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      canBuild ? Icons.check_circle : Icons.cancel,
                      size: 14,
                      color: canBuild
                          ? Colors.green
                          : Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Can Build: ${canBuild ? 'Yes' : 'No'}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Build info
                Row(
                  children: [
                    Text(
                      'Last Build: ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      _getLastBuildTime(),
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                Row(
                  children: [
                    Text(
                      'Size: ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      _getAppSize(),
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Location
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Output Location:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getBuildLocation(),
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Enable instructions (if not supported)
                if (!isSupported) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.settings, size: 14, color: Colors.blue),
                          const SizedBox(width: 4),
                          const Text(
                            'To Enable:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getEnableInstructions(),
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ],

                // Fix instructions
                if (!canBuild || !isSupported) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.build, size: 14, color: Colors.orange),
                          const SizedBox(width: 4),
                          const Text(
                            'To Fix:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getFixInstructions(),
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
