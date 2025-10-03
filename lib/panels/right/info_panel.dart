// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yaml/yaml.dart';

// Models
import '../../models/document_state.dart';

// Providers
import '../../providers/app_providers.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to analyze project: $e')),
        );
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
    await for (final entity in Directory(projectPath).list(recursive: true)) {
      if (entity is File) {
        final size = await entity.length();
        if (size > 10 * 1024 * 1024) {
          // 10MB
          largeFiles.add(entity.path.replaceFirst(projectPath, ''));
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
    metrics['qualityGrade'] = _getGradeFromScore(score);
  }

  String _getGradeFromScore(int score) {
    if (score >= 90) return 'A';
    if (score >= 80) return 'B';
    if (score >= 70) return 'C';
    if (score >= 60) return 'D';
    return 'F';
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Full project cleanup completed!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRefreshing = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Cleanup failed: $e')));
      }
    }
  }

  void _openPubspecYaml() {
    try {
      final currentProjectPath = ref.read(currentProjectPathProvider);
      if (currentProjectPath == null) return;

      final pubspecPath = '$currentProjectPath/pubspec.yaml';
      if (!File(pubspecPath).existsSync()) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('pubspec.yaml not found')));
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open pubspec.yaml: $e')),
      );
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Outdated check completed')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to check outdated: ${result.stderr}'),
            ),
          );
        }
      }

      if (mounted) setState(() => _checkingOutdated = false);
    } catch (e) {
      if (mounted) {
        setState(() => _checkingOutdated = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error checking outdated: $e')));
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
      final result = await Process.run('flutter', [
        'pub',
        'upgrade',
      ], workingDirectory: currentProjectPath);

      if (result.exitCode == 0) {
        // Refresh analysis
        await _analyzeProject();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Packages upgraded successfully')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to upgrade packages: ${result.stderr}'),
            ),
          );
        }
      }

      if (mounted) setState(() => _upgrading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _upgrading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error upgrading packages: $e')));
      }
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
          children: [
            // Header with refresh button
            Text(
              projectMetrics['name'] as String? ?? 'Unknown Project',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              'Version: ${projectMetrics['version'] as String? ?? 'Unknown'}',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),

            Text(
              'Description: ${projectMetrics['description'] as String}',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),

            // Quality Score
            if (projectMetrics['qualityScore'] != null) ...[
              _buildScoreCard(projectMetrics),
              const SizedBox(height: 16),
            ],

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

            // Dependencies
            if (projectMetrics['dependencies'] != null ||
                projectMetrics['devDependencies'] != null) ...[
              _buildDependenciesCard(projectMetrics),
              const SizedBox(height: 16),
            ],

            // Actions
            _buildActionsCard(projectMetrics),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard(Map<String, dynamic> projectMetrics) {
    final score = projectMetrics['qualityScore'] as int;
    final grade = projectMetrics['qualityGrade'] as String;

    Color color;
    IconData icon;
    String label;

    switch (grade) {
      case 'A':
        color = Colors.green.shade700;
        icon = Icons.star;
        label = 'Excellent';
        break;
      case 'B':
        color = Colors.green.shade500;
        icon = Icons.star_half;
        label = 'Good';
        break;
      case 'C':
        color = Colors.orange.shade600;
        icon = Icons.star_border;
        label = 'Average';
        break;
      case 'D':
        color = Colors.orange.shade800;
        icon = Icons.warning;
        label = 'Poor';
        break;
      case 'F':
        color = Colors.red.shade600;
        icon = Icons.error;
        label = 'Critical';
        break;
      default:
        color = Colors.grey;
        icon = Icons.help;
        label = 'Unknown';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quality Score: $score/100',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'Grade: $grade ($label)',
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
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
                        child: Row(
                          children: [
                            Icon(
                              issue['icon'] as IconData,
                              size: 14,
                              color: _getIssueColor(issue['type'] as String),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              issue['message'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
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

    return Card(
      child: ExpansionTile(
        initiallyExpanded: false,
        title: Text(
          'Dependencies ($totalDeps)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: _checkingOutdated ? null : _checkOutdated,
              icon: _checkingOutdated
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.update, size: 16),
              tooltip: 'Check outdated packages',
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              onPressed: _upgrading ? null : _upgradePackages,
              icon: _upgrading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_upward, size: 16),
              tooltip: 'Upgrade packages',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        onExpansionChanged: (expanded) {
          if (expanded && !_dependenciesExpanded) {
            _dependenciesExpanded = true;
            // Check outdated when expanding for the first time
            _checkOutdated();
          }
        },
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (deps.isNotEmpty) ...[
                  Text(
                    'Dependencies',
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
                    'Dev Dependencies',
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

  Widget _buildDescriptionCard(Map<String, dynamic> projectMetrics) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Description',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              projectMetrics['description'] as String,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
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
            Column(
              children: [
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
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _openPubspecYaml,
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit pubspec.yaml'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 36),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
