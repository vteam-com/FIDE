// ignore_for_file: deprecated_member_use

import 'package:fide/constants/constants.dart';
import 'package:fide/models/build_artifacts.dart';
import 'package:fide/models/flutter_platform.dart';
import 'package:fide/models/locale_number.dart';
import 'package:fide/providers/app_icon_review_provider.dart';
import 'package:fide/providers/panel_actions.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/theme/app_theme.dart';
import 'package:fide/widgets/app_icon_image.dart';
import 'package:fide/widgets/badge_status.dart';
import 'package:fide/widgets/container_counter.dart';
import 'package:fide/widgets/detail_row.dart';
import 'package:fide/widgets/file_actions.dart';
import 'package:fide/widgets/outlined_surface.dart';
import 'package:fide/widgets/section_panel.dart';
import 'package:fide/widgets/section_title.dart';
import 'package:fide/widgets/surface_padding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as p;

/// Represents `PlatformInfoSection`.
class PlatformInfoSection extends ConsumerStatefulWidget {
  const PlatformInfoSection({
    super.key,
    required this.selectedPlatform,
    required this.isSupported,
    required this.canBuild,
    required this.projectPath,
  });

  final bool canBuild;

  final bool isSupported;

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
                      : AppTheme.readable(
                          AppTheme.warningColor,
                          Theme.of(context).colorScheme,
                        )
                : Theme.of(context).colorScheme.error,
          ),
        ],
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
              DetailRow('Last Build:', _artifacts.lastBuildTime),
              const SizedBox(height: AppSpacing.micro),
              DetailRow('Size:', _artifacts.size),
              const SizedBox(height: AppSpacing.micro),
              DetailRow('Location:', p.basename(_artifacts.location)),
            ],
          ),

          // Enable instructions (if not supported)
          if (!widget.isSupported) ...[
            const SizedBox(height: AppSpacing.medium),
            OutlinedSurface(
              padding: SurfacePadding.dense,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      BadgeStatus.info(text: 'ENABLE'),
                      const SizedBox(width: AppSpacing.medium),
                      Expanded(
                        child: SectionTitle(
                          'Instructions for ${widget.selectedPlatform.displayName}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Text(
                    _getEnableInstructions(),
                    style: AppTextStyle.secondary(context),
                  ),
                ],
              ),
            ),
          ],

          // The app icon and its file's actions
          const SizedBox(height: AppSpacing.medium),
          OutlinedSurface(
            padding: SurfacePadding.dense,
            child: Row(
              children: [
                _buildIcon(),
                const SizedBox(width: AppSpacing.medium),
                Expanded(
                  child: switch (_artifacts.appIconPath) {
                    final path? => FileActions(path: path),
                    null => Text(
                      p.basename(_genericIconPath),
                      style: AppTextStyle.captionStrong,
                    ),
                  },
                ),
                _buildIconIssues(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// How many problems the platform's app icons have, opening the App
  /// Icons view to fix them; nothing when they have none.
  Widget _buildIconIssues() {
    final count =
        ref
            .watch(appIconReviewProvider)
            .value
            ?.issueCountOf(widget.selectedPlatform.name) ??
        0;
    if (count == 0) return const SizedBox();
    return ContainerCounter.warning(
      icon: Icons.apps,
      count: count,
      tooltip:
          '${count.count('app icon problem')} on '
          '${widget.selectedPlatform.displayName}.'
          '\nClick to review and fix them.',
      onTap: () => showAppIcons(ref),
    );
  }

  /// A bold caption introducing a group of details.
  Widget _buildHeading(String label) {
    return Text(label, style: AppTextStyle.captionStrong);
  }

  /// Returns the platform icon widget — either an SVG asset or a Material icon fallback.
  Widget _buildIcon() {
    return AppIconImage(
      path: _artifacts.appIconPath,
      size: AppIconSize.xLarge,
      fallback: SvgPicture.asset(
        _genericIconPath,
        width: AppIconSize.xLarge,
        height: AppIconSize.xLarge,
      ),
    );
  }

  /// Bundled icon for the selected platform.
  String get _genericIconPath => widget.selectedPlatform.iconAsset;

  /// How to add the selected platform to the project.
  String _getEnableInstructions() {
    if (widget.isSupported) return 'Platform is already configured';
    return widget.selectedPlatform.enableInstructions;
  }

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
}
