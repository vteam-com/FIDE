// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'badge_status.dart';

class PlatformInfoSection extends StatefulWidget {
  final String selectedPlatform;
  final bool isSupported;
  final bool canBuild;
  final String projectPath;
  final String currentHostPlatform;
  final void Function(String output)? onAppendOutput;
  final void Function(String error)? onAppendError;

  const PlatformInfoSection({
    super.key,
    required this.selectedPlatform,
    required this.isSupported,
    required this.canBuild,
    required this.projectPath,
    required this.currentHostPlatform,
    this.onAppendOutput,
    this.onAppendError,
  });

  @override
  State<PlatformInfoSection> createState() => _PlatformInfoSectionState();
}

class _PlatformInfoSectionState extends State<PlatformInfoSection> {
  String _getLastBuildTime() {
    final buildDir = Directory('${widget.projectPath}/build');
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
    final buildDir = Directory('${widget.projectPath}/build');
    if (!buildDir.existsSync()) return 'No build directory found';

    final platformSubdir =
        '${widget.projectPath}/build/${widget.selectedPlatform}';
    if (Directory(platformSubdir).existsSync()) {
      return platformSubdir;
    }

    var files = buildDir.listSync(recursive: false, followLinks: false);
    for (var file in files) {
      if (file.path.contains(widget.selectedPlatform) ||
          widget.selectedPlatform.contains(
            file.path.split('/').last.toLowerCase(),
          )) {
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

  void _openFolder(String path) {
    try {
      // For assets, we can't open in file explorer (they're packaged)
      if (path.startsWith('assets/')) {
        return;
      }

      // Get the directory containing the file
      final file = File(path);
      final directory = file.parent.path;

      // Cross-platform folder opening
      if (Platform.isMacOS) {
        Process.run('open', [directory]);
      } else if (Platform.isWindows) {
        Process.run('explorer', [directory]);
      } else if (Platform.isLinux) {
        Process.run('xdg-open', [directory]);
      }
    } catch (e) {
      // Ignore errors silently
    }
  }

  String _getEnableInstructions() {
    if (widget.isSupported) return 'Platform is already configured';

    switch (widget.selectedPlatform) {
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

  String? _findAppIconPath() {
    switch (widget.selectedPlatform) {
      case 'android':
        // Check for common Android icon paths
        final androidPaths = [
          '${widget.projectPath}/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
          '${widget.projectPath}/android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png',
          '${widget.projectPath}/android/app/src/main/res/mipmap-xhdpi/ic_launcher.png',
          '${widget.projectPath}/android/app/src/main/res/mipmap-hdpi/ic_launcher.png',
          '${widget.projectPath}/android/app/src/main/res/mipmap-mdpi/ic_launcher.png',
          '${widget.projectPath}/android/app/src/main/res/drawable/ic_launcher.png',
        ];
        for (final path in androidPaths) {
          if (File(path).existsSync()) return path;
        }
        break;

      case 'ios':
        // Check iOS icon paths (icon with the highest resolution)
        final iosPaths = [
          '${widget.projectPath}/ios/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png',
          '${widget.projectPath}/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
          '${widget.projectPath}/ios/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png',
          '${widget.projectPath}/ios/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png',
        ];
        for (final path in iosPaths) {
          if (File(path).existsSync()) return path;
        }
        break;

      case 'macos':
        // Check macOS icon paths from the actual project structure
        final macosPaths = [
          '${widget.projectPath}/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png',
          '${widget.projectPath}/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png',
          '${widget.projectPath}/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png',
          '${widget.projectPath}/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png',
        ];
        for (final path in macosPaths) {
          if (File(path).existsSync()) return path;
        }
        break;

      case 'windows':
        // Windows ICO file
        final windowsIcon =
            '${widget.projectPath}/windows/runner/resources/app_icon.ico';
        if (File(windowsIcon).existsSync()) return windowsIcon;
        break;

      case 'web':
        // Try common web favicon paths
        final webIcons = [
          '${widget.projectPath}/web/favicon.png',
          '${widget.projectPath}/web/icons/Icon-192.png',
          '${widget.projectPath}/web/icons/Icon-512.png',
        ];
        for (final path in webIcons) {
          if (File(path).existsSync()) return path;
        }
        break;

      case 'linux':
        // Linux typically doesn't have app icons in the project
        break;
    }

    return null; // No icon found
  }

  String _getPlatformIconPath() {
    final appIconPath = _findAppIconPath();
    if (appIconPath != null) {
      return appIconPath;
    }

    // Fallback to generic platform icons
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
      if (platform['id'] == widget.selectedPlatform) {
        return platform['asset'] as String;
      }
    }
    return 'assets/platform_linux.svg'; // fallback
  }

  Widget _buildIcon() {
    final iconPath = _getPlatformIconPath();
    if (iconPath.startsWith('assets/')) {
      // Use SVG asset
      return SvgPicture.asset(iconPath, width: 24, height: 24);
    } else {
      // Use actual app icon file
      return Image.file(
        File(iconPath),
        width: 24,
        height: 24,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // Fallback to generic SVG if image loading fails
          return SvgPicture.asset(
            'assets/platform_${widget.selectedPlatform}.svg',
            width: 24,
            height: 24,
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          Icon(
            widget.isSupported
                ? widget.canBuild
                      ? Icons.info_outline
                      : Icons.warning_amber_rounded
                : Icons.error_outline,
            size: 16,
            color: widget.isSupported
                ? widget.canBuild
                      ? Theme.of(context).colorScheme.primary
                      : Colors.orange
                : Theme.of(context).colorScheme.error,
          ),
          Expanded(
            child: Text(
              widget.selectedPlatform,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      initiallyExpanded: false,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Row
              Row(
                children: [
                  Text(
                    'Status:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    spacing: 8,
                    children: [
                      widget.isSupported
                          ? BadgeStatus.success(text: 'SUPPORTED')
                          : BadgeStatus.error(text: 'UNSUPPORTED'),

                      widget.canBuild
                          ? BadgeStatus.success(text: 'BUILDABLE')
                          : BadgeStatus.warning(text: 'UNBUILDABLE'),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // Build Info
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Build Info:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      SizedBox(
                        width: 70,
                        child: Text(
                          'Last Build:',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.8),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _getLastBuildTime(),
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      SizedBox(
                        width: 70,
                        child: Text(
                          'Size:',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.8),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _getAppSize(),
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 70,
                        child: Text(
                          'Location:',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.8),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _getBuildLocation().split('/').last,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Enable instructions (if not supported)
              if (!widget.isSupported) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          BadgeStatus(
                            text: 'ENABLE',
                            backgroundColor: Colors.blue.withOpacity(0.1),
                            textColor: Colors.blue.shade700,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Instructions for ${widget.selectedPlatform}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _getEnableInstructions(),
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Icon with Context Menu at Bottom
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    _buildIcon(),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getPlatformIconPath().split('/').last,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _getPlatformIconPath(),
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant.withOpacity(0.7),
                              fontFamily: 'monospace',
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      itemBuilder: (context) => [
                        PopupMenuItem<String>(
                          value: 'copy_path',
                          child: Row(
                            children: [
                              Icon(Icons.copy, size: 16),
                              const SizedBox(width: 8),
                              const Text('Copy Path'),
                            ],
                          ),
                        ),
                        if (!_getPlatformIconPath().startsWith('assets/'))
                          PopupMenuItem<String>(
                            value: 'open_finder',
                            child: Row(
                              children: [
                                Icon(Icons.folder_open, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  Platform.isMacOS
                                      ? 'Open in Finder'
                                      : Platform.isWindows
                                      ? 'Open in Explorer'
                                      : 'Open Folder',
                                ),
                              ],
                            ),
                          ),
                        PopupMenuItem<String>(
                          value: 'select_in_fide',
                          child: Row(
                            children: [
                              Icon(Icons.search, size: 16),
                              const SizedBox(width: 8),
                              const Text('Select in FIDE-Explorer'),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        switch (value) {
                          case 'copy_path':
                            Clipboard.setData(
                              ClipboardData(text: _getPlatformIconPath()),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Path copied to clipboard'),
                              ),
                            );
                            break;
                          case 'open_finder':
                            _openFolder(_getPlatformIconPath());
                            break;
                          case 'select_in_fide':
                            // Show a message for now since we don't have access to the explorer
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Select in FIDE-Explorer: ${_getPlatformIconPath()}',
                                ),
                              ),
                            );
                            break;
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
