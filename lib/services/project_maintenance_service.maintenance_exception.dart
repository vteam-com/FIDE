part of 'project_maintenance_service.dart';

/// Why a [ProjectMaintenanceService] chore could not finish.
class MaintenanceException implements Exception {
  /// Creates an exception explained by [message].
  const MaintenanceException(this.message);

  /// What prevented the chore, for the user.
  final String message;

  @override
  String toString() => message;
}
