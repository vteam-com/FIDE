// ignore_for_file: deprecated_member_use

import 'package:fide/constants/constants.dart';
import 'package:fide/models/action_status.dart';
import 'package:fide/models/app_theme.dart';
import 'package:fide/models/panel_action.dart';
import 'package:fide/widgets/icon_label_tab.dart';
import 'package:fide/widgets/icon_tab_bar.dart';
import 'package:fide/widgets/inline_spinner.dart';
import 'package:fide/widgets/outlined_surface.dart';
import 'package:fide/widgets/status_indicator.dart';
import 'package:flutter/material.dart';

/// Tabs of panel actions, each showing its details, an Execute (or Stop)
/// button and its status.
class ActionTabsWithExecute extends StatefulWidget {
  /// Creates tabs for [actions].
  const ActionTabsWithExecute({
    super.key,
    required this.actions,
    this.initialId,
  });

  /// The actions, in tab order.
  final List<PanelAction> actions;

  /// The id of the action selected first, or null for the first tab.
  final String? initialId;

  @override
  State<ActionTabsWithExecute> createState() => _ActionTabsWithExecuteState();
}

class _ActionTabsWithExecuteState extends State<ActionTabsWithExecute>
    with TickerProviderStateMixin {
  late TabController _tabController;
  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.actions.length,
      initialIndex: _indexOf(widget.initialId),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ActionTabsWithExecute oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.actions.length != widget.actions.length) {
      // Keeps the selected ACTION, not its index: switching to Android adds a
      // tab before Run Debug, which would otherwise land on Run Release.
      final selected = oldWidget.actions[_tabController.index].id;
      _tabController.dispose();
      _tabController = TabController(
        length: widget.actions.length,
        initialIndex: _indexOf(selected),
        vsync: this,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return OutlinedSurface(
      padding: AppPadding.actionTabContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TabBar with action tabs
          IconTabBar(
            controller: _tabController,
            tabsBuilder: (showLabels) => widget.actions.map((action) {
              return IconLabelTab(
                showLabel: showLabels,
                label: action.title,
                icon: action.isRunning
                    ? InlineSpinner(
                        size: showLabels
                            ? AppSize.regularProgressIndicator
                            : AppSize.expandedProgressIndicator,
                        color: AppTheme.warningColor,
                      )
                    : Icon(
                        action.status.resultIcon ?? action.icon,
                        size: showLabels
                            ? AppIconSize.large
                            : AppIconSize.largeCompact,
                      ),
              );
            }).toList(),
          ),

          const SizedBox(height: AppSpacing.xLarge),

          // Content area showing selected action details
          SizedBox(
            height: AppSize.actionTabContentHeight,
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: widget.actions.map((action) {
                final status = action.status;
                final isRunning = action.isRunning;
                final color = action.color;
                final canStop = isRunning && action.onStop != null;

                return Padding(
                  padding: AppPadding.actionTabContent,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Action title and description
                      Row(
                        children: [
                          Icon(
                            action.icon,
                            size: AppIconSize.xLarge,
                            color: color,
                          ),
                          const SizedBox(width: AppSpacing.large),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  action.title,
                                  style: TextStyle(
                                    fontSize: AppFontSize.title,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  action.description,
                                  style: TextStyle(
                                    fontSize: AppFontSize.caption,
                                    color: colorScheme.onSurface.withValues(
                                      alpha: AppOpacity.secondaryText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.large),

                      // Action details - reduced size and made expandable
                      Expanded(
                        child: Container(
                          padding: AppPadding.actionTabDetails,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withValues(alpha: AppOpacity.divider),
                            borderRadius: BorderRadius.circular(
                              AppRadius.small,
                            ),
                          ),
                          child: SingleChildScrollView(
                            // Keep only this for the details text
                            child: Text(
                              action.details,
                              style: AppTextStyle.monospace.copyWith(
                                fontSize: AppFontSize.metadata,
                                color: colorScheme.onSurface.withValues(
                                  alpha: AppOpacity.emphasis,
                                ),
                                height: AppLineHeight.compact,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: AppSpacing.large),

                      // Execute button and status in a compact footer
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: canStop
                                  ? action.onStop
                                  : isRunning
                                  ? null
                                  : action.onRun,
                              icon: canStop
                                  ? const Icon(
                                      Icons.stop,
                                      size: AppIconSize.mediumLarge,
                                    )
                                  : isRunning
                                  ? const InlineSpinner(
                                      size: AppSize.compactProgressIndicator,
                                      color: Colors.white,
                                    )
                                  : const Icon(
                                      Icons.play_arrow,
                                      size: AppIconSize.mediumLarge,
                                    ),
                              label: Text(
                                canStop
                                    ? 'Stop'
                                    : isRunning
                                    ? 'Running...'
                                    : 'Execute',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: canStop
                                    ? colorScheme.error
                                    : isRunning
                                    ? Colors.grey
                                    : color,
                                // Contrasted with the fill rather than
                                // fixed white: the dark theme's primary
                                // and error are light tints.
                                foregroundColor: canStop
                                    ? colorScheme.onError
                                    : _onColor(color),
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.regular,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.medium,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Status message - compact
                          const SizedBox(height: AppSpacing.small),
                          if (isRunning)
                            StatusIndicator(
                              icon: Icons.hourglass_top,
                              label: 'In progress...',
                              color: colorScheme.onSurface.withValues(
                                alpha: AppOpacity.muted,
                              ),
                            )
                          else
                            ?StatusIndicator.forResult(status),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// The tab of action [id], or the first tab when there is none.
  int _indexOf(String? id) {
    final i = widget.actions.indexWhere((a) => a.id == id);
    return i < 0 ? 0 : i;
  }

  /// Text colour readable on a button filled with [fill].
  static Color _onColor(Color fill) =>
      ThemeData.estimateBrightnessForColor(fill) == Brightness.dark
      ? Colors.white
      : Colors.black;
}
