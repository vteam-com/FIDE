import 'package:fide/providers/ai_service.dart';
import 'package:fide/providers/file_system_watcher.dart';
import 'package:fide/providers/git_service.dart';
import 'package:fide/providers/localization_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides the shared [GitService]; override in tests to stub Git commands.
final gitServiceProvider = Provider<GitService>((_) => GitService());

/// Provides the shared [AIService]; override in tests to stub Ollama calls.
final aiServiceProvider = Provider<AIService>((_) => AIService());

/// Provides the shared [LocalizationService] for project l10n setup.
final localizationServiceProvider = Provider<LocalizationService>(
  (_) => LocalizationService(),
);

/// Provides the shared [ArbService] for reading and writing ARB files.
final arbServiceProvider = Provider<ArbService>((_) => ArbService());

/// Provides the [FileSystemWatcher] used for incremental project tree updates.
final fileSystemWatcherProvider = Provider<FileSystemWatcher>((ref) {
  final watcher = FileSystemWatcher();
  ref.onDispose(watcher.dispose);
  return watcher;
});
