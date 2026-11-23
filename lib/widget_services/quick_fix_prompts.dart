import 'package:fide/models/quick_fix.dart';
import 'package:fide/providers/quick_fix_controller.dart';
import 'package:fide/services/quick_fix_runner.dart';
import 'package:fide/widgets/blocking_task_dialog.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Asks the user to confirm a quick fix in a dialog over [context]; false
/// once [context] is gone.
QuickFixConfirmation confirmQuickFixOver(BuildContext context) =>
    (fix, message) async =>
        context.mounted &&
        await MessageBox.confirm(
          context,
          title: fix.label,
          message: message,
          confirmLabel: fix.label,
        );

/// Shows a quick fix's messages over [context] while it is there.
QuickFixNotice quickFixNoticesOver(BuildContext context) => (message, tone) {
  if (context.mounted) MessageBox.show(context, message, tone);
};

/// Blocks the app over [context] while a quick fix changes the project's
/// files, showing the step it is at and letting the user cancel it.
QuickFixBlocker quickFixBlockerOver(BuildContext context) =>
    (title, run) => BlockingTaskDialog.run(
      context,
      title: title,
      step: QuickFixRunner.analyzingStep,
      run: run,
    );

/// Applies [fix] to the open project, confirmed, blocking the app and
/// told about over [context], wherever a button offers it: an issue's
/// quick fixes, the Packages section's Upgrade.
void applyQuickFix(BuildContext context, WidgetRef ref, QuickFix fix) {
  ref
      .read(quickFixControllerProvider)
      .apply(
        fix,
        confirm: confirmQuickFixOver(context),
        notify: quickFixNoticesOver(context),
        block: quickFixBlockerOver(context),
      );
}
