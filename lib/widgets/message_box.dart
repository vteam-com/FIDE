import 'package:fide/constants/constants.dart';
import 'package:fide/models/action_outcome.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/widgets/app_text_field.dart';
import 'package:fide/widgets/message_widget.dart';
import 'package:fide/widgets/primary_button.dart';
import 'package:fide/widgets/secondary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Convenience methods for showing messages
/// Represents `MessageBox`.
class MessageBox {
  /// [copyToClipboard]'s confirmation unless it names what was copied.
  static const String copiedConfirmation = 'Copied to clipboard';

  /// Shows an error message overlay, with a button to copy the text.
  static void showError(BuildContext context, String message) {
    show(context, message, StatusTone.error);
  }

  /// Shows an informational message overlay.
  static void showInfo(BuildContext context, String message) {
    show(context, message, StatusTone.info);
  }

  /// Shows a success message overlay.
  static void showSuccess(BuildContext context, String message) {
    show(context, message, StatusTone.success);
  }

  /// Shows a warning message overlay.
  static void showWarning(BuildContext context, String message) {
    show(context, message, StatusTone.warning);
  }

  /// Copies [text] to the clipboard and confirms it with [confirmation].
  static void copyToClipboard(
    BuildContext context,
    String text, {
    String confirmation = copiedConfirmation,
  }) {
    Clipboard.setData(ClipboardData(text: text));
    showSuccess(context, confirmation);
  }

  /// Shows read-only [content] under [title] with a Close button before
  /// any extra [actions]; [content] scrolls unless [scrollable] is false, for
  /// content that sizes and scrolls itself.
  static Future<void> showDetails(
    BuildContext context, {
    required Widget title,
    required Widget content,
    List<Widget> actions = const [],
    bool scrollable = true,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: title,
        content: scrollable ? SingleChildScrollView(child: content) : content,
        actions: [
          SecondaryButton(
            onPressed: () => Navigator.of(context).pop(),
            label: 'Close',
          ),
          ...actions,
        ],
      ),
    );
  }

  /// Asks for a line of text, starting from [initialText]; resolves to the
  /// trimmed text when [confirmLabel] is pressed, null on Cancel or
  /// dismissal; [keyboardType] picks the on-screen keyboard.
  static Future<String?> promptForText(
    BuildContext context, {
    required String title,
    required String labelText,
    required String hintText,
    required String confirmLabel,
    String initialText = '',
    TextInputType? keyboardType,
  }) async {
    // Not disposed here: the dialog's field still uses it while the route
    // animates out after showDialog returns
    final controller = TextEditingController(text: initialText);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: AppTextField(
          controller: controller,
          labelText: labelText,
          hintText: hintText,
          keyboardType: keyboardType,
          autofocus: true,
          onSubmitted: (text) => Navigator.of(context).pop(text.trim()),
        ),
        actions: [
          SecondaryButton(
            onPressed: () => Navigator.of(context).pop(),
            label: 'Cancel',
          ),
          PrimaryButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            label: confirmLabel,
          ),
        ],
      ),
    );
  }

  /// Asks the user to confirm a destructive action; resolves true only when
  /// [confirmLabel] is pressed, false on Cancel or dismissal.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          SecondaryButton(
            onPressed: () => Navigator.of(context).pop(false),
            label: 'Cancel',
          ),
          PrimaryButton(
            onPressed: () => Navigator.of(context).pop(true),
            destructive: true,
            label: confirmLabel,
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// Tells the user how an action ended, in the tone of [outcome].
  static void showOutcome(BuildContext context, ActionOutcome outcome) =>
      show(context, outcome.message, outcome.tone);

  /// Presents an overlay message bar of [tone], the one every message of
  /// that meaning gets; the bar removes itself once closed or after the
  /// tone's [StatusTone.messageDuration].
  static void show(BuildContext context, String message, StatusTone tone) {
    late final OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.medium,
        left: 0,
        right: 0,
        child: MessageWidget(
          message: message,
          type: tone,
          // Removed rather than left faded out: an invisible bar would
          // still catch the clicks meant for what lies under it
          onClose: () {
            if (overlayEntry.mounted) overlayEntry.remove();
          },
        ),
      ),
    );
    // The navigator's own context (navigatorKey.currentContext) sits above
    // the overlay it builds, so take the overlay from the navigator first
    (Navigator.maybeOf(context)?.overlay ?? Overlay.of(context)).insert(
      overlayEntry,
    );
  }
}
