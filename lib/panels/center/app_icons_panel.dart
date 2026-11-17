import 'package:fide/constants/constants.dart';
import 'package:fide/models/app_icon_review.dart';
import 'package:fide/models/locale_number.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/providers/app_icon_fix_controller.dart';
import 'package:fide/providers/app_icon_review_provider.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/editor_navigation.dart';
import 'package:fide/providers/panel_actions.dart';
import 'package:fide/providers/right_panel_tab.dart';
import 'package:fide/widget_services/app_icon_slot_tile.dart';
import 'package:fide/widgets/action_card.dart';
import 'package:fide/widgets/app_icon_image.dart';
import 'package:fide/widgets/clickable.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:fide/widgets/empty_label.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/page_header.dart';
import 'package:fide/widgets/page_scroll_view.dart';
import 'package:fide/widgets/path_text.dart';
import 'package:fide/widgets/primary_button.dart';
import 'package:fide/widgets/refresh_button.dart';
import 'package:fide/widgets/secondary_button.dart';
import 'package:fide/widgets/status_indicator.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Shown in the center panel to review the open project's app icons: each
/// platform's icon and the problems fCheck finds with it, fixed in one
/// click by regenerating the icons from one master image.
class AppIconsPanel extends ConsumerWidget {
  /// Creates the review of the open project's app icons.
  const AppIconsPanel({super.key});

  /// Image formats the fixer reads.
  static const List<String> _masterExtensions = ['png', 'jpg', 'jpeg', 'webp'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectPath = ref.watch(currentProjectPathProvider);
    if (projectPath == null) return const SizedBox();
    final reviewing = ref.watch(appIconReviewProvider);
    final review = reviewing.value;
    final issues = review?.issues ?? const <AppIconProblem>[];
    final master = review?.master;
    final fixing = ref.watch(appIconFixControllerProvider);

    return PageScrollView(
      children: [
        PageHeader(
          title: 'App Icons',
          subTitle: issues.isEmpty
              ? 'Every platform icon checks out'
              : '${issues.length.count('problem')} on '
                    '${review!.brokenPlatformCount.count('platform')}',
          logo: const Icon(Icons.apps),
          actions: [
            RefreshButton(
              busy: reviewing.isLoading,
              onPressed: () => ref.invalidate(appIconReviewProvider),
            ),
            CompactIconButton(
              tooltip: 'Close',
              icon: Icons.close,
              onPressed: () => closeCenterView(ref),
            ),
          ],
        ),
        _masterCard(
          context,
          ref,
          projectPath,
          master,
          review?.brokenPlatforms ?? const [],
          fixing,
        ),
        for (final platform in review?.platforms ?? const [])
          _platformCard(context, ref, projectPath, platform, master, fixing),
      ],
    );
  }

  /// The image every icon is generated from, how to pick another one, and
  /// the button fixing it and every [broken] platform while nothing is
  /// [fixing].
  Widget _masterCard(
    BuildContext context,
    WidgetRef ref,
    String projectPath,
    AppIconMaster? master,
    List<AppIconPlatformReview> broken,
    Set<String> fixing,
  ) {
    final readable = master != null && master.isReadable ? master.path : null;
    return ActionCard(
      icon: Icons.image_outlined,
      title: 'Master image',
      description:
          'Fixes generate every icon from this image: at least '
          '${AppIconMaster.recommendedSize}×'
          '${AppIconMaster.recommendedSize} px, square, PNG.',
      action: Wrap(
        spacing: AppSpacing.medium,
        children: [
          SecondaryButton(
            icon: Icons.folder_open,
            label: 'Choose…',
            onPressed: () => _chooseMaster(ref, projectPath),
          ),
          PrimaryButton(
            icon: Icons.auto_fix_high,
            label: 'Fix all',
            // The platforms' own buttons tell they are being fixed
            busy: fixing.contains(AppIconFixController.masterId),
            onPressed:
                master == null ||
                    fixing.isNotEmpty ||
                    (broken.isEmpty && !master.needsFix)
                ? null
                : () => _fix(
                    context,
                    ref,
                    projectPath,
                    broken,
                    master.path,
                    fixMaster: master.needsFix,
                  ),
          ),
        ],
      ),
      child: Row(
        spacing: AppSpacing.large,
        children: [
          Clickable(
            onTap: _onTap(ref, readable),
            onDoubleTap: _onDoubleTap(ref, readable),
            child: _preview(master?.path),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.tiny,
              children: [
                if (master == null)
                  const EmptyLabel('No image yet: choose one')
                else
                  PathText(
                    master.path,
                    rootPath: projectPath,
                    selectable: true,
                  ),
                if (master != null && master.isReadable)
                  Text(
                    '${master.width}×${master.height} px',
                    style: AppTextStyle.secondary(context),
                  ),
                if (master?.isTooSmall ?? false)
                  StatusIndicator.tone(
                    StatusTone.warning,
                    label: 'Smaller than the largest icons: they will blur',
                  ),
                if (master?.isNotSquare ?? false)
                  StatusIndicator.tone(
                    StatusTone.warning,
                    label: 'Not square: the center square is used',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// [platform]'s issues, every one of its slots grouped as Xcode shows
  /// them, and the button fixing the issues from [master] while nothing
  /// is [fixing].
  Widget _platformCard(
    BuildContext context,
    WidgetRef ref,
    String projectPath,
    AppIconPlatformReview platform,
    AppIconMaster? master,
    Set<String> fixing,
  ) {
    final selection = ref.watch(appIconSelectionProvider);
    return ActionCard(
      icon: Icons.apps,
      title: platform.label,
      action: !platform.hasIssues
          ? null
          : PrimaryButton(
              icon: Icons.auto_fix_high,
              label: 'Fix',
              busy: fixing.contains(platform.id),
              onPressed: master == null || fixing.isNotEmpty
                  ? null
                  : () => _fix(context, ref, projectPath, [
                      platform,
                    ], master.path),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.large,
        children: [
          if (!platform.hasIssues)
            StatusIndicator.tone(StatusTone.success, label: 'No issues')
          else
            for (final issue in platform.issues)
              StatusIndicator.tone(
                StatusTone.warning,
                label: '${issue.message}\n${issue.filePath}',
              ),
          for (final MapEntry(key: group, value: groupSlots)
              in platform.groups.entries) ...[
            Text(group, style: AppTextStyle.captionStrong),
            Wrap(
              spacing: AppSpacing.large,
              runSpacing: AppSpacing.large,
              children: [
                for (final slot in groupSlots) _buildTile(ref, slot, selection),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// The icon at [path] at preview size, or [fallback] when there is none.
  Widget _preview(String? path, {Widget? fallback}) {
    return AppIconImage(
      path: path,
      size: AppSize.appIconPreview,
      fallback:
          fallback ??
          const Icon(Icons.image_not_supported, size: AppSize.appIconPreview),
    );
  }

  /// The tile of [slot], filled when its file is the [selection]: a click
  /// shows its details, a double-click opens it.
  Widget _buildTile(WidgetRef ref, AppIconSlotInfo slot, String? selection) {
    final path = slot.readablePath;
    return AppIconSlotTile(
      slot: slot,
      isSelected: path != null && path == selection,
      onTap: _onTap(ref, path),
      onDoubleTap: _onDoubleTap(ref, path),
    );
  }

  /// Shows the details of the image at [path] on click; null without one.
  VoidCallback? _onTap(WidgetRef ref, String? path) =>
      path == null ? null : () => _select(ref, path);

  /// Opens the image at [path] on double-click; null without one.
  VoidCallback? _onDoubleTap(WidgetRef ref, String? path) =>
      path == null ? null : () => openFromCenterView(ref, path);

  /// Shows the details of the icon file at [path] in the Outline tab.
  void _select(WidgetRef ref, String path) {
    ref.read(appIconSelectionProvider.notifier).state = path;
    showRightPanelTab(ref.read, RightPanelTab.outline);
  }

  /// Lets the user pick the master image, starting in the project folder.
  Future<void> _chooseMaster(WidgetRef ref, String projectPath) async {
    final picked = await FilePicker.pickFile(
      dialogTitle: 'Master image for the app icons',
      initialDirectory: projectPath,
      type: FileType.custom,
      allowedExtensions: _masterExtensions,
    );
    final path = picked?.path;
    if (path != null) {
      ref.read(appIconMasterChoiceProvider.notifier).state = path;
    }
  }

  /// Regenerates the icons of [platforms] from the image at [masterPath],
  /// rewriting that image first when [fixMaster], and reports the outcome.
  Future<void> _fix(
    BuildContext context,
    WidgetRef ref,
    String projectPath,
    List<AppIconPlatformReview> platforms,
    String masterPath, {
    bool fixMaster = false,
  }) async {
    final outcome = await ref
        .read(appIconFixControllerProvider.notifier)
        .fix(projectPath, platforms, masterPath, fixMaster: fixMaster);
    if (context.mounted) {
      MessageBox.show(context, outcome.message, outcome.tone);
    }
  }
}
