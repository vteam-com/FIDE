// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

// Models
import '../../models/document_state.dart';

// Providers
import '../../providers/app_providers.dart';

// Utils
import '../../utils/message_helper.dart';

// Widgets
import '../../widgets/status_indicator.dart';

class InfoPanel extends ConsumerStatefulWidget {
  const InfoPanel({super.key});

  @override
  ConsumerState<InfoPanel> createState() => _InfoPanelState();
}

class _InfoPanelState extends ConsumerState<InfoPanel> {
  bool _isRefreshing = false;
  bool _checkingOutdated = false;
  bool _upgrading = false;
  bool _dependenciesExpanded = false;
  Process? _currentProcess;
  final StringBuffer _outputBuffer = StringBuffer();

  @override
  void initState() {
    super.initState();
    _analyzeProject();
  }

  @override
  void dispose() {
    _currentProcess?.kill();
    super.dispose();
  }

  Future<void> _analyzeProject() async {
    final currentProjectPath = ref.read(currentProjectPathProvider);
    if (currentProjectPath == null) return;

    setState(() => _isRefreshing = true);
    _outputBuffer.clear();

    try {
      final metrics = await _gatherProjectMetrics(currentProjectPath);
      await ref
          .read(projectMetricsProvider.notifier)
          .updateMetrics(currentProjectPath, metrics);
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRefreshing = false);
        MessageHelper.showError(context, 'Failed to analyze project: $e');
      }
    }
  }

  Future<Map<String, dynamic>> _gatherProjectMetrics(String projectPath) async {
    final metrics = <String, dynamic>{};

    // Basic project info
    final pubspecFile = File('$projectPath/pubspec.yaml');
    if (pubspecFile.existsSync()) {
      final content = pubspecFile.readAsStringSync();
      final lines = content.split('\n');

      for (final line in lines) {
        if (line.trim().startsWith('name:') &&
            !line.trim().startsWith('  name:')) {
          metrics['name'] = line.split(':').last.trim();
        }
        if (line.trim().startsWith('version:')) {
          metrics['version'] = line.split(':').last.trim();
        }
        if (line.trim().startsWith('description:')) {
          metrics['description'] = line.split(':').last.trim();
        }
      }

      // Parse dependencies
      final yamlDoc = loadYamlDocument(content);
      final yamlMap = yamlDoc.contents as YamlMap;

      final deps = yamlMap['dependencies'] as YamlMap?;
      if (deps != null) {
        final dependencies = <String, String>{};
        deps.forEach((key, value) {
          if (value is String) {
            dependencies[key as String] = value;
          } else if (value is YamlMap && value['sdk'] == 'flutter') {
            dependencies[key as String] = 'Flutter SDK';
          } else {
            dependencies[key as String] = 'Complex dependency';
          }
        });
        metrics['dependencies'] = dependencies;
      }

      final devDeps = yamlMap['dev_dependencies'] as YamlMap?;
      if (devDeps != null) {
        final devDependencies = <String, String>{};
        devDeps.forEach((key, value) {
          if (value is String) {
            devDependencies[key as String] = value;
          } else if (value is YamlMap && value['sdk'] == 'flutter') {
            devDependencies[key as String] = 'Flutter SDK';
          } else {
            devDependencies[key as String] = 'Complex dependency';
          }
        });
        metrics['devDependencies'] = devDependencies;
      }
    }

    // File stats
    await _analyzeFileStats(projectPath, metrics);

    // Directory structure
    await _analyzeDirectoryStructure(projectPath, metrics);

    // Health indicators
    await _analyzeHealthIndicators(projectPath, metrics);

    // Generate quality score
    _calculateQualityScore(metrics);

    return metrics;
  }

  Future<void> _analyzeFileStats(
    String projectPath,
    Map<String, dynamic> metrics,
  ) async {
    final stats = <String, int>{};
    final dir = Directory(projectPath);

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final extension = entity.path.split('.').last.toLowerCase();
        stats[extension] = (stats[extension] ?? 0) + 1;
      }
    }

    metrics['fileStats'] = stats;
    metrics['totalFiles'] = stats.values.fold(0, (sum, count) => sum + count);
  }

  Future<void> _analyzeDirectoryStructure(
    String projectPath,
    Map<String, dynamic> metrics,
  ) async {
    final dir = Directory(projectPath);
    final structure = <String, int>{};

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is Directory) {
        final pathSegments = entity.path
            .replaceFirst(projectPath, '')
            .split('/');
        if (pathSegments.length >= 2) {
          final category = pathSegments[1];
          if ([
            'android',
            'ios',
            'web',
            'windows',
            'linux',
            'macos',
            'lib',
            'test',
          ].contains(category)) {
            structure[category] = (structure[category] ?? 0) + 1;
          }
        }
      }
    }

    metrics['directoryStructure'] = structure;
  }

  Future<void> _analyzeHealthIndicators(
    String projectPath,
    Map<String, dynamic> metrics,
  ) async {
    final indicators = <String, dynamic>{};

    // Check for pubspec.lock existence
    indicators['hasPubspecLock'] = File(
      '$projectPath/pubspec.lock',
    ).existsSync();

    // Check for build warning/error logs
    final buildDir = Directory('$projectPath/build');
    if (buildDir.existsSync()) {
      int warningLogs = 0;
      int errorLogs = 0;

      await for (final entity in buildDir.list(recursive: true)) {
        if (entity is File && entity.path.endsWith('.log')) {
          final content = entity.readAsStringSync().toLowerCase();
          if (content.contains('error')) errorLogs++;
          if (content.contains('warning')) warningLogs++;
        }
      }

      indicators['buildWarnings'] = warningLogs;
      indicators['buildErrors'] = errorLogs;
    }

    // Check for large files (>10MB)
    final largeFiles = <String>[];
    await for (final entity in Directory(
      projectPath,
    ).list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          final size = await entity.length();
          if (size > 10 * 1024 * 1024) {
            // 10MB
            largeFiles.add(entity.path.replaceFirst(projectPath, ''));
          }
        } catch (e) {
          // Skip files we can't read (like broken symlinks)
          continue;
        }
      }
    }
    indicators['largeFiles'] = largeFiles;

    // Check for outdated pubspec.yaml dependencies (simplified check)
    final pubspecFile = File('$projectPath/pubspec.yaml');
    if (pubspecFile.existsSync()) {
      final content = pubspecFile.readAsStringSync();
      indicators['hasDependencies'] = content.contains('dependencies:');
    }

    metrics['healthIndicators'] = indicators;
  }

  void _calculateQualityScore(Map<String, dynamic> metrics) {
    int score = 100;

    final healthIndicators =
        metrics['healthIndicators'] as Map<String, dynamic>?;

    if (healthIndicators == null) return;

    // Deduct for missing pubspec.lock
    if (!(healthIndicators['hasPubspecLock'] ?? false)) {
      score -= 20;
    }

    // Deduct for build errors
    final buildErrors = (healthIndicators['buildErrors'] ?? 0) as int;
    score -= (buildErrors * 10).clamp(0, 50);

    // Deduct for warnings
    final buildWarnings = (healthIndicators['buildWarnings'] ?? 0) as int;
    score -= (buildWarnings * 2).clamp(0, 20);

    // Deduct for large files
    final largeFiles = healthIndicators['largeFiles'] as List?;
    if (largeFiles != null && largeFiles.length > 3) {
      score -= 10;
    }

    metrics['qualityScore'] = score.clamp(0, 100);
  }

  Color _getScoreColor(int score) {
    if (score < 50) return Colors.red.shade700;
    if (score < 80) return Colors.orange.shade700;
    return Colors.green.shade700;
  }

  void _showScoreDetails(
    BuildContext context,
    Map<String, dynamic> projectMetrics,
  ) {
    final healthIndicators =
        projectMetrics['healthIndicators'] as Map<String, dynamic>?;
    final isMissingPubspecLock =
        !(healthIndicators?['hasPubspecLock'] ?? false);
    final buildErrors = (healthIndicators?['buildErrors'] ?? 0) as int;
    final buildWarnings = (healthIndicators?['buildWarnings'] ?? 0) as int;
    final largeFiles = healthIndicators?['largeFiles'] as List?;
    final hasLargeFiles = largeFiles != null && largeFiles.length > 3;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quality Score Breakdown'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Starting Score: 100 points',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Deductions:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _buildDeductionItem(
                'Missing pubspec.lock',
                -20,
                isMissingPubspecLock,
                context,
              ),
              _buildDeductionItem(
                'Build errors (max 50 points)',
                -(buildErrors * 10).clamp(0, 50),
                buildErrors > 0,
                context,
              ),
              _buildDeductionItem(
                'Build warnings (max 20 points)',
                -(buildWarnings * 2).clamp(0, 20),
                buildWarnings > 0,
                context,
              ),
              _buildDeductionItem(
                'Large files (>3 files over 10MB)',
                -10,
                hasLargeFiles,
                context,
              ),
              const Divider(height: 24),
              Text(
                'Final Score: ${projectMetrics['qualityScore']}/100',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Score ranges:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                '• Green (80-100): Good project health\n'
                '• Orange (50-79): Needs attention\n'
                '• Red (0-49): Critical issues',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeductionItem(
    String label,
    int points,
    bool active,
    BuildContext context,
  ) {
    return Row(
      children: [
        Icon(
          active ? Icons.remove : Icons.check,
          size: 14,
          color: active ? Colors.red.shade600 : Colors.green.shade600,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: active
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              decoration: active
                  ? TextDecoration.none
                  : TextDecoration.lineThrough,
            ),
          ),
        ),
        Text(
          active ? '$points pts' : 'No deduction',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: active ? Colors.red.shade600 : Colors.green.shade600,
          ),
        ),
      ],
    );
  }

  Future<void> _performFullCleanup() async {
    final currentProjectPath = ref.read(currentProjectPathProvider);
    if (currentProjectPath == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Full Project Cleanup'),
        content: const Text(
          'This will:\n• Flutter clean\n• Remove build artifacts\n• Clear pub cache\n• Reset CocoaPods (if macOS)\n\nContinue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isRefreshing = true);

    try {
      // Flutter clean
      await _runCommand('flutter', [
        'clean',
      ], workingDirectory: currentProjectPath);

      // Remove build directory
      final buildDir = Directory('$currentProjectPath/build');
      if (buildDir.existsSync()) {
        await buildDir.delete(recursive: true);
      }

      // Clear Flutter pub cache
      await _runCommand('flutter', ['pub', 'cache', 'repair']);

      // Clean Android if exists
      final androidDir = Directory('$currentProjectPath/android');
      if (androidDir.existsSync()) {
        await _runCommand('./gradlew', [
          'clean',
        ], workingDirectory: '$currentProjectPath/android');
      }

      // Clean iOS/macOS CocoaPods if macOS
      if (Platform.isMacOS) {
        final iosDir = Directory('$currentProjectPath/ios');
        if (iosDir.existsSync()) {
          await _runCommand('pod', [
            'install',
            '--repo-update',
          ], workingDirectory: '$currentProjectPath/ios');
        }
        final macosDir = Directory('$currentProjectPath/macos');
        if (macosDir.existsSync()) {
          await _runCommand('pod', [
            'install',
            '--repo-update',
          ], workingDirectory: '$currentProjectPath/macos');
        }
      }

      // Re-analyze project
      await _analyzeProject();

      if (mounted) {
        MessageHelper.showSuccess(context, 'Full project cleanup completed!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRefreshing = false);
        MessageHelper.showError(context, 'Cleanup failed: $e');
      }
    }
  }

  void _openPubspecYaml() {
    try {
      final currentProjectPath = ref.read(currentProjectPathProvider);
      if (currentProjectPath == null) return;

      final pubspecPath = '$currentProjectPath/pubspec.yaml';
      if (!File(pubspecPath).existsSync()) {
        MessageHelper.showError(context, 'pubspec.yaml not found');
        return;
      }

      final documents = ref.read(openDocumentsProvider);
      final existingIndex = documents.indexWhere(
        (doc) => doc.filePath == pubspecPath,
      );

      if (existingIndex == -1) {
        // Not open, add it
        final newDocument = DocumentState(filePath: pubspecPath);
        final updatedDocuments = [...documents, newDocument];
        ref.read(openDocumentsProvider.notifier).state = updatedDocuments;
        ref.read(activeDocumentIndexProvider.notifier).state =
            updatedDocuments.length - 1;
      } else {
        // Already open, switch to it
        ref.read(activeDocumentIndexProvider.notifier).state = existingIndex;
      }
    } catch (e) {
      MessageHelper.showError(context, 'Failed to open pubspec.yaml: $e');
    }
  }

  Future<void> _runCommand(
    String cmd,
    List<String> args, {
    String? workingDirectory,
  }) async {
    final process = await Process.start(
      cmd,
      args,
      workingDirectory: workingDirectory,
      runInShell: true,
    );

    await process.stdout.transform(utf8.decoder).drain();
    await process.stderr.transform(utf8.decoder).drain();

    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      throw 'Command failed with exit code $exitCode';
    }
  }

  Future<void> _checkOutdated() async {
    final currentProjectPath = ref.read(currentProjectPathProvider);
    if (currentProjectPath == null) return;

    setState(() => _checkingOutdated = true);

    try {
      final result = await Process.run('flutter', [
        'pub',
        'outdated',
      ], workingDirectory: currentProjectPath);

      if (result.exitCode == 0) {
        final output = result.stdout as String;
        final parsed = _parseOutdated(output);

        final currentMetrics = ref.read(projectMetricsProvider);
        final updatedMetrics = Map<String, dynamic>.from(currentMetrics)
          ..['outdated'] = parsed;

        ref
            .read(projectMetricsProvider.notifier)
            .updateMetrics(currentProjectPath, updatedMetrics);

        if (mounted) {
          MessageHelper.showSuccess(context, 'Outdated check completed');
        }
      } else {
        if (mounted) {
          MessageHelper.showError(
            context,
            'Failed to check outdated: ${result.stderr}',
          );
        }
      }

      if (mounted) setState(() => _checkingOutdated = false);
    } catch (e) {
      if (mounted) {
        setState(() => _checkingOutdated = false);
        MessageHelper.showError(context, 'Error checking outdated: $e');
      }
    }
  }

  Map<String, dynamic> _parseOutdated(String output) {
    final lines = output.split('\n');
    final outdated = <String, dynamic>{};

    for (String line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      final parts = line.split(RegExp(r'\s+'));
      if (parts.length >= 5 && parts[0] != 'Package' && parts[0] != '---') {
        final package = parts[0];
        final current = parts[1];
        final upgradable = parts[2];
        final resolvable = parts[3];
        outdated[package] = {
          'current': current,
          'upgradable': upgradable,
          'resolvable': resolvable,
          'latest': parts.length > 4 ? parts[4] : '',
        };
      }
    }

    return outdated;
  }

  Future<void> _upgradePackages() async {
    final currentProjectPath = ref.read(currentProjectPathProvider);
    if (currentProjectPath == null) return;

    setState(() => _upgrading = true);
    try {
      // 1. Run flutter pub outdated --json
      final result = await Process.run('flutter', [
        'pub',
        'outdated',
        '--json',
      ], workingDirectory: currentProjectPath);
      if (result.exitCode != 0) {
        if (mounted) {
          MessageHelper.showError(
            context,
            'Failed to check outdated: ${result.stderr}',
          );
        }
        return;
      }
      // 2. Parse the JSON result
      final outdatedJson = result.stdout is String
          ? result.stdout as String
          : utf8.decode(result.stdout as List<int>);

      final dynamic outdatedData = json.decode(outdatedJson);

      if (outdatedData is! Map<String, dynamic>) {
        if (mounted) {
          MessageHelper.showError(
            context,
            'Invalid JSON response from flutter pub outdated: expected Map, got ${outdatedData.runtimeType}',
          );
        }
        return;
      }

      final Map<String, dynamic> outdatedDataMap = outdatedData;

      // Handle the array format: [{"package": "name", "kind": "direct", "current": {...}, "resolvable": {...}}, ...]
      final packagesRaw = outdatedDataMap['packages'];
      if (packagesRaw is! List) {
        if (mounted) {
          MessageHelper.showError(
            context,
            'Expected packages to be an array, got ${packagesRaw?.runtimeType}',
          );
        }
        return;
      }

      final packages = packagesRaw;

      if (mounted) {
        MessageHelper.showInfo(
          context,
          'Found ${packages.length} packages to check',
        );
      }

      // 3. Load pubspec.yaml and create a YamlEditor
      final pubspecFile = File('$currentProjectPath/pubspec.yaml');
      if (!pubspecFile.existsSync()) {
        if (mounted) {
          MessageHelper.showError(context, 'pubspec.yaml not found');
        }
        return;
      }
      final pubspecContent = await pubspecFile.readAsString();
      final yamlEditor = YamlEditor(pubspecContent);

      // 4. For each package in the array, check if it's upgradeable
      bool changed = false;
      final List<String> updatedPackages = [];
      for (final pkg in packages) {
        // Each pkg is a Map like: {"package": "name", "kind": "direct", "current": {...}, "resolvable": {...}}
        final pkgMap = pkg is Map<String, dynamic> ? pkg : null;
        if (pkgMap == null) continue;

        final packageName = pkgMap['package'] as String?;
        if (packageName == null) continue;

        // Only update direct and dev dependencies
        final kind = pkgMap['kind'] as String?;
        if (kind != 'direct' && kind != 'dev') continue;

        final resolvable = pkgMap['resolvable'];
        final resolvableMap = resolvable is Map<String, dynamic>
            ? resolvable
            : null;
        if (resolvableMap == null) continue;

        final newVersion = resolvableMap['version']?.toString();
        if (newVersion == null || newVersion.isEmpty) continue;

        final current = pkgMap['current'];
        final currentMap = current is Map<String, dynamic> ? current : null;
        final currentVersion = currentMap?['version']?.toString();

        // If no current version or same as new version, skip
        if (currentVersion == null || currentVersion == newVersion) {
          continue;
        }

        // Update dependencies or dev_dependencies
        final depPath = ['dependencies', packageName];
        final devDepPath = ['dev_dependencies', packageName];
        final pathToUpdate = kind == 'direct' ? depPath : devDepPath;

        try {
          // Parse at the path to make sure it exists
          yamlEditor.parseAt(pathToUpdate).value;
          // Update with new version
          yamlEditor.update(pathToUpdate, newVersion);
          changed = true;
          updatedPackages.add('$packageName: $currentVersion → $newVersion');
        } catch (e) {
          // Continue to next package if this one fails
          continue;
        }
      }

      // 5. Write modified YAML back to pubspec.yaml
      if (changed) {
        await pubspecFile.writeAsString(yamlEditor.toString());
      }

      // 6. Run flutter pub get
      await _runCommand('flutter', [
        'pub',
        'get',
      ], workingDirectory: currentProjectPath);

      // 7. Re-analyze the project
      await _analyzeProject();

      // 8. Show snackbar
      if (mounted) {
        if (changed) {
          MessageHelper.showSuccess(
            context,
            'Packages upgraded to compatible versions!',
          );
        } else {
          MessageHelper.showInfo(
            context,
            'All packages already up to date with compatible versions.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        MessageHelper.showError(context, 'Error upgrading packages: $e');
      }
    } finally {
      if (mounted) setState(() => _upgrading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentProjectPath = ref.watch(currentProjectPathProvider);
    final projectMetrics = ref.watch(projectMetricsProvider);

    if (currentProjectPath == null) {
      return const Center(
        child: Text('No project loaded', style: TextStyle(color: Colors.grey)),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            // Header with refresh button
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  projectMetrics['name'] as String? ?? 'Unknown Project',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text(
                    'v${projectMetrics['version'] as String? ?? '< no version >'}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Spacer(),
                IconButton(
                  onPressed: _openPubspecYaml,
                  icon: const Icon(Icons.edit_note, size: 16),
                ),
                Spacer(),
                if (projectMetrics['qualityScore'] != null)
                  GestureDetector(
                    onTap: () => _showScoreDetails(context, projectMetrics),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getScoreColor(
                          projectMetrics['qualityScore'] as int,
                        ).withOpacity(0.2),
                        border: Border.all(
                          color: _getScoreColor(
                            projectMetrics['qualityScore'] as int,
                          ),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${projectMetrics['qualityScore']}%',
                        style: TextStyle(
                          color: _getScoreColor(
                            projectMetrics['qualityScore'] as int,
                          ),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            Text(
              projectMetrics['description'] as String? ?? '< no description >',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.visible,
            ),

            // Dependencies
            if (projectMetrics['dependencies'] != null ||
                projectMetrics['devDependencies'] != null) ...[
              _buildDependenciesCard(projectMetrics),
              const SizedBox(height: 16),
            ],

            // Actions
            _buildActionsCard(projectMetrics),

            // File Statistics
            if (projectMetrics['fileStats'] != null) ...[
              _buildFileStatsCard(projectMetrics),
              const SizedBox(height: 16),
            ],

            // Directory Structure
            if (projectMetrics['directoryStructure'] != null) ...[
              _buildDirectoryStructureCard(projectMetrics),
              const SizedBox(height: 16),
            ],

            // Health Indicators
            if (projectMetrics['healthIndicators'] != null) ...[
              _buildHealthCard(projectMetrics),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFileStatsCard(Map<String, dynamic> projectMetrics) {
    final fileStats = (projectMetrics['fileStats'] as Map).cast<String, int>();
    final totalFiles = projectMetrics['totalFiles'] as int;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Files & Directories',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Total files: $totalFiles',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: fileStats.entries
                  .take(8) // Show top 8
                  .map(
                    (entry) => Chip(
                      label: Text(
                        '.${entry.key} (${entry.value})',
                        style: const TextStyle(fontSize: 10),
                      ),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectoryStructureCard(Map<String, dynamic> projectMetrics) {
    final structure = (projectMetrics['directoryStructure'] as Map)
        .cast<String, int>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Platform Support',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: structure.entries
                  .map(
                    (entry) => Chip(
                      label: Text(
                        '${entry.key} (${entry.value})',
                        style: const TextStyle(fontSize: 10),
                      ),
                      avatar: Icon(_getPlatformIcon(entry.key), size: 12),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getPlatformIcon(String platform) {
    switch (platform) {
      case 'android':
        return Icons.phone_android;
      case 'ios':
        return Icons.phone_iphone;
      case 'web':
        return Icons.web;
      case 'windows':
        return Icons.desktop_windows;
      case 'linux':
        return Icons.desktop_mac;
      case 'macos':
        return Icons.desktop_mac;
      case 'lib':
        return Icons.code;
      case 'test':
        return Icons.bug_report;
      default:
        return Icons.folder;
    }
  }

  Widget _buildHealthCard(Map<String, dynamic> projectMetrics) {
    final indicators = (projectMetrics['healthIndicators'] as Map)
        .cast<String, dynamic>();

    final issues = <Map<String, dynamic>>[];

    if (!(indicators['hasPubspecLock'] ?? false)) {
      issues.add({
        'type': 'warning',
        'message': 'Missing pubspec.lock',
        'icon': Icons.warning,
      });
    }

    final buildErrors = indicators['buildErrors'] ?? 0;
    if (buildErrors > 0) {
      issues.add({
        'type': 'error',
        'message': '$buildErrors build errors',
        'icon': Icons.error,
      });
    }

    final buildWarnings = indicators['buildWarnings'] ?? 0;
    if (buildWarnings > 0) {
      issues.add({
        'type': 'warning',
        'message': '$buildWarnings build warnings',
        'icon': Icons.warning,
      });
    }

    final largeFiles = indicators['largeFiles'] as List?;
    if (largeFiles != null && largeFiles.isNotEmpty) {
      issues.add({
        'type': 'info',
        'message': '${largeFiles.length} large files',
        'icon': Icons.file_present,
      });
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Project Health',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            if (issues.isEmpty)
              Text(
                '✅ No issues detected',
                style: TextStyle(fontSize: 12, color: Colors.green.shade700),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: issues
                    .map(
                      (issue) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: StatusIndicator(
                          icon: issue['icon'] as IconData,
                          label: issue['message'] as String,
                          color: _getIssueColor(issue['type'] as String),
                          iconSize: 14,
                          textSize: 12,
                          spacing: 8,
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Color _getIssueColor(String type) {
    switch (type) {
      case 'error':
        return Colors.red.shade700;
      case 'warning':
        return Colors.orange.shade700;
      case 'info':
        return Colors.blue.shade700;
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  Widget _buildDependenciesCard(Map<String, dynamic> projectMetrics) {
    final deps =
        (projectMetrics['dependencies'] as Map<String, dynamic>?) ?? {};
    final devDeps =
        (projectMetrics['devDependencies'] as Map<String, dynamic>?) ?? {};
    final totalDeps = deps.length + devDeps.length;

    bool isExpanded = false;

    return StatefulBuilder(
      builder: (context, setState) => ExpansionTile(
        key: const PageStorageKey('dependencies_expansion'),
        initiallyExpanded: false,
        title: Text(
          'Dependencies ($totalDeps)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        tilePadding: EdgeInsets.all(0),
        trailing: AnimatedRotation(
          turns: isExpanded ? 0.25 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Icon(
            Icons.chevron_right,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        onExpansionChanged: (expanded) {
          setState(() => isExpanded = expanded);
          if (expanded && !_dependenciesExpanded) {
            _dependenciesExpanded = true;
            // Check outdated when expanding for expanding for the first time
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _checkOutdated();
            });
          }
        },
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _checkingOutdated ? null : _checkOutdated,
                      icon: _checkingOutdated
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.update, size: 16),
                      label: const Text('Check Outdated'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _upgrading ? null : _upgradePackages,
                      icon: _upgrading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_upward, size: 16),
                      label: const Text('Upgrade'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ],
                ),

                if (deps.isNotEmpty) ...[
                  Text(
                    'Direct (${deps.length})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: deps.entries.map((entry) {
                      final outdated =
                          projectMetrics['outdated'] as Map<String, dynamic>?;
                      final isOutdated =
                          outdated?.containsKey(entry.key) ?? false;
                      final label = isOutdated
                          ? '${entry.key} ${entry.value} → ${outdated![entry.key]['latest']}'
                          : '${entry.key} ${entry.value}';
                      return Chip(
                        label: Text(
                          label,
                          style: TextStyle(
                            fontSize: 10,
                            color: isOutdated ? Colors.orange.shade700 : null,
                          ),
                        ),
                        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],
                if (devDeps.isNotEmpty) ...[
                  Text(
                    'Developer (${devDeps.length})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: devDeps.entries.map((entry) {
                      final outdated =
                          projectMetrics['outdated'] as Map<String, dynamic>?;
                      final isOutdated =
                          outdated?.containsKey(entry.key) ?? false;
                      final label = isOutdated
                          ? '${entry.key} ${entry.value} → ${outdated![entry.key]['latest']}'
                          : '${entry.key} ${entry.value}';
                      return Chip(
                        label: Text(
                          label,
                          style: TextStyle(
                            fontSize: 10,
                            color: isOutdated ? Colors.orange.shade700 : null,
                          ),
                        ),
                        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                ],
                if (deps.isEmpty && devDeps.isEmpty) ...[
                  Text(
                    'No dependencies',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsCard(Map<String, dynamic> projectMetrics) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actions',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isRefreshing ? null : _performFullCleanup,
              icon: _isRefreshing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cleaning_services, size: 16),
              label: const Text('Full Project Cleanup'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 36),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isRefreshing ? null : _analyzeProject,
              icon: _isRefreshing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 16),
              label: const Text('Refresh Analysis'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 36),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
