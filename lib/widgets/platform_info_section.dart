// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/build_artifacts.dart';
import 'package:fide/models/flutter_platform.dart';
import 'package:fide/providers/process_runner.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/widgets/badge_status.dart';
import 'package:fide/widgets/icon_menu_row.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/section_panel.dart';
import 'package:fide/widgets/outlined_surface.dart';
import 'package:flutter/material.dart';
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
    this.onAppendOutput,
    this.onAppendError,
  });

  final bool canBuild;

  final bool isSupported;

  final void Function(String error)? onAppendError;

  final void Function(String output)? onAppendOutput;

  final String projectPath;

  final FlutterPlatform selectedPlatform;

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
      title: widget.selectedPlatform.displayName,
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
                _buildHeading('Status:'),
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
                _buildHeading('Build Info:'),
                const SizedBox(height: AppSpacing.tiny),
                _buildDetailRow('Last Build:', _artifacts.lastBuildTime),
                const SizedBox(height: AppSpacing.micro),
                _buildDetailRow('Size:', _artifacts.size),
                const SizedBox(height: AppSpacing.micro),
                _buildDetailRow(
                  'Location:',
                  _artifacts.location.split('/').last,
                ),
              ],
            ),

            // Enable instructions (if not supported)
            if (!widget.isSupported) ...[
              const SizedBox(height: AppSpacing.medium),
              OutlinedSurface(
                padding: AppPadding.infoCard,
                borderColor: Colors.blue.withValues(alpha: AppOpacity.divider),
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
                            'Instructions for ${widget.selectedPlatform.displayName}',
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
            OutlinedSurface(
              padding: AppPadding.infoCard,
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
                          style: AppTextStyle.monospace.copyWith(
                            fontSize: AppFontSize.badge,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: AppOpacity.secondaryText),
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
                        child: IconMenuRow(
                          icon: Icons.copy,
                          label: 'Copy Path',
                        ),
                      ),
                      if (!_iconPath.startsWith('assets/'))
                        PopupMenuItem<String>(
                          value: 'open_finder',
                          child: IconMenuRow(
                            icon: Icons.folder_open,
                            label: 'Open in ${ProcessRunner.fileManagerName}',
                          ),
                        ),
                      PopupMenuItem<String>(
                        value: 'select_in_fide',
                        child: IconMenuRow(
                          icon: Icons.search,
                          label: 'Select in FIDE-Explorer',
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      switch (value) {
                        case 'copy_path':
                          MessageBox.copyToClipboard(
                            context,
                            _iconPath,
                            confirmation: 'Path copied to clipboard',
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

  /// A bold caption introducing a group of details.
  Widget _buildHeading(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: AppFontSize.caption,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  /// A build-info line: a fixed-width [label] column, then [value] in
  /// monospace, truncated to one line.
  Widget _buildDetailRow(String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: AppSize.platformDetailLabelWidth,
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppFontSize.metadata,
              color: colorScheme.onSurface.withValues(
                alpha: AppOpacity.emphasis,
              ),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTextStyle.monospace.copyWith(
              fontSize: AppFontSize.metadata,
              color: colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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

  /// Bundled icon for the selected platform.
  String get _genericIconPath => widget.selectedPlatform.iconAsset;

  /// How to add the selected platform to the project.
  String _getEnableInstructions() {
    if (widget.isSupported) return 'Platform is already configured';
    return widget.selectedPlatform.enableInstructions;
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
