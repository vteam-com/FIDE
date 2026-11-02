import 'package:fide/constants/core_constants.dart';

/// The meaning of a status shown to the user, giving every badge, toast
/// and indicator of that meaning the same wording; `StatusToneStyle` gives
/// it the same icon and color.
enum StatusTone {
  /// Something finished or is available.
  success(
    messageLabel: 'Success message',
    messageDuration: AppDuration.messageSuccess,
  ),

  /// Something needs attention but still works.
  warning(
    messageLabel: 'Warning message',
    messageDuration: AppDuration.messageWarning,
  ),

  /// Something failed or is missing; its messages can be copied, as they
  /// are the ones users paste into reports.
  error(
    messageLabel: 'Error message',
    messageDuration: AppDuration.messageError,
    messageCopyable: true,
  ),

  /// Neutral information.
  info(
    messageLabel: 'Information message',
    messageDuration: AppDuration.messageInfo,
  ),

  /// No particular meaning.
  neutral(
    messageLabel: 'Information message',
    messageDuration: AppDuration.messageInfo,
  );

  const StatusTone({
    required this.messageLabel,
    required this.messageDuration,
    this.messageCopyable = false,
  });

  /// Whether a message of this tone offers to copy its text.
  final bool messageCopyable;

  /// How long a message of this tone stays on screen.
  final Duration messageDuration;

  /// What a message of this tone is, for its tooltip and screen readers.
  final String messageLabel;
}
