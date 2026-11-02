import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/git_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

/// Added/removed line counts of the file at an absolute path against HEAD,
/// as the editor's tabs show them; null when the path is empty or not in a
/// Git repository. Read again after each save; Git actions invalidate it.
final gitDiffStatsProvider = FutureProvider.autoDispose
    .family<GitDiffStats?, String>((ref, filePath) async {
      ref.watch(savedFilesRevisionProvider);
      if (filePath.isEmpty) return null;
      final git = ref.read(gitServiceProvider);
      final folder = p.dirname(filePath);
      if (!await git.isGitRepository(folder)) return null;
      return git.getFileDiffStats(folder, filePath);
    }, retry: (_, _) => null);
