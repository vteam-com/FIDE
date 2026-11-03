part of 'app_icon_review.dart';

/// One platform's app icons: its slots, grouped as Xcode shows them, and
/// the problems found with them.
class AppIconPlatformReview {
  /// The platform's id, its folder name such as `ios`.
  final String id;

  /// The problems with the platform's icons.
  final List<AppIconProblem> issues;

  /// The platform's name, such as `iOS`.
  final String label;

  /// The platform's slots, in the order its configuration lists them.
  final List<AppIconSlotInfo> slots;

  /// Creates the review of one platform.
  const AppIconPlatformReview({
    required this.id,
    required this.label,
    required this.issues,
    required this.slots,
  });

  /// The slots by group, in the order the groups first appear.
  Map<String, List<AppIconSlotInfo>> get groups {
    final groups = <String, List<AppIconSlotInfo>>{};
    for (final slot in slots) {
      groups.putIfAbsent(slot.group, () => []).add(slot);
    }
    return groups;
  }

  /// Whether the platform's icons have a problem.
  bool get hasIssues => issues.isNotEmpty;
}
