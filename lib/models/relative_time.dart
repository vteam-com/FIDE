import 'package:fide/constants/constants.dart';

/// Describes a past moment relative to now, the way people say it.
extension RelativeTime on DateTime {
  /// `now`, `5 min ago`, `today`, `yesterday`, `4 days ago`, `2 weeks ago`,
  /// `3 months ago` or `1 year ago`, measured against [now] (the current
  /// time when omitted).
  String timeAgo([DateTime? now]) {
    final current = now ?? DateTime.now();
    final elapsed = current.difference(this);
    if (elapsed.inMinutes < 1) return 'now';
    if (elapsed.inHours < 1) return '${elapsed.inMinutes} min ago';

    // Whole calendar days, so last night reads as yesterday
    final days = DateTime(
      current.year,
      current.month,
      current.day,
    ).difference(DateTime(year, month, day)).inDays;
    if (days == 0) return 'today';
    if (days == 1) return 'yesterday';
    if (days < DateTime.daysPerWeek) return '$days days ago';
    if (days < AppMetric.daysPerMonth) {
      return _plural(days ~/ DateTime.daysPerWeek, 'week');
    }
    if (days < AppMetric.daysPerYear) {
      return _plural(days ~/ AppMetric.daysPerMonth, 'month');
    }
    return _plural(days ~/ AppMetric.daysPerYear, 'year');
  }

  /// `[count] [unit]s ago`, singular when [count] is one.
  static String _plural(int count, String unit) =>
      '$count $unit${count == 1 ? '' : 's'} ago';
}
