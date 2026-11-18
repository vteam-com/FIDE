import 'package:fide/constants/constants.dart';
import 'package:fide/models/readable_error.dart';
import 'package:fide/providers/app_update_notifier.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/task_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// The button updating FIDE to its newer release, shown only while there
/// is one: a [TaskButton] whose ring spins while the release downloads,
/// until FIDE quits and restarts updated; a failure shows as a message.
class UpdateButton extends ConsumerWidget {
  /// Creates the button installing the release [appUpdateProvider] found.
  const UpdateButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final release = ref.watch(appUpdateProvider).value;
    if (release == null) return const SizedBox.shrink();
    return TaskButton(
      icon: Icons.upgrade,
      tooltip: 'Update to ${AppName.short} ${release.version} and restart',
      running: ref.watch(appUpdateInstallingProvider),
      onRun: () => _install(context, ref),
    );
  }

  /// Installs the newer release, showing why on [context] when it fails.
  Future<void> _install(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(appUpdateProvider.notifier).install();
    } catch (error) {
      if (context.mounted) {
        MessageBox.showError(
          context,
          'Update failed: ${ReadableError.describe(error)}',
        );
      }
    }
  }
}
