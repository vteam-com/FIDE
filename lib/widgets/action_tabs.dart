// ignore_for_file: deprecated_member_use

import 'package:fide/constants/constants.dart';
import 'package:fide/models/action_status.dart';
import 'package:fide/models/panel_action.dart';
import 'package:fide/widgets/inline_spinner.dart';
import 'package:fide/widgets/status_indicator.dart';
import 'package:flutter/material.dart';

/// Tabs of panel actions, each showing its details, an Execute (or Stop)
/// button and its status.
class ActionTabsWithExecute extends StatefulWidget {
  /// Creates tabs for [actions].
  const ActionTabsWithExecute({super.key, required this.actions});

  /// The actions, in tab order.
  final List<PanelAction> actions;

  @override
  State<ActionTabsWithExecute> createState() => _ActionTabsWithExecuteState();
}

class _ActionTabsWithExecuteState extends State<ActionTabsWithExecute>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.actions.length, vsync: this);
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
      _tabController.dispose();
      _tabController = TabController(
        length: widget.actions.length,
        vsync: this,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (_, constraints) {
        final showLabels =
            constraints.maxWidth >
            AppSize.tabLabelBreakpoint; // Show labels if wider than 240px

        return Container(
          padding: AppPadding.actionTabContainer,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.medium),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: AppOpacity.divider),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TabBar with action tabs
              TabBar(
                controller: _tabController,
                tabs: widget.actions.map((action) {
                  final status = action.status;
                  final isRunning = action.isRunning;
                  final icon = action.icon;

                  return Tab(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isRunning)
                          InlineSpinner(
                            size: showLabels
                                ? AppSize.regularProgressIndicator
                                : AppSize.expandedProgressIndicator,
                            color: Colors.amber,
                          )
                        else
                          Icon(
                            status == ActionStatus.success
                                ? Icons.check_circle
                                : status == ActionStatus.error
                                ? Icons.error
                                : icon,
                            size: showLabels
                                ? AppIconSize.large
                                : AppIconSize.largeCompact,
                          ),
                        if (showLabels) ...[
                          const SizedBox(height: AppSpacing.tiny),
                          Text(
                            action.title,
                            style: TextStyle(
                              fontSize: AppFontSize.badge,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
                labelColor: colorScheme.primary,
                unselectedLabelColor: colorScheme.onSurface.withValues(
                  alpha: AppOpacity.muted,
                ),
                indicatorColor: colorScheme.primary,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelPadding: showLabels
                    ? AppPadding.actionTabLabelExpanded
                    : AppPadding.actionTabLabelCompact,
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
                                  style: TextStyle(
                                    fontSize: AppFontSize.metadata,
                                    color: colorScheme.onSurface.withValues(
                                      alpha: AppOpacity.emphasis,
                                    ),
                                    height: AppLineHeight.compact,
                                    fontFamily: 'monospace',
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
                                          size:
                                              AppSize.compactProgressIndicator,
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
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: canStop
                                        ? Colors.red
                                        : isRunning
                                        ? Colors.grey
                                        : color,
                                    foregroundColor: Colors.white,
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
                              else if (status == ActionStatus.success)
                                StatusIndicator(
                                  icon: Icons.check_circle,
                                  label: 'Success',
                                  color: Colors.green,
                                )
                              else if (status == ActionStatus.error)
                                StatusIndicator(
                                  icon: Icons.error,
                                  label: 'Failed',
                                  color: Colors.red,
                                ),
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
      },
    );
  }
}
