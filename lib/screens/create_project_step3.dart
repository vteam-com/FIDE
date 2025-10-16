import 'package:fide/widgets/full_path_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fide/providers/app_providers.dart';

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
      builder: (context, ref, child) {
        final loadingActions = ref.watch(loadingActionsProvider);
        final hasFailed = loadingActions.any(
          (action) => action.status == LoadingStatus.failed,
        );

        return Container(
          width: 600,
          constraints: const BoxConstraints(maxHeight: 400),
          child: Column(
            spacing: 16,
            children: [
              // Project info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
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

              // Loading Progress
              Consumer(
                builder: (context, ref, child) {
                  final loadingActions = ref.watch(loadingActionsProvider);

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
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 300),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: loadingActions.length,
                      itemBuilder: (context, index) {
                        final LoadingAction action = loadingActions[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 16,
                          ),
                          child: Row(
                            spacing: 8,
                            children: [
                              // Status icon
                              _buildStatusIcon(action.status, context),

                              // Action text
                              Expanded(
                                child: Text(
                                  action.text,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color:
                                            action.status ==
                                                LoadingStatus.failed
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.error
                                            : null,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),

              // Error message if failed
              if (hasFailed)
                Text(
                  'Project creation failed. Please check the errors above.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusIcon(LoadingStatus status, BuildContext context) {
    switch (status) {
      case LoadingStatus.pending:
        return SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 1,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
        );
      case LoadingStatus.success:
        return Icon(Icons.check_circle, color: Colors.green, size: 20);
      case LoadingStatus.failed:
        return Icon(
          Icons.error,
          color: Theme.of(context).colorScheme.error,
          size: 20,
        );
    }
  }
}
