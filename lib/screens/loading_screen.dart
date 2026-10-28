// ignore_for_file: deprecated_member_use

import 'package:fide/constants/constants.dart';
import 'package:fide/models/app_theme.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/widgets/full_path_widget.dart';
import 'package:fide/widgets/hero_title_widget.dart';
import 'package:fide/widgets/loading_actions_log.dart';
import 'package:fide/widgets/loading_progress_bar.dart';
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
      decoration: AppTheme.screenBackground(context),
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

                        LoadingProgressBar(actions: loadingActions),

                        if (loadingActions.isNotEmpty)
                          LoadingActionsLog(actions: loadingActions),

                        // Error message and retry button if failed
                        if (hasFailed)
                          Column(
                            spacing: AppSpacing.xLarge,
                            children: [
                              Text(
                                'Project loading failed. Please check the errors above.',
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error,
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
}
