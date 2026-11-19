import 'package:fide/constants/core_constants.dart';
import 'package:fide/models/locale_number.dart';

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
    if (days < DateTime.daysPerWeek) return _ago(days, 'day');
    if (days < AppMetric.daysPerMonth) {
      return _ago(days ~/ DateTime.daysPerWeek, 'week');
    }
    if (days < AppMetric.daysPerYear) {
      return _ago(days ~/ AppMetric.daysPerMonth, 'month');
    }
    return _ago(days ~/ AppMetric.daysPerYear, 'year');
  }

  /// This moment's date and time to the second, such as
  /// `2024-05-01 14:03:27`.
  String get toSecond => toString().split(_fractionSeparator).first;

  /// What separates the seconds from their fraction in [toString].
  static const String _fractionSeparator = '.';

  /// `[count] [unit]s ago`, singular when [count] is one.
  static String _ago(int count, String unit) => '${count.count(unit)} ago';
}
