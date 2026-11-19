import 'dart:async';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/action_outcome.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/theme/app_theme.dart';
import 'package:fide/widgets/app_text_field.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:fide/widgets/primary_button.dart';
import 'package:fide/widgets/secondary_button.dart';
import 'package:fide/widgets/status_tone_style.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

part 'message_box.copy_button.dart';
part 'message_box.message_widget.dart';

/// How the app talks to the user: the message bars telling how an action
/// ended, the dialogs showing details, asking for text or a confirmation,
/// and copies to the clipboard, confirmed by a bar.
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

  /// Shows [content] under [title] with a Close button before any extra
  /// [actions]; [content] scrolls unless [scrollable] is false, for
  /// content that sizes and scrolls itself. Resolves to what [content]
  /// pops the dialog with, null when closed.
  static Future<T?> showDetails<T>(
    BuildContext context, {
    required Widget title,
    required Widget content,
    List<Widget> actions = const [],
    bool scrollable = true,
  }) {
    return showDialog<T>(
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
  /// tone's [StatusTone.messageDuration]. Bars shown together stack, the
  /// newest at the bottom, so none covers another, such as the
  /// confirmation of copying a message under that message.
  static void show(BuildContext context, String message, StatusTone tone) {
    // The navigator's own context (navigatorKey.currentContext) sits above
    // the overlay it builds, so take the overlay from the navigator first
    final overlay = Navigator.maybeOf(context)?.overlay ?? Overlay.of(context);
    (_stacks[overlay] ??= _MessageStack(overlay)).add(message, tone);
  }

  /// The message bars shown in each overlay.
  static final Expando<_MessageStack> _stacks = Expando();
}

/// One message shown by [MessageBox.show], a bar of its own even when
/// another says the same.
class _Message {
  /// Creates the message [text] in the tone of [tone].
  _Message(this.text, this.tone);

  /// The text shown.
  final String text;

  /// The tone giving the bar its icon, color and duration.
  final StatusTone tone;
}

/// The message bars shown in one [overlay], stacked upward from its
/// bottom edge in the order they came.
class _MessageStack {
  /// Creates the empty stack of [overlay].
  _MessageStack(this.overlay);

  /// The overlay the bars show in.
  final OverlayState overlay;

  /// The bars shown, oldest first.
  final ValueNotifier<List<_Message>> _messages = ValueNotifier(const []);

  /// The overlay entry holding the bars, while there are any.
  OverlayEntry? _entry;

  /// Shows [text] in the tone of [tone] under the bars already shown.
  void add(String text, StatusTone tone) {
    _messages.value = [..._messages.value, _Message(text, tone)];
    if (_entry != null) return;
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.medium,
        left: 0,
        right: 0,
        child: ValueListenableBuilder(
          valueListenable: _messages,
          builder: (_, messages, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final message in messages)
                MessageWidget(
                  // Keeps each bar's own fade and timer as others go
                  key: ObjectKey(message),
                  message: message.text,
                  type: message.tone,
                  onClose: () => _remove(message),
                ),
            ],
          ),
        ),
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  /// Takes [message] off the stack, and the stack off the overlay once
  /// empty: an invisible bar would still catch the clicks meant for what
  /// lies under it.
  void _remove(_Message message) {
    _messages.value = [
      for (final shown in _messages.value)
        if (!identical(shown, message)) shown,
    ];
    if (_messages.value.isNotEmpty) return;
    final entry = _entry;
    _entry = null;
    if (entry != null && entry.mounted) entry.remove();
  }
}
