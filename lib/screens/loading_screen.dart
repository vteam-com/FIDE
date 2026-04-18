// ignore_for_file: deprecated_member_use

import 'package:fide/constants/constants.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/widgets/full_path_widget.dart';
import 'package:fide/widgets/hero_title_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Represents `LoadingScreen`.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key, required this.loadingProjectName});

  final String? loadingProjectName;

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSize.compactActionButton),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.surface,
            Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
              alpha: AppOpacity.divider,
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HeroTitleWidget(
            title: 'Loading project',
            subWidget: FullPathWidget(path: widget.loadingProjectName!),
          ),

          Center(
            child: SizedBox(
              width: AppSize.panelFallbackHeight,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xLarge),
                child: Consumer(
                  builder: (context, ref, _) {
                    final loadingActions = ref.watch(loadingActionsProvider);
                    final hasFailed = loadingActions.any(
                      (action) => action.status == LoadingStatus.failed,
                    );

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: AppSpacing.xLarge,
                      children: [
                        // Project Path

                        // Loading Progress (deterministic based on step counters - 6 total steps)
                        Consumer(
                          builder: (context, ref, _) {
                            final loadingActions = ref.watch(
                              loadingActionsProvider,
                            );

                            // Calculate progress based on current step position (max 6 steps)
                            double progress = 0.0;
                            if (loadingActions.isNotEmpty) {
                              final currentStep = loadingActions
                                  .map((action) => action.step)
                                  .reduce((a, b) => a > b ? a : b);
                              const int totalSteps = 6;

                              progress = currentStep / totalSteps;
                              // Ensure progress doesn't exceed 1.0
                              progress = progress.clamp(0.0, 1.0);
                            }

                            return LinearProgressIndicator(
                              value: progress,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.primary,
                              ),
                            );
                          },
                        ),

                        // Loading Actions Log
                        if (loadingActions.isNotEmpty)
                          Container(
                            constraints: const BoxConstraints(
                              maxHeight: AppSize.statusLogMaxHeight,
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: loadingActions.length,
                              itemBuilder: (context, index) {
                                final LoadingAction action =
                                    loadingActions[index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppSpacing.tiny,
                                  ),
                                  child: Row(
                                    spacing: AppSpacing.medium,
                                    children: [
                                      // Status icon
                                      _buildStatusIcon(action.status, context),

                                      // Action text
                                      Expanded(
                                        child: Text(
                                          action.text,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),

                        // Error message and retry button if failed
                        if (hasFailed)
                          Column(
                            spacing: AppSpacing.xLarge,
                            children: [
                              Text(
                                'Project loading failed. Please check the errors above.',
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  // Clear loading state and let user try again
                                  ref
                                          .read(loadingActionsProvider.notifier)
                                          .state =
                                      [];
                                  // The main app should handle retry logic
                                },
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Returns a status icon widget (spinner, check, or error) for the given [LoadingStatus].
  Widget _buildStatusIcon(LoadingStatus status, BuildContext context) {
    switch (status) {
      case LoadingStatus.pending:
        return SizedBox(
          width: AppIconSize.xLarge,
          height: AppSize.statusIconTall,
          child: CircularProgressIndicator(
            strokeWidth: AppSize.borderThin,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
        );
      case LoadingStatus.success:
        return Icon(Icons.check_circle, color: Colors.green);
      case LoadingStatus.failed:
        return Icon(Icons.error, color: Theme.of(context).colorScheme.error);
    }
  }
}
