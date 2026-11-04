part of 'cocoa_pods_migration.dart';

/// A pod a Podfile adds by hand, which no plugin manages.
class HandAddedPod {
  /// Creates the pod [name] added at [line] of the Podfile at [podfile].
  const HandAddedPod({
    required this.podfile,
    required this.name,
    required this.line,
  });

  /// 1-based Podfile line.
  final int line;

  /// The pod's name.
  final String name;

  /// Absolute path of the Podfile.
  final String podfile;
}
