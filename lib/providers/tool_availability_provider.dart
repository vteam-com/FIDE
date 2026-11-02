import 'package:fide/models/tool_availability.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shown for an installed Flutter whose output has no version.
const String _unknownVersion = 'Unknown';

/// Probes Flutter, Git and Ollama together for the new-project wizard, once
/// per visit.
final toolAvailabilityProvider = FutureProvider.autoDispose<ToolAvailability>((
  ref,
) async {
  final ollama = ref.read(ollamaInstallerProvider);
  Future<bool> ollamaReady() async {
    try {
      return await ollama.isInstalled() && await ollama.isRunning();
    } catch (_) {
      return false;
    }
  }

  final (flutter, git, ollamaAvailable) = await (
    ref.read(flutterSdkProvider).versions(),
    ref.read(gitServiceProvider).version(),
    ollamaReady(),
  ).wait;
  return ToolAvailability(
    flutterAvailable: flutter != null,
    flutterVersion: flutter == null ? null : flutter.flutter ?? _unknownVersion,
    gitVersion: git,
    ollamaAvailable: ollamaAvailable,
  );
});
