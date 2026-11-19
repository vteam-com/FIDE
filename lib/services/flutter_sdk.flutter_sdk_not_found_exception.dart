part of 'flutter_sdk.dart';

/// Thrown when no Flutter SDK is found to analyze a project with.
class FlutterSdkNotFoundException implements Exception {
  /// Creates the exception.
  const FlutterSdkNotFoundException();

  @override
  String toString() => 'Flutter SDK not found';
}
