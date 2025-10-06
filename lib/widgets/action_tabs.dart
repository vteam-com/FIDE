// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

// Local import
import 'status_indicator.dart';

enum BuildProcessStatus { idle, running, success, error }

class ActionTabsWithExecute extends StatefulWidget {
  final List<Map<String, dynamic>> actions;

  const ActionTabsWithExecute({super.key, required this.actions});

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
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final showLabels =
            constraints.maxWidth > 240; // Show labels if wider than 240px

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TabBar with action tabs
              TabBar(
                controller: _tabController,
                tabs: widget.actions.map((action) {
                  final status = action['status'] as BuildProcessStatus;
                  final isRunning = status == BuildProcessStatus.running;
                  final icon = action['icon'] as IconData;

                  return Tab(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isRunning)
                          SizedBox(
                            width: showLabels ? 20 : 24,
                            height: showLabels ? 20 : 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.amber,
                              ),
                            ),
                          )
                        else
                          Icon(
                            status == BuildProcessStatus.success
                                ? Icons.check_circle
                                : status == BuildProcessStatus.error
                                ? Icons.error
                                : icon,
                            size: showLabels ? 20 : 22,
                          ),
                        if (showLabels) ...[
                          const SizedBox(height: 4),
                          Text(
                            action['title'] as String,
                            style: TextStyle(
                              fontSize: 10,
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
                  alpha: 0.6,
                ),
                indicatorColor: colorScheme.primary,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: showLabels ? 4 : 8,
                ),
              ),

              const SizedBox(height: 16),

              // Content area showing selected action details
              SizedBox(
                height:
                    220, // Fixed height for content area - increased for no scroll
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: widget.actions.map((action) {
                    final status = action['status'] as BuildProcessStatus;
                    final isRunning = status == BuildProcessStatus.running;
                    final color = action['color'] as Color;

                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Action title and description
                          Row(
                            children: [
                              Icon(
                                action['icon'] as IconData,
                                size: 24,
                                color: color,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      action['title'] as String,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                    Text(
                                      action['description'] as String,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurface.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Action details - reduced size and made expandable
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: SingleChildScrollView(
                                // Keep only this for the details text
                                child: Text(
                                  action['details'] as String,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.8,
                                    ),
                                    height: 1.3,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Execute button and status in a compact footer
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: isRunning
                                      ? null // Disable when running
                                      : () {
                                          final onPressed =
                                              action['action'] as VoidCallback?;
                                          onPressed?.call();
                                        },
                                  icon: isRunning
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                      : Icon(Icons.play_arrow, size: 18),
                                  label: Text(
                                    isRunning ? 'Running...' : 'Execute',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isRunning
                                        ? Colors.grey
                                        : color,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),

                              // Status message - compact
                              SizedBox(height: 6),
                              if (isRunning)
                                StatusIndicator(
                                  icon: Icons.hourglass_top,
                                  label: 'In progress...',
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                )
                              else if (status == BuildProcessStatus.success)
                                StatusIndicator(
                                  icon: Icons.check_circle,
                                  label: 'Success',
                                  color: Colors.green,
                                )
                              else if (status == BuildProcessStatus.error)
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
