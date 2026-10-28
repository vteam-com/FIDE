import 'package:fide/constants/constants.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/widgets/full_path_widget.dart';
import 'package:fide/widgets/loading_actions_log.dart';
import 'package:fide/widgets/loading_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Represents `CreateProjectStep3`.
class CreateProjectStep3 extends StatefulWidget {
  const CreateProjectStep3({
    super.key,
    required this.projectName,
    required this.projectLocation,
  });

  final String projectLocation;

  final String projectName;

  @override
  State<CreateProjectStep3> createState() => _CreateProjectStep3State();
}

class _CreateProjectStep3State extends State<CreateProjectStep3> {
  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final loadingActions = ref.watch(loadingActionsProvider);
        final hasFailed = loadingActions.any(
          (action) => action.status == LoadingStatus.failed,
        );

        return Container(
          width: AppSize.panelFallbackHeight,
          constraints: const BoxConstraints(
            maxHeight: AppSize.terminalMaxHeight,
          ),
          child: Column(
            spacing: AppSpacing.xLarge,
            children: [
              // Project info
              Container(
                padding: const EdgeInsets.all(AppSpacing.xLarge),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppSpacing.medium,
                  children: [
                    Text(
                      'Creating project: ${widget.projectName}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    FullPathWidget(
                      path: '${widget.projectLocation}/${widget.projectName}',
                    ),
                  ],
                ),
              ),

              LoadingProgressBar(actions: loadingActions),

              if (loadingActions.isNotEmpty)
                Expanded(
                  child: LoadingActionsLog(
                    actions: loadingActions,
                    framed: true,
                  ),
                ),

              // Error message if failed
              if (hasFailed)
                Text(
                  'Project creation failed. Please check the errors above.',
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        );
      },
    );
  }
}
