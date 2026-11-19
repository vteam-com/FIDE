import 'package:fide/models/tool_availability.dart';
import 'package:fide/models/tool_version.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Probes Flutter and Git together for the new-project wizard, once per
/// visit.
final toolAvailabilityProvider = FutureProvider.autoDispose<ToolAvailability>((
  ref,
) async {
  final (flutter, git) = await (
    ref.read(flutterSdkProvider).versions(),
    ref.read(gitServiceProvider).version(),
  ).wait;
  return ToolAvailability(
    flutterAvailable: flutter != null,
    flutterVersion: flutter == null ? null : flutter.flutter ?? unknownVersion,
    gitVersion: git,
  );
});
