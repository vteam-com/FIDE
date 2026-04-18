// ignore_for_file: deprecated_member_use
// ignore: fcheck_secrets
import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/badge_status.dart';
import 'package:fide/widgets/section_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Represents `PlatformInfoSection`.
class PlatformInfoSection extends StatefulWidget {
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

  final bool canBuild;

  final String currentHostPlatform;

  final bool isSupported;

  final void Function(String error)? onAppendError;

  final void Function(String output)? onAppendOutput;

  final String projectPath;

  final String selectedPlatform;

  @override
  State<PlatformInfoSection> createState() => _PlatformInfoSectionState();
}

class _PlatformInfoSectionState extends State<PlatformInfoSection> {
  @override
  Widget build(BuildContext context) {
    return SectionPanel(
      title: widget.selectedPlatform,
      rightWidget: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.medium,
        children: [
          Icon(
            widget.isSupported
                ? widget.canBuild
                      ? Icons.info_outline
                      : Icons.warning_amber_rounded
                : Icons.error_outline,
            size: AppIconSize.medium,
            color: widget.isSupported
                ? widget.canBuild
                      ? Theme.of(context).colorScheme.primary
                      : Colors.orange
                : Theme.of(context).colorScheme.error,
          ),
        ],
      ),
      child: Container(
        padding: AppPadding.actionTabDetails,
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceVariant.withValues(alpha: AppOpacity.divider),
          borderRadius: BorderRadius.circular(AppRadius.medium),
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
                    fontSize: AppFontSize.caption,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: AppSpacing.medium),
                Row(
                  spacing: AppSpacing.medium,
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

            const SizedBox(height: AppSpacing.small),

            // Build Info
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Build Info:',
                  style: TextStyle(
                    fontSize: AppFontSize.caption,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.tiny),
                Row(
                  children: [
                    SizedBox(
                      width: AppSize.platformDetailLabelWidth,
                      child: Text(
                        'Last Build:',
                        style: TextStyle(
                          fontSize: AppFontSize.metadata,
                          color: Theme.of(context).colorScheme.onSurface
                              .withValues(alpha: AppOpacity.emphasis),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _getLastBuildTime(),
                        style: TextStyle(
                          fontSize: AppFontSize.metadata,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.micro),
                Row(
                  children: [
                    SizedBox(
                      width: AppSize.platformDetailLabelWidth,
                      child: Text(
                        'Size:',
                        style: TextStyle(
                          fontSize: AppFontSize.metadata,
                          color: Theme.of(context).colorScheme.onSurface
                              .withValues(alpha: AppOpacity.emphasis),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _getAppSize(),
                        style: TextStyle(
                          fontSize: AppFontSize.metadata,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.micro),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: AppSize.platformDetailLabelWidth,
                      child: Text(
                        'Location:',
                        style: TextStyle(
                          fontSize: AppFontSize.metadata,
                          color: Theme.of(context).colorScheme.onSurface
                              .withValues(alpha: AppOpacity.emphasis),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _getBuildLocation().split('/').last,
                        style: TextStyle(
                          fontSize: AppFontSize.metadata,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
              const SizedBox(height: AppSpacing.medium),
              Container(
                padding: AppPadding.infoCard,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: AppOpacity.divider),
                    width: AppSize.borderThin,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        BadgeStatus(
                          text: 'ENABLE',
                          backgroundColor: Colors.blue.withValues(
                            alpha: AppOpacity.subtle,
                          ),
                          textColor: Colors.blue.shade700,
                          fontSize: AppFontSize.badge,
                          fontWeight: FontWeight.w600,
                        ),
                        const SizedBox(width: AppSpacing.medium),
                        Expanded(
                          child: Text(
                            'Instructions for ${widget.selectedPlatform}',
                            style: TextStyle(
                              fontSize: AppFontSize.caption,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.small),
                    Text(
                      _getEnableInstructions(),
                      style: TextStyle(
                        fontSize: AppFontSize.metadata,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: AppLineHeight.relaxed,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Icon with Context Menu at Bottom
            const SizedBox(height: AppSpacing.medium),
            Container(
              padding: AppPadding.infoCard,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.small),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: AppOpacity.divider),
                  width: AppBorderWidth.medium,
                ),
              ),
              child: Row(
                children: [
                  _buildIcon(),
                  const SizedBox(width: AppSpacing.medium),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getPlatformIconPath().split('/').last,
                          style: TextStyle(
                            fontSize: AppFontSize.metadata,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _getPlatformIconPath(),
                          style: TextStyle(
                            fontSize: AppFontSize.badge,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: AppOpacity.secondaryText),
                            fontFamily: 'monospace',
                          ),
                          maxLines: AppMetric.doubleLineLimit,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      size: AppIconSize.medium,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    itemBuilder: (_) => [
                      PopupMenuItem<String>(
                        value: 'copy_path',
                        child: Row(
                          children: [
                            Icon(Icons.copy, size: AppIconSize.medium),
                            const SizedBox(width: AppSpacing.medium),
                            const Text('Copy Path'),
                          ],
                        ),
                      ),
                      if (!_getPlatformIconPath().startsWith('assets/'))
                        PopupMenuItem<String>(
                          value: 'open_finder',
                          child: Row(
                            children: [
                              Icon(Icons.folder_open, size: AppIconSize.medium),
                              const SizedBox(width: AppSpacing.medium),
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
                            Icon(Icons.search, size: AppIconSize.medium),
                            const SizedBox(width: AppSpacing.medium),
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
    );
  }

  /// Returns the platform icon widget — either an SVG asset or a Material icon fallback.
  Widget _buildIcon() {
    final iconPath = _getPlatformIconPath();
    if (iconPath.startsWith('assets/')) {
      // Use SVG asset
      return SvgPicture.asset(
        iconPath,
        width: AppIconSize.xLarge,
        height: AppIconSize.xLarge,
      );
    } else {
      // Use actual app icon file
      return Image.file(
        File(iconPath),
        width: AppIconSize.xLarge,
        height: AppIconSize.xLarge,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) {
          // Fallback to generic SVG if image loading fails
          return SvgPicture.asset(
            'assets/platform_${widget.selectedPlatform}.svg',
            width: AppIconSize.xLarge,
            height: AppIconSize.xLarge,
          );
        },
      );
    }
  }

  /// Searches the project directory for the platform app icon and returns its path, or `null` if not found.
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

  /// Calculates and returns the human-readable total build output size.
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
      while (size > AppMetric.fileSizeDivisor && i < units.length - 1) {
        size /= AppMetric.fileSizeDivisor;
        i++;
      }

      return '${size.toStringAsFixed(1)} ${units[i]}';
    } catch (_) {
      return 'Unknown';
    }
  }

  /// Returns the filesystem path to the platform's build output directory.
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

  /// Returns human-readable instructions for enabling this platform in the project.
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

  /// Returns a formatted string of the most recent build timestamp, or 'Never' if no build exists.
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
    } catch (_) {
      return 'Unknown';
    }

    return latestTime?.toString().split('.').first ?? 'Unknown';
  }

  /// Resolves the best available icon path for the current platform, falling back to a generic asset.
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

  /// Opens the folder containing [path] in the system file manager.
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
    } catch (_) {
      // Ignore errors silently
    }
  }
}
