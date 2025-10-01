// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
  bool _isRunningPodUpdate = false;

  Future<void> _runPodUpdate() async {
    setState(() {
      _isRunningPodUpdate = true;
    });
    widget.onAppendOutput!(
      '[CocoaPods] Running pod install --repo-update... This may take several minutes.\n',
    );
    try {
      final process = await Process.start(
        'pod',
        ['install', '--repo-update'],
        workingDirectory: '${widget.projectPath}/macos',
        runInShell: true,
      );
      final stdoutLines = process.stdout
          .transform(SystemEncoding().decoder)
          .transform(const LineSplitter());
      final stderrLines = process.stderr
          .transform(SystemEncoding().decoder)
          .transform(const LineSplitter());
      final stdoutSub = stdoutLines.listen((line) {
        widget.onAppendOutput?.call('$line\n');
      });
      final stderrSub = stderrLines.listen((line) {
        widget.onAppendError?.call('$line\n');
      });
      final exitCode = await process.exitCode;
      await stdoutSub.cancel();
      await stderrSub.cancel();
      if (exitCode == 0) {
        widget.onAppendOutput!(
          '[CocoaPods] pod install --repo-update complete! Try building again.\n',
        );
      } else {
        widget.onAppendError!(
          '[CocoaPods] pod install --repo-update failed (exit code $exitCode).\n',
        );
      }
    } catch (e) {
      widget.onAppendError!('[CocoaPods] Error: $e\n');
    } finally {
      setState(() {
        _isRunningPodUpdate = false;
      });
    }
  }

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

  String _getFixInstructions() {
    // Always check for macOS CocoaPods issues when macOS is selected
    if (widget.selectedPlatform == 'macos' && Platform.isMacOS) {
      final cocoaPodsIssue = _checkMacOSCocoaPodsIssue();
      if (cocoaPodsIssue != null) {
        return cocoaPodsIssue;
      }
      // Even if no issues detected, always provide helpful macOS commands
      return 'macOS builds: Consider periodic CocoaPods updates\nRun: pod repo update (may take several minutes)\n\nFor build issues: rm -rf build/macos/Pods && flutter clean';
    }

    if (widget.isSupported && widget.canBuild) {
      return 'No issues detected';
    }

    if (!widget.isSupported) {
      return 'Enable the platform first using the instructions above.';
    }

    if (!widget.canBuild) {
      switch (widget.selectedPlatform) {
        case 'ios':
          return 'iOS builds require a macOS machine with Xcode installed.';
        case 'windows':
          return 'Windows builds require a Windows machine with Visual Studio.';
        case 'linux':
          return 'Linux builds require a Linux machine.';
        default:
          return 'Current host platform cannot build for this target.';
      }
    }

    return 'Check Flutter doctor and resolve any reported issues.';
  }

  String? _checkMacOSCocoaPodsIssue() {
    try {
      // Check if CocoaPods is available
      final podVersion = Process.runSync('pod', ['--version']);
      if (podVersion.exitCode != 0) {
        return 'CocoaPods is not installed. Install with: brew install cocoapods\nThen run: pod setup';
      }

      // Check if pod repo update is needed by looking at the last update time
      final repoDir = Directory(
        '${Platform.environment['HOME']}/Library/Caches/CocoaPods/Pods',
      );
      if (repoDir.existsSync()) {
        final entries = repoDir.listSync(recursive: false);
        if (entries.isNotEmpty) {
          final latestEntry = entries
              .map((e) => e.statSync().modified)
              .reduce((a, b) => a.isAfter(b) ? a : b);

          final daysSinceUpdate = DateTime.now().difference(latestEntry).inDays;
          if (daysSinceUpdate > 30) {
            return 'CocoaPods repository may be out of date.\nRun: pod repo update\n\nThis may take several minutes.';
          }
        }
      }

      // Check for common Flutter macOS build errors
      final buildDir = Directory('${widget.projectPath}/build');
      if (buildDir.existsSync()) {
        final recentErrors = _checkRecentBuildErrors();
        if (recentErrors.contains('CocoaPods')) {
          return 'Recent build had CocoaPods issues.\nTry: pod repo update\n\nOr clean and rebuild.';
        }
      }
    } catch (e) {
      // If we can't check, don't show anything
    }

    return null;
  }

  String _checkRecentBuildErrors() {
    try {
      final logFiles = Directory('${widget.projectPath}/build/macos')
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (file) => file.path.endsWith('.log') || file.path.contains('error'),
          )
          .toList();

      for (final file in logFiles) {
        final content = file.readAsStringSync();
        if (content.contains('CocoaPods') ||
            content.contains('pod repo update')) {
          return 'CocoaPods';
        }
      }
    } catch (e) {
      // Ignore errors
    }
    return '';
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ExpansionTile(
        title: Row(
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(width: 8),
            Flexible(
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
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: SingleChildScrollView(
              child: Container(
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
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        _buildIcon(),
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
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.isSupported
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              size: 14,
                              color: widget.isSupported
                                  ? Colors.green
                                  : Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Supported: ${widget.isSupported ? 'Yes' : 'No'}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.canBuild
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              size: 14,
                              color: widget.canBuild
                                  ? Colors.green
                                  : Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Can Build: ${widget.canBuild ? 'Yes' : 'No'}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
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
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
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
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
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
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Enable instructions (if not supported)
                    if (!widget.isSupported) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.settings,
                                size: 14,
                                color: Colors.blue,
                              ),
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
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ],

                    // Fix instructions
                    if (!widget.canBuild ||
                        !widget.isSupported ||
                        (widget.selectedPlatform == 'macos' &&
                            Platform.isMacOS)) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Flexible(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.build,
                                  size: 14,
                                  color: Colors.orange,
                                ),
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
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getFixInstructions(),
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontFamily: 'monospace',
                            ),
                          ),
                          if (widget.selectedPlatform == 'macos' &&
                              Platform.isMacOS) ...[
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: _isRunningPodUpdate
                                  ? null
                                  : _runPodUpdate,
                              icon: Icon(Icons.system_update, size: 14),
                              label: Text(
                                _isRunningPodUpdate
                                    ? 'Updating...'
                                    : 'Update CocoaPods',
                              ),
                              style: ButtonStyle(
                                minimumSize: MaterialStateProperty.all(
                                  const Size(120, 32),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
