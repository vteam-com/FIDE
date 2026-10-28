// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/build_artifacts.dart';
import 'package:fide/models/flutter_platform.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/widgets/badge_status.dart';
import 'package:fide/widgets/section_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Represents `PlatformInfoSection`.
class PlatformInfoSection extends ConsumerStatefulWidget {
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
  ConsumerState<PlatformInfoSection> createState() =>
      _PlatformInfoSectionState();
}

class _PlatformInfoSectionState extends ConsumerState<PlatformInfoSection> {
  BuildArtifacts _artifacts = BuildArtifacts.pending;

  @override
  void initState() {
    super.initState();
    _inspectArtifacts();
  }

  @override
  void didUpdateWidget(PlatformInfoSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectPath != widget.projectPath ||
        oldWidget.selectedPlatform != widget.selectedPlatform) {
      _inspectArtifacts();
    }
  }

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
          color: Theme.of(context).colorScheme.surfaceVariant
              .withValues(alpha: AppOpacity.divider),
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
                        _artifacts.lastBuildTime,
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
                        _artifacts.size,
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
                        _artifacts.location.split('/').last,
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
                  color: Theme.of(context).colorScheme.outline
                      .withValues(alpha: AppOpacity.divider),
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
                          _iconPath.split('/').last,
                          style: TextStyle(
                            fontSize: AppFontSize.metadata,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _iconPath,
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
                      if (!_iconPath.startsWith('assets/'))
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
                          Clipboard.setData(ClipboardData(text: _iconPath));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Path copied to clipboard'),
                            ),
                          );
                          break;
                        case 'open_finder':
                          _openFolder(_iconPath);
                          break;
                        case 'select_in_fide':
                          // Show a message for now since we don't have access to the explorer
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Select in FIDE-Explorer: $_iconPath',
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
    final iconPath = _iconPath;
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
            _genericIconPath,
            width: AppIconSize.xLarge,
            height: AppIconSize.xLarge,
          );
        },
      );
    }
  }

  /// Bundled icon for the selected platform, or Linux's for an unknown id.
  String get _genericIconPath {
    return (FlutterPlatform.fromId(widget.selectedPlatform) ??
            FlutterPlatform.linux)
        .iconAsset;
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

  /// The project's app icon, or the bundled one for the platform.
  String get _iconPath => _artifacts.appIconPath ?? _genericIconPath;

  /// Reads the build output off the UI thread's critical path; results for
  /// a platform the user has since switched away from are dropped.
  Future<void> _inspectArtifacts() async {
    final platform = widget.selectedPlatform;
    final artifacts = await ref
        .read(buildArtifactsInspectorProvider)
        .inspect(widget.projectPath, platform);
    if (mounted && platform == widget.selectedPlatform) {
      setState(() => _artifacts = artifacts);
    }
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

      ref.read(processRunnerProvider).revealInFileManager(directory);
    } catch (_) {
      // Ignore errors silently
    }
  }
}
