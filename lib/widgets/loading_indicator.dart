import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/empty_state.dart';
import 'package:fide/widgets/inline_spinner.dart';
import 'package:flutter/material.dart';

/// A spinner centered in the space of content that is still loading, with
/// an optional [message] under it.
class LoadingIndicator extends StatelessWidget {
  /// Creates a centered spinner.
  const LoadingIndicator({super.key, this.message});

  /// What is loading; just the spinner when null.
  final String? message;

  @override
  Widget build(BuildContext context) {
    final message = this.message;
    const spinner = InlineSpinner(size: AppIconSize.emptyState);
    return message == null
        ? const Center(child: spinner)
        : EmptyState(message: message, child: spinner);
  }
}
