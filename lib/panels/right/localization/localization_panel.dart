// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'dart:io';
import 'package:fide/panels/right/localization/localization_entry_widget.dart';
import 'package:fide/panels/right/localization/localization_setup_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fide/models/localization_data.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/services/localization_service.dart';
import 'package:fide/services/ai_service.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/utils/message_box.dart';
import 'package:fide/widgets/badge_status.dart';
import 'package:yaml_edit/yaml_edit.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

enum LocalizationStatus {
  checking,
  noProject,
  notFlutterProject,
  notStarted,
  partial,
  complete,
  error,
}

class LocalizationPanel extends ConsumerStatefulWidget {
  const LocalizationPanel({super.key, this.selectedFile});

  final FileSystemItem? selectedFile;

  @override
  ConsumerState<LocalizationPanel> createState() => _LocalizationPanelState();
}

class _LocalizationPanelState extends ConsumerState<LocalizationPanel> {
  final ArbService _arbService = ArbService();
  final LocalizationService _localizationService = LocalizationService();
  final AIService _aiService = AIService();
  final TextEditingController _filterController = TextEditingController();
  String _filterQuery = '';

  List<ArbFile> _arbFiles = [];
  List<ArbComparison> _comparisons = [];
  List<String> _malformedArbFiles = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Localization status
  LocalizationStatus _localizationStatus = LocalizationStatus.checking;

  @override
  void initState() {
    super.initState();
    _filterController.addListener(_onFilterChanged);
    _checkLocalizationStatus();
    _loadArbFiles();
  }

  @override
  void dispose() {
    _filterController.removeListener(_onFilterChanged);
    _filterController.dispose();
    super.dispose();
  }

  void _onFilterChanged() {
    setState(() {
      _filterQuery = _filterController.text.toLowerCase();
    });
  }

  bool _matchesFilter(ArbComparison comparison, String query) {
    final lowerQuery = query.toLowerCase();

    // Check the key
    if (comparison.key.toLowerCase().contains(lowerQuery)) {
      return true;
    }

    // Check English value
    if (comparison.englishValue != null &&
        comparison.englishValue!.toLowerCase().contains(lowerQuery)) {
      return true;
    }

    // Check other translation values
    for (final value in comparison.otherValues.values) {
      if (value != null && value.toLowerCase().contains(lowerQuery)) {
        return true;
      }
    }

    return false;
  }

  Future<void> _checkLocalizationStatus() async {
    final projectRoot = ref.read(currentProjectRootProvider);
    if (projectRoot == null) {
      setState(() => _localizationStatus = LocalizationStatus.noProject);
      return;
    }

    setState(() => _localizationStatus = LocalizationStatus.checking);

    try {
      final status = await _evaluateLocalizationStatus(projectRoot.path);
      setState(() => _localizationStatus = status);
    } catch (e) {
      setState(() => _localizationStatus = LocalizationStatus.error);
      debugPrint('Error checking localization status: $e');
    }
  }

  Future<LocalizationStatus> _evaluateLocalizationStatus(
    String projectPath,
  ) async {
    // Check if pubspec.yaml exists
    final pubspecFile = File('$projectPath/pubspec.yaml');
    if (!await pubspecFile.exists()) return LocalizationStatus.noProject;

    final pubspecContent = await pubspecFile.readAsString();

    // Check for basic Flutter project structure
    if (!pubspecContent.contains('flutter:') ||
        !pubspecContent.contains('sdk: flutter')) {
      return LocalizationStatus.notFlutterProject;
    }

    // Check for ARB files in the loaded project
    final l10nDir = Directory('$projectPath/lib/l10n');
    final hasL10nDirectory = await l10nDir.exists();

    bool hasArbFiles = false;
    if (hasL10nDirectory) {
      final arbFiles = await l10nDir
          .list()
          .where((entity) => entity.path.endsWith('.arb'))
          .toList();
      hasArbFiles = arbFiles.isNotEmpty;
    }

    // Check for generated classes in the loaded project
    final generatedClassesFile = File(
      '$projectPath/lib/l10n/app_localizations.dart',
    );
    final hasGeneratedClasses = await generatedClassesFile.exists();

    // Check main.dart integration in the loaded project
    final mainFile = File('$projectPath/lib/main.dart');
    bool hasAppIntegration = false;
    if (await mainFile.exists()) {
      final mainContent = await mainFile.readAsString();
      hasAppIntegration =
          mainContent.contains('AppLocalizations') &&
          mainContent.contains('localizationsDelegates') &&
          mainContent.contains('supportedLocales');
    }

    // Determine overall status
    if (hasArbFiles && hasGeneratedClasses && hasAppIntegration) {
      return LocalizationStatus.complete;
    } else if (hasArbFiles || hasGeneratedClasses) {
      return LocalizationStatus.partial;
    } else {
      return LocalizationStatus.notStarted;
    }
  }

  Future<void> _loadArbFiles() async {
    final projectRoot = ref.read(currentProjectRootProvider);
    if (projectRoot == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _malformedArbFiles = [];
    });

    try {
      // First, find all ARB files
      final l10nDir = Directory('${projectRoot.path}/lib/l10n');
      final arbFilePaths = <String>[];
      if (await l10nDir.exists()) {
        final files = await l10nDir.list().toList();
        for (final file in files) {
          if (file.path.endsWith('.arb')) {
            arbFilePaths.add(file.path);
          }
        }
      }

      // Try to parse each file individually
      final validArbFiles = <ArbFile>[];
      final malformedFiles = <String>[];

      for (final filePath in arbFilePaths) {
        try {
          final arbFile = await _arbService.parseArbFile(filePath);
          if (arbFile != null) {
            validArbFiles.add(arbFile);
          } else {
            malformedFiles.add(filePath);
          }
        } catch (e) {
          malformedFiles.add(filePath);
          debugPrint('Error parsing ARB file $filePath: $e');
        }
      }

      final comparisons = _arbService.compareArbFiles(validArbFiles);

      setState(() {
        _arbFiles = validArbFiles;
        _comparisons = comparisons;
        _malformedArbFiles = malformedFiles;
        _isLoading = false;
      });

      // Update localization status after loading ARB files to ensure consistency
      await _checkLocalizationStatus();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading ARB files: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _initializeLocalization() async {
    final projectRoot = ref.read(currentProjectRootProvider);
    if (projectRoot == null) return;

    setState(() => _isLoading = true);

    try {
      // Step 1: Add required packages
      if (mounted) {
        MessageBox.showInfo(
          context,
          'Adding flutter_localizations and intl packages...',
        );
      }
      await _addPackages(projectRoot.path);

      // Step 2: Configure pubspec.yaml
      if (mounted) {
        MessageBox.showInfo(context, 'Configuring pubspec.yaml...');
      }
      await _configurePubspec(projectRoot.path);

      // Step 3: Create l10n directory
      if (mounted) {
        MessageBox.showInfo(context, 'Creating lib/l10n directory...');
      }
      await _createL10nDirectory(projectRoot.path);

      // Step 4: Create ARB files
      if (mounted) {
        MessageBox.showInfo(context, 'Creating template ARB files...');
      }
      await _createArbFiles(projectRoot.path);

      // Step 5: Generate localization classes
      if (mounted) {
        MessageBox.showInfo(context, 'Generating localization classes...');
      }
      await _generateClasses(projectRoot.path);

      // Step 6: Update main.dart
      if (mounted) {
        MessageBox.showInfo(context, 'Updating main.dart...');
      }
      await _localizationService.updateMainDartForLocalization(
        projectRoot.path,
      );

      await _loadArbFiles();
      await _checkLocalizationStatus();

      if (mounted) {
        MessageBox.showSuccess(
          context,
          'Localization system initialized and main.dart updated successfully!',
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        MessageBox.showError(context, 'Error initializing localization: $e');
      }
    }
  }

  Future<void> _addPackages(String projectPath) async {
    // Add flutter_localizations
    final addFlutterLocalizationsResult = await Process.run('flutter', [
      'pub',
      'add',
      'flutter_localizations',
      '--sdk=flutter',
    ], workingDirectory: projectPath);
    if (addFlutterLocalizationsResult.exitCode != 0) {
      throw Exception(
        'Failed to add flutter_localizations: ${addFlutterLocalizationsResult.stderr}',
      );
    }

    // Add intl
    final addIntlResult = await Process.run('flutter', [
      'pub',
      'add',
      'intl',
    ], workingDirectory: projectPath);
    if (addIntlResult.exitCode != 0) {
      throw Exception('Failed to add intl: ${addIntlResult.stderr}');
    }
  }

  Future<void> _configurePubspec(String projectPath) async {
    final pubspecFile = File('$projectPath/pubspec.yaml');
    if (await pubspecFile.exists()) {
      final pubspecContent = await pubspecFile.readAsString();
      final editor = YamlEditor(pubspecContent);

      // Add generate: true to flutter section
      editor.update(['flutter', 'generate'], true);

      await pubspecFile.writeAsString(editor.toString());
    }
  }

  Future<void> _createL10nDirectory(String projectPath) async {
    final l10nDir = Directory('$projectPath/lib/l10n');
    if (!await l10nDir.exists()) {
      await l10nDir.create(recursive: true);
    }
  }

  Future<void> _createArbFiles(String projectPath) async {
    final l10nDir = Directory('$projectPath/lib/l10n');

    // Try to read existing app title from main.dart
    String appTitle = 'My App';
    final mainFile = File('$projectPath/lib/main.dart');
    if (await mainFile.exists()) {
      final mainContent = await mainFile.readAsString();
      final extractedTitle = _extractAppTitleFromMainDart(mainContent);
      if (extractedTitle != null && extractedTitle.isNotEmpty) {
        appTitle = extractedTitle;
      }
    }

    // Create English ARB file
    final englishArbContent = {
      '@@locale': 'en',
      'appTitle': appTitle,
      '@appTitle': {'description': 'The title of the application'},
      'helloWorld': 'Hello World',
      '@helloWorld': {'description': 'A greeting message'},
    };

    // Create French ARB file
    final frenchArbContent = {
      '@@locale': 'fr',
      'appTitle': 'Mon Application',
      '@appTitle': {'description': 'The title of the application'},
      'helloWorld': 'Bonjour le monde',
      '@helloWorld': {'description': 'A greeting message'},
    };

    await File(
      '${l10nDir.path}/app_en.arb',
    ).writeAsString(jsonEncode(englishArbContent));
    await File(
      '${l10nDir.path}/app_fr.arb',
    ).writeAsString(jsonEncode(frenchArbContent));
  }

  Future<void> _generateClasses(String projectPath) async {
    final result = await Process.run('flutter', [
      'gen-l10n',
    ], workingDirectory: projectPath);

    if (result.exitCode != 0) {
      throw Exception(
        'Failed to generate localization classes: ${result.stderr}',
      );
    }
  }

  Future<void> _updateMainDart() async {
    final projectRoot = ref.read(currentProjectRootProvider);
    if (projectRoot == null) return;

    setState(() => _isLoading = true);

    try {
      await _localizationService.updateMainDartForLocalization(
        projectRoot.path,
      );
      await _checkLocalizationStatus();

      if (mounted) {
        MessageBox.showSuccess(context, 'main.dart updated successfully!');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        MessageBox.showError(context, 'Error updating main.dart: $e');
      }
    }
  }

  Future<void> _generateLocalizationClasses() async {
    final projectRoot = ref.read(currentProjectRootProvider);
    if (projectRoot == null) return;

    setState(() => _isLoading = true);

    try {
      // Check if generate: true is set in pubspec.yaml
      final pubspecFile = File('${projectRoot.path}/pubspec.yaml');
      bool hasGenerateFlag = false;
      if (await pubspecFile.exists()) {
        final pubspecContent = await pubspecFile.readAsString();
        hasGenerateFlag = pubspecContent.contains('generate: true');
      }

      if (!hasGenerateFlag) {
        setState(() => _isLoading = false);
        if (mounted) {
          MessageBox.showError(
            context,
            'Cannot generate localization classes. Please ensure your pubspec.yaml has "generate: true" properly indented under the flutter section, run "flutter pub get", and restart your IDE. Example:\n\nflutter:\n  generate: true\n  uses-material-design: true',
          );
        }
        return;
      }

      final result = await Process.run('flutter', [
        'gen-l10n',
      ], workingDirectory: projectRoot.path);

      if (result.exitCode == 0) {
        await _checkLocalizationStatus();
        if (mounted) {
          MessageBox.showSuccess(
            context,
            'Localization classes generated successfully!',
          );
        }
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          MessageBox.showError(
            context,
            'Error generating classes: ${result.stderr}',
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        MessageBox.showError(context, 'Error generating classes: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectRoot = ref.watch(currentProjectRootProvider);

    if (projectRoot == null) {
      return const Center(child: Text('No project loaded'));
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadArbFiles,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Show status-based UI
    switch (_localizationStatus) {
      case LocalizationStatus.checking:
        return const Center(child: CircularProgressIndicator());
      case LocalizationStatus.noProject:
        return _buildStatusView(
          'No Project',
          'No Flutter project is currently loaded.',
          Icons.folder_off,
        );
      case LocalizationStatus.notFlutterProject:
        return _buildStatusView(
          'Not a Flutter Project',
          'The loaded project does not appear to be a Flutter project.',
          Icons.flutter_dash,
        );
      case LocalizationStatus.notStarted:
        return LocalizationSetupWidget(
          onInitializeLocalization: _initializeLocalization,
          onUpdateMainDart: _updateMainDart,
          isInitializing: _isLoading,
        );
      case LocalizationStatus.partial:
        return _buildPartialView();
      case LocalizationStatus.complete:
        return _buildCompleteView();
      case LocalizationStatus.error:
        return _buildStatusView(
          'Error',
          'An error occurred while checking localization status.',
          Icons.error,
          action: ElevatedButton(
            onPressed: _checkLocalizationStatus,
            child: const Text('Retry'),
          ),
        );
    }
  }

  Widget _buildStatusView(
    String title,
    String message,
    IconData icon, {
    Widget? action,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 16), action],
        ],
      ),
    );
  }

  Widget _buildPartialView() {
    final hasArbFiles = _hasArbFiles();
    final hasValidArbFiles = _arbFiles.isNotEmpty;
    final hasGeneratedClasses = _hasGeneratedClasses();
    final hasAppIntegration = _hasAppIntegration();
    final hasLocalizationDependencies = _hasLocalizationDependencies();
    final hasFlutterGenerateFlag = _hasFlutterGenerateFlag();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning,
                color: Theme.of(context).colorScheme.tertiary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Localization Partially Set Up',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Your Flutter project has some localization components set up, but others are missing. Localization requires three main components:',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '• ARB files (translation files in lib/l10n/)\n• Generated AppLocalizations class\n• Integration in main.dart',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Here\'s the current status:',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),

          // Status checks
          _buildStatusCheck(
            'Localization dependencies configured',
            hasLocalizationDependencies,
          ),
          _buildStatusCheck(
            'Flutter generate flag configured',
            hasFlutterGenerateFlag,
          ),
          _buildStatusCheck('ARB files exist', hasArbFiles),
          if (hasArbFiles) ...[
            hasValidArbFiles
                ? _buildStatusCheck('ARB files are valid JSON', true)
                : _buildStatusCheckWithMalformedFiles(
                    'ARB files are valid JSON',
                    _malformedArbFiles,
                  ),
          ],
          _buildStatusCheck('Generated classes exist', hasGeneratedClasses),
          _buildStatusCheck('App integration complete', hasAppIntegration),

          const SizedBox(height: 24),

          // Next Steps section
          Text(
            'Next Steps:',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Show specific actions based on what's missing
          if (!hasArbFiles) ...[
            _buildActionItem(
              'Create ARB files',
              'Set up localization files with template content',
              Icons.file_copy,
              _initializeLocalization,
            ),
          ] else if (hasArbFiles && !hasValidArbFiles) ...[
            _buildActionItem(
              'Fix malformed ARB files',
              'ARB files exist but contain invalid JSON. Check and repair the files in lib/l10n/',
              Icons.warning,
              () {
                MessageBox.showError(
                  context,
                  'ARB files are malformed. Please check the files in lib/l10n/ and ensure they contain valid JSON. You may need to recreate them using the Initialize Localization action.',
                );
              },
            ),
          ] else if (!hasGeneratedClasses) ...[
            _buildActionItem(
              'Generate localization classes',
              'Run flutter gen-l10n to create AppLocalizations class',
              Icons.build,
              _generateLocalizationClasses,
            ),
          ] else if (!hasAppIntegration) ...[
            _buildActionItem(
              'Update main.dart',
              'Add localization delegates and supported locales to MaterialApp',
              Icons.code,
              _updateMainDart,
            ),
          ],

          const SizedBox(height: 24),

          // Show ARB file management if files are loaded
          if (_arbFiles.isNotEmpty) ...[
            Text(
              'ARB File Management:',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _comparisons.length,
              itemBuilder: (context, index) {
                final comparison = _comparisons[index];
                return _buildComparisonTile(comparison);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompleteView() {
    // Filter comparisons based on filter query
    final filteredComparisons = _filterQuery.isEmpty
        ? _comparisons
        : _comparisons.where((comparison) {
            return _matchesFilter(comparison, _filterQuery);
          }).toList();

    // Find duplicate English values (2 or more occurrences)
    final englishValueCounts = <String, int>{};
    for (final comparison in filteredComparisons) {
      if (comparison.englishValue != null) {
        englishValueCounts[comparison.englishValue!] =
            (englishValueCounts[comparison.englishValue!] ?? 0) + 1;
      }
    }
    final duplicatedValues = englishValueCounts.entries
        .where((entry) => entry.value >= 2)
        .map((entry) => entry.key)
        .toSet();

    return Column(
      children: [
        // Duplicate warning banner
        if (duplicatedValues.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: BadgeStatus.warning(
              text:
                  '${duplicatedValues.length} English ${duplicatedValues.length == 1 ? 'string is' : 'strings are'} duplicated',
              fontSize: 11,
              showIcon: true,
            ),
          ),
        Expanded(
          child: _arbFiles.isEmpty
              ? const Center(child: Text('No ARB files found'))
              : ListView.separated(
                  itemCount: filteredComparisons.length,
                  itemBuilder: (context, index) {
                    final comparison = filteredComparisons[index];
                    final isDuplicated =
                        comparison.englishValue != null &&
                        duplicatedValues.contains(comparison.englishValue);
                    return LocalizationEntryWidget(
                      comparison: comparison,
                      showWarning: isDuplicated,
                    );
                  },
                  separatorBuilder: (context, index) =>
                      const Divider(height: 8, thickness: 1),
                ),
        ),
        // Filter bar
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: TextField(
            controller: _filterController,
            decoration: InputDecoration(
              hintText: 'Filter localization keys...',
              prefixIcon: const Icon(Icons.filter_list, size: 20),
              suffixIcon: _filterQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _filterController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCheck(String label, bool isComplete) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            isComplete ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 20,
            color: isComplete
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }

  Widget _buildStatusCheckWithMalformedFiles(
    String label,
    List<String> malformedFiles,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.radio_button_unchecked,
                size: 20,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(label)),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The following ARB files contain invalid JSON:',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(height: 4),
                ...malformedFiles.map((filePath) {
                  final fileName = filePath.split(Platform.pathSeparator).last;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            fileName,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.edit, size: 14),
                          label: const Text(
                            'Edit',
                            style: TextStyle(fontSize: 12),
                          ),
                          onPressed: () {
                            // Open the file in FIDE's editor
                            final fileSystemItem =
                                FileSystemItem.fromFileSystemEntity(
                                  File(filePath),
                                );
                            ref.read(selectedFileProvider.notifier).state =
                                fileSystemItem;
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            minimumSize: const Size(50, 28),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(
    String title,
    String description,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(description, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Execute'),
                  onPressed: onPressed,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _hasGeneratedClasses() {
    final projectRoot = ref.read(currentProjectRootProvider);
    if (projectRoot == null) return false;
    final file = File('${projectRoot.path}/lib/l10n/app_localizations.dart');
    return file.existsSync();
  }

  bool _hasArbFiles() {
    final projectRoot = ref.read(currentProjectRootProvider);
    if (projectRoot == null) return false;
    final l10nDir = Directory('${projectRoot.path}/lib/l10n');
    if (!l10nDir.existsSync()) return false;
    final arbFiles = l10nDir
        .listSync()
        .where((entity) => entity.path.endsWith('.arb'))
        .toList();
    return arbFiles.isNotEmpty;
  }

  bool _hasLocalizationDependencies() {
    final projectRoot = ref.read(currentProjectRootProvider);
    if (projectRoot == null) return false;
    final file = File('${projectRoot.path}/pubspec.yaml');
    if (!file.existsSync()) return false;
    final content = file.readAsStringSync();
    return content.contains('flutter_localizations:') &&
        content.contains('intl:');
  }

  bool _hasFlutterGenerateFlag() {
    final projectRoot = ref.read(currentProjectRootProvider);
    if (projectRoot == null) return false;
    final file = File('${projectRoot.path}/pubspec.yaml');
    if (!file.existsSync()) return false;
    final content = file.readAsStringSync();
    return content.contains('generate: true');
  }

  bool _hasAppIntegration() {
    final projectRoot = ref.read(currentProjectRootProvider);
    if (projectRoot == null) return false;
    final file = File('${projectRoot.path}/lib/main.dart');
    if (!file.existsSync()) return false;
    final content = file.readAsStringSync();
    return content.contains('AppLocalizations') &&
        content.contains('localizationsDelegates') &&
        content.contains('supportedLocales');
  }

  Widget _buildComparisonTile(ArbComparison comparison) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              comparison.key,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            if (comparison.englishValue != null)
              Text(
                'EN: ${comparison.englishValue}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: comparison.missingInLanguages.map((lang) {
                final targetFile = _arbFiles.firstWhere(
                  (file) => file.languageCode == lang,
                );
                return ElevatedButton.icon(
                  icon: const Icon(Icons.translate, size: 16),
                  label: Text('Translate to $lang'),
                  onPressed: comparison.englishValue != null
                      ? () => _translateMissingKey(
                          comparison.key,
                          comparison.englishValue!,
                          lang,
                          targetFile.path,
                        )
                      : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _translateMissingKey(
    String key,
    String englishValue,
    String targetLanguage,
    String targetFilePath,
  ) async {
    try {
      final prompt =
          '''
Translate the following English text to $targetLanguage:

"$englishValue"

Provide only the translated text, no additional explanation or quotes.''';

      final translation = await _aiService.getCodeSuggestion(prompt, '');

      if (translation.isNotEmpty && !translation.startsWith('Error:')) {
        await _arbService.updateArbFile(
          targetFilePath,
          key,
          translation.trim(),
          metadata: {'description': 'Translated using AI'},
        );

        await _loadArbFiles();

        if (mounted) {
          MessageBox.showSuccess(
            context,
            'Translated "$key" to $targetLanguage',
          );
        }
      } else {
        if (mounted) {
          MessageBox.showError(context, 'Translation failed');
        }
      }
    } catch (e) {
      if (mounted) {
        MessageBox.showError(context, 'Error translating: $e');
      }
    }
  }

  String? _extractAppTitleFromMainDart(String content) {
    try {
      final result = parseString(content: content);
      final unit = result.unit;

      final visitor = _MaterialAppTitleVisitor();
      unit.accept(visitor);
      return visitor.title;
    } catch (e) {
      debugPrint('Error parsing main.dart: $e');
      return null;
    }
  }
}

class _MaterialAppTitleVisitor extends GeneralizingAstVisitor<void> {
  String? title;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    // Check if this is a MaterialApp constructor
    if (node.constructorName.toString() == 'MaterialApp') {
      // Look for the title argument
      for (final argument in node.argumentList.arguments) {
        if (argument is NamedExpression &&
            argument.name.label.name == 'title') {
          final expression = argument.expression;
          if (expression is StringLiteral) {
            title = expression.stringValue;
            break;
          }
        }
      }
    }

    super.visitInstanceCreationExpression(node);
  }
}
