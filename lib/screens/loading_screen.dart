// ignore_for_file: deprecated_member_use

import 'package:fide/widgets/full_path_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fide/providers/app_providers.dart';

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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.surface,
            Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
          ],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          child: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Consumer(
                builder: (context, ref, child) {
                  final loadingActions = ref.watch(loadingActionsProvider);
                  final hasFailed = loadingActions.any(
                    (action) => action.status == LoadingStatus.failed,
                  );
                  final allSuccess =
                      loadingActions.isNotEmpty &&
                      loadingActions.every(
                        (action) => action.status == LoadingStatus.success,
                      );

                  // Auto-hide on success after delay
                  if (allSuccess && !hasFailed) {
                    Future.delayed(const Duration(milliseconds: 500), () {
                      // The screen will be hidden when projectLoaded becomes true
                    });
                  }

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    spacing: 16,
                    children: [
                      // App Logo
                      SizedBox(
                        height: 100,
                        child: Image.asset('assets/app.png'),
                      ),

                      // Loading Container
                      // Loading Spinner
                      LinearProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),

                      // Project Path
                      FullPathWidget(path: widget.loadingProjectName!),

                      // Loading Actions Log
                      if (loadingActions.isNotEmpty)
                        Container(
                          constraints: const BoxConstraints(maxHeight: 300),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: loadingActions.length,
                            itemBuilder: (context, index) {
                              final action = loadingActions[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    // Step number
                                    SizedBox(
                                      width: 24,
                                      child: Text(
                                        '${action.step}.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Status icon
                                    SizedBox(
                                      width: 20,
                                      child: _buildStatusIcon(
                                        action.status,
                                        context,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
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
                          spacing: 16,
                          children: [
                            Text(
                              'Project loading failed. Please check the errors above.',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
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
      ),
    );
  }

  Widget _buildStatusIcon(LoadingStatus status, BuildContext context) {
    switch (status) {
      case LoadingStatus.pending:
        return SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
        );
      case LoadingStatus.success:
        return Icon(Icons.check_circle, size: 16, color: Colors.green);
      case LoadingStatus.failed:
        return Icon(
          Icons.error,
          size: 16,
          color: Theme.of(context).colorScheme.error,
        );
    }
  }
}
