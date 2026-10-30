import 'package:fide/models/relative_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 30, 15);

  test('timeAgo reads recent moments as now, minutes or today', () {
    expect(now.timeAgo(now), 'now');
    expect(now.subtract(const Duration(minutes: 5)).timeAgo(now), '5 min ago');
    expect(DateTime(2026, 10, 30, 1).timeAgo(now), 'today');
  });

  test('timeAgo counts calendar days, then weeks, months and years', () {
    expect(DateTime(2026, 10, 29, 23).timeAgo(now), 'yesterday');
    expect(DateTime(2026, 10, 26).timeAgo(now), '4 days ago');
    expect(DateTime(2026, 10, 23).timeAgo(now), '1 week ago');
    expect(DateTime(2026, 10, 9).timeAgo(now), '3 weeks ago');
    expect(DateTime(2026, 8, 30).timeAgo(now), '2 months ago');
    expect(DateTime(2024, 10, 1).timeAgo(now), '2 years ago');
  });
}
