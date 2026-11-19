import 'package:fide/constants/constants.dart';
import 'package:fide/models/build_artifacts.dart';
import 'package:fide/models/flutter_platform.dart';
import 'package:fide/models/locale_number.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/providers/app_icon_review_provider.dart';
import 'package:fide/providers/center_view.dart';
import 'package:fide/providers/panel_actions.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/widget_services/file_actions.dart';
import 'package:fide/widgets/app_icon_image.dart';
import 'package:fide/widgets/badge_status.dart';
import 'package:fide/widgets/container_counter.dart';
import 'package:fide/widgets/detail_row.dart';
import 'package:fide/widgets/detail_section.dart';
import 'package:fide/widgets/outlined_surface.dart';
import 'package:fide/widgets/platform_icon.dart';
import 'package:fide/widgets/section_panel.dart';
import 'package:fide/widgets/section_title.dart';
import 'package:fide/widgets/status_tone_style.dart';
import 'package:fide/widgets/surface_padding.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

/// The Execute panel's section about the [selectedPlatform]: whether the
/// project supports it and this computer can build it, its last build's
/// output and its app icons' problems.
class PlatformInfoSection extends ConsumerStatefulWidget {
  /// Creates the section for [selectedPlatform] of the project at
  /// [projectPath].
  const PlatformInfoSection({
    super.key,
    required this.selectedPlatform,
    required this.isSupported,
    required this.canBuild,
    required this.projectPath,
  });

  /// Whether this computer can build [selectedPlatform].
  final bool canBuild;

  /// Whether the project has [selectedPlatform]'s folder.
  final bool isSupported;

  /// The open project's folder.
  final String projectPath;

  /// The platform the Execute panel builds and runs.
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
                      : StatusTone.warning.readableIn(
                          Theme.of(context).colorScheme,
                        )
                : StatusTone.error.readableIn(Theme.of(context).colorScheme),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Row
          Row(
            children: [
              const SectionTitle('Status'),
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

          DetailSection('Build Info', [
            DetailRow('Last Build', _artifacts.lastBuildTime),
            DetailRow('Size', _artifacts.size),
            DetailRow('Location', p.basename(_artifacts.location)),
          ]),

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
      onTap: () => showCenterView(ref, CenterView.appIcons),
    );
  }

  /// Returns the platform icon widget — either an SVG asset or a Material icon fallback.
  Widget _buildIcon() {
    return AppIconImage(
      path: _artifacts.appIconPath,
      size: AppIconSize.xLarge,
      fallback: PlatformIcon(
        platform: widget.selectedPlatform,
        size: AppIconSize.xLarge,
        isSupported: widget.isSupported,
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

  /// Reads the build output off the UI thread; results for a platform or
  /// project the user has since switched away from are dropped.
  Future<void> _inspectArtifacts() async {
    final platform = widget.selectedPlatform;
    final projectPath = widget.projectPath;
    final artifacts = await ref
        .read(buildArtifactsInspectorProvider)
        .inspect(projectPath, platform);
    if (mounted &&
        platform == widget.selectedPlatform &&
        projectPath == widget.projectPath) {
      setState(() => _artifacts = artifacts);
    }
  }
}
