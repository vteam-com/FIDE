import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/busy_bar.dart';
import 'package:fide/widgets/empty_state.dart';
import 'package:material_ui/material_ui.dart';

/// The space of content that is still loading: a [BusyBar] across its top
/// with an optional [message] centered under it.
class LoadingIndicator extends StatelessWidget {
  /// Creates the placeholder of loading content.
  const LoadingIndicator({super.key, this.message});

  /// What is loading; just the bar when null.
  final String? message;

  @override
  Widget build(BuildContext context) {
    final message = this.message;
    return BusyBar.over(
      busy: true,
      child: message == null
          // As tall as the bar where the space is unbounded
          ? const SizedBox(
              width: double.infinity,
              height: AppBorderWidth.medium,
            )
          : EmptyState(message: message),
    );
  }
}
