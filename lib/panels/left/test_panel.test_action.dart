part of 'test_panel.dart';

/// Represents `TestAction`.
class TestAction {
  final String id;
  final String title;
  final String description;
  final String details;
  final IconData icon;
  final Color color;
  final Function() action;
  TestStatus status;

  TestAction({
    required this.id,
    required this.title,
    required this.description,
    required this.details,
    required this.icon,
    required this.color,
    required this.action,
    this.status = TestStatus.idle,
  });
}
