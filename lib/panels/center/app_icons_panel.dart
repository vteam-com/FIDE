import 'dart:io';

import 'package:fcheck/fcheck.dart';
import 'package:fide/constants/constants.dart';
import 'package:fide/models/locale_number.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/editor_navigation.dart';
import 'package:fide/providers/panel_actions.dart';
import 'package:fide/providers/right_panel_tab.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/services/app_icon_fixer.dart';
import 'package:fide/widgets/action_card.dart';
import 'package:fide/widgets/app_icon_image.dart';
import 'package:fide/widgets/app_icon_slot_tile.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:fide/widgets/empty_label.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/page_header.dart';
import 'package:fide/widgets/path_text.dart';
import 'package:fide/widgets/primary_button.dart';
import 'package:fide/widgets/secondary_button.dart';
import 'package:fide/widgets/status_indicator.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

/// Shown in the center panel to review the open project's app icons: each
/// platform's icon and the problems fCheck finds with it, fixed in one
/// click by regenerating the icons from one master image.
class AppIconsPanel extends ConsumerStatefulWidget {
  /// Creates the review of the open project's app icons.
  const AppIconsPanel({super.key});

  @override
  ConsumerState<AppIconsPanel> createState() => _AppIconsPanelState();
}

class _AppIconsPanelState extends ConsumerState<AppIconsPanel> {
  /// Image formats the fixer reads.
  static const List<String> _masterExtensions = ['png', 'jpg', 'jpeg', 'webp'];

  /// Platforms whose icons are being written.
  final Set<AppIconPlatform> _fixing = {};

  @override
  Widget build(BuildContext context) {
    final projectPath = ref.watch(currentProjectPathProvider);
    if (projectPath == null) return const SizedBox();
    final report = ref.watch(appIconReportProvider).value;
    final issues = report?.issues ?? const <AppIconIssue>[];
    final slots = report?.slots ?? const <AppIconSlot>[];
    final master = ref.watch(appIconMasterProvider).value;
    final platforms = [
      for (final platform in AppIconPlatform.values)
        if (Directory(p.join(projectPath, platform.name)).existsSync())
          platform,
    ];
    final broken = {for (final issue in issues) issue.platform};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.huge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.xxLarge,
        children: [
          PageHeader(
            title: 'App Icons',
            subTitle: issues.isEmpty
                ? 'Every platform icon checks out'
                : '${issues.length.count('problem')} on '
                      '${broken.length.count('platform')}',
            logo: const Icon(Icons.apps, size: AppSize.heroLogoHeight),
            actions: [
              CompactIconButton(
                tooltip: 'Check again',
                icon: Icons.refresh,
                onPressed: () => ref.invalidate(appIconReportProvider),
              ),
              CompactIconButton(
                tooltip: 'Close',
                icon: Icons.close,
                onPressed: () =>
                    ref.read(appIconsVisibleProvider.notifier).state = false,
              ),
            ],
          ),
          _masterCard(projectPath, master, broken),
          for (final platform in platforms)
            _platformCard(
              projectPath,
              platform,
              [
                for (final issue in issues)
                  if (issue.platform == platform) issue,
              ],
              [
                for (final slot in slots)
                  if (slot.platform == platform) slot,
              ],
              master,
            ),
        ],
      ),
    );
  }

  /// The image every icon is generated from, how to pick another one, and
  /// the button fixing every [broken] platform from it.
  Widget _masterCard(
    String projectPath,
    String? master,
    Set<AppIconPlatform> broken,
  ) {
    final image = master == null ? null : AppIconFileInfo.read(File(master));
    final tooSmall =
        image != null &&
        (image.width < AppIconFixer.recommendedMasterSize ||
            image.height < AppIconFixer.recommendedMasterSize);
    final notSquare = image != null && image.width != image.height;
    return ActionCard(
      icon: Icons.image_outlined,
      title: 'Master image',
      description:
          'Fixes generate every icon from this image: at least '
          '${AppIconFixer.recommendedMasterSize}×'
          '${AppIconFixer.recommendedMasterSize} px, square, PNG.',
      action: Wrap(
        spacing: AppSpacing.medium,
        children: [
          SecondaryButton(
            icon: Icons.folder_open,
            label: 'Choose…',
            onPressed: () => _chooseMaster(projectPath),
          ),
          PrimaryButton(
            icon: Icons.auto_fix_high,
            label: 'Fix all',
            busy: _fixing.isNotEmpty,
            onPressed: master == null || broken.isEmpty
                ? null
                : () => _fix(projectPath, broken, master),
          ),
        ],
      ),
      child: Row(
        spacing: AppSpacing.large,
        children: [
          _preview(master),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.tiny,
              children: [
                if (master == null)
                  const EmptyLabel('No image yet: choose one')
                else
                  PathText(master, rootPath: projectPath, selectable: true),
                if (image != null)
                  Text(
                    '${image.width}×${image.height} px',
                    style: AppTextStyle.secondary(context),
                  ),
                if (tooSmall)
                  StatusIndicator.tone(
                    StatusTone.warning,
                    label: 'Smaller than the largest icons: they will blur',
                  ),
                if (notSquare)
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

  /// [platform]'s [issues], every one of its [slots] grouped as Xcode
  /// shows them, and the button fixing the issues from [master].
  Widget _platformCard(
    String projectPath,
    AppIconPlatform platform,
    List<AppIconIssue> issues,
    List<AppIconSlot> slots,
    String? master,
  ) {
    final selection = ref.watch(appIconSelectionProvider);
    final groups = <String, List<AppIconSlot>>{};
    for (final slot in slots) {
      groups.putIfAbsent(slot.group, () => []).add(slot);
    }
    return ActionCard(
      icon: Icons.apps,
      title: platform.label,
      action: issues.isEmpty
          ? null
          : PrimaryButton(
              icon: Icons.auto_fix_high,
              label: 'Fix',
              busy: _fixing.contains(platform),
              onPressed: master == null || _fixing.isNotEmpty
                  ? null
                  : () => _fix(projectPath, {platform}, master),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.large,
        children: [
          if (issues.isEmpty)
            StatusIndicator.tone(StatusTone.success, label: 'No issues')
          else
            for (final issue in issues)
              StatusIndicator.tone(
                StatusTone.warning,
                label: '${issue.message}\n${issue.filePath}',
              ),
          for (final MapEntry(key: group, value: groupSlots)
              in groups.entries) ...[
            Text(group, style: AppTextStyle.captionStrong),
            Wrap(
              spacing: AppSpacing.large,
              runSpacing: AppSpacing.large,
              children: [
                for (final slot in groupSlots)
                  _buildTile(projectPath, slot, issues, selection),
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

  /// The tile of [slot] with its [issues], filled when its file is the
  /// [selection]: a click shows its details, a double-click opens it.
  Widget _buildTile(
    String projectPath,
    AppIconSlot slot,
    List<AppIconIssue> issues,
    String? selection,
  ) {
    final path = _pathOf(projectPath, slot);
    return AppIconSlotTile(
      slot: slot,
      projectPath: projectPath,
      isSelected: path != null && path == selection,
      onTap: path == null ? null : () => _select(path),
      onDoubleTap: path == null ? null : () => openFile(ref, path),
      problems: [
        for (final issue in issues)
          if (issue.filePath == slot.filePath) issue.message,
      ],
    );
  }

  /// The absolute path of [slot]'s file; null when it has none to show.
  static String? _pathOf(String projectPath, AppIconSlot slot) {
    final path = slot.filePath;
    return path == null || slot.file == null ? null : p.join(projectPath, path);
  }

  /// Shows the details of the icon file at [path] in the Outline tab.
  void _select(String path) {
    ref.read(appIconSelectionProvider.notifier).state = path;
    showRightPanelTab(ref.read, RightPanelTab.outline);
  }

  /// Lets the user pick the master image, starting in the project folder.
  Future<void> _chooseMaster(String projectPath) async {
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

  /// Regenerates the icons of [platforms] from [master], one platform at a
  /// time, then reloads what changed and reports the outcome.
  Future<void> _fix(
    String projectPath,
    Set<AppIconPlatform> platforms,
    String master,
  ) async {
    setState(() => _fixing.addAll(platforms));
    final fixer = ref.read(appIconFixerProvider);
    final written = <String>[];
    final failures = <String>[];
    for (final platform in platforms) {
      try {
        written.addAll(await fixer.fix(projectPath, platform, master));
      } catch (e) {
        failures.add('${platform.label}: $e');
      }
      if (mounted) setState(() => _fixing.remove(platform));
    }
    // The previews show files rewritten in place
    imageCache
      ..clear()
      ..clearLiveImages();
    await ref.read(openDocumentsProvider.notifier).reloadWritten([
      for (final path in written) p.join(projectPath, path),
    ]);
    if (!mounted) return;
    if (failures.isEmpty) {
      MessageBox.showSuccess(context, 'Wrote ${written.length.count('file')}');
    } else {
      MessageBox.showError(context, failures.join('\n'));
    }
  }
}
