// ignore_for_file: deprecated_member_use

import 'package:fide/constants/constants.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/widgets/full_path_widget.dart';
import 'package:fide/widgets/hero_title_widget.dart';
import 'package:fide/widgets/loading_actions_log.dart';
import 'package:fide/widgets/loading_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

/// Full-screen progress view shown while a project loads.
///
/// Transparent, so the workspace gradient shows through behind it.
class LoadingScreen extends StatefulWidget {
  /// Creates the loading view for the project at [loadingProjectName].
  const LoadingScreen({super.key, required this.loadingProjectName});

  /// Full path of the project being loaded.
  final String? loadingProjectName;

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  Widget build(BuildContext context) {
    final projectPath = widget.loadingProjectName!;
    return Padding(
      padding: const EdgeInsets.all(AppSize.compactActionButton),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HeroTitleWidget(
            title: 'Loading ${p.basename(projectPath)}',
            subWidget: FullPathWidget(path: projectPath),
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
                                style: AppTextStyle.label.copyWith(
                                  color: Theme.of(context).colorScheme.error,
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
