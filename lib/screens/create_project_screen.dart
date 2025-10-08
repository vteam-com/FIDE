import 'dart:io';
import 'package:fide/widgets/full_path_widget.dart';
import 'package:flutter/material.dart';
import 'package:fide/screens/create_project_step3.dart';
import 'package:fide/widgets/hero_title_widget.dart';
import 'package:fide/services/ai_service.dart';
import 'package:fide/services/localization_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:process_run/shell.dart';

import 'create_project_step1.dart';
import 'create_project_step2.dart';

// Enum for wizard steps
enum CreateProjectStep {
  nameAndFolder, // Step 1
  localization, // Step 2
  creating, // Step 3
}

class CreateProjectScreen extends ConsumerStatefulWidget {
  final String? initialDirectory;
  final VoidCallback onCancel;
  final void Function(String) onOpenProject;

  // Static variable for testing to override initial directory
  static String? _testInitialDirectory;

  const CreateProjectScreen({
    super.key,
    this.initialDirectory,
    required this.onOpenProject,
    required this.onCancel,
  });

  // Method to set initial directory for testing
  static void setTestInitialDirectory(String? directory) {
    _testInitialDirectory = directory;
  }

  @override
  ConsumerState<CreateProjectScreen> createState() =>
      _CreateProjectScreenState();
}

class _CreateProjectScreenState extends ConsumerState<CreateProjectScreen> {
  final TextEditingController nameController = TextEditingController();
  TextEditingController? directoryController;
  TextEditingController descriptionController = TextEditingController();
  String? selectedDirectory;
  String? _finalProjectName;

  // Wizard step management
  CreateProjectStep _currentStep = CreateProjectStep.nameAndFolder;
  bool _step1CanProceed = false;
  bool _step2CanProceed = true; // Step 2 always allows proceeding by default
  bool _projectCreationComplete = false; // Track project creation completion
  String _selectedLanguage = 'en'; // Default to English

  // Localization settings
  bool _wantsLocalization = true;
  final Set<String> _selectedLanguages = {'en', 'fr'};

  // Flutter status tracking
  bool _flutterStatusChecked = false;
  bool _flutterAvailable = false;
  String? _flutterVersion;

  // Git status tracking
  bool _gitStatusChecked = false;
  bool _gitAvailable = false;
  String? _gitVersion;

  // Ollama status tracking
  bool _ollamaStatusChecked = false;
  bool _ollamaAvailable = false;

  // AI generation settings
  bool _useAI = false; // Default to using AI for project generation

  // Performance optimization for loading actions
  final Map<int, LoadingAction> _pendingActionUpdates = {};
  bool _hasScheduledLoadingUpdate = false;

  void _scheduleLoadingUpdate() {
    if (_hasScheduledLoadingUpdate) return;

    _hasScheduledLoadingUpdate = true;

    // Batch updates every 50ms to avoid overwhelming the UI
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted) return;

      final actions = ref.read(loadingActionsProvider);
      bool hasUpdates = false;

      for (final update in _pendingActionUpdates.entries) {
        final actionIndex = actions.indexWhere(
          (action) => action.step == update.key,
        );
        if (actionIndex != -1) {
          actions[actionIndex] = update.value;
          hasUpdates = true;
        }
      }

      if (hasUpdates) {
        ref.read(loadingActionsProvider.notifier).state = [...actions];
      }

      _pendingActionUpdates.clear();
      _hasScheduledLoadingUpdate = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _userProjectName = '';
    _userFinalProjectName = '';
    _userDirectory = '';
    _initializeDirectoryController();
    _checkFlutterStatus();
    _checkGitStatus();
    _checkOllamaStatus();
  }

  Future<void> _checkFlutterStatus() async {
    try {
      // Check Flutter availability and get version
      final shell = Shell();
      final results = await shell.run('flutter --version');

      if (results.isNotEmpty && results.first.exitCode == 0) {
        _flutterAvailable = true;
        // Extract version from output (first line typically contains version)
        final output = results.first.stdout.toString();
        final lines = output.split('\n');
        if (lines.isNotEmpty) {
          // Look for version pattern like "Flutter 3.24.0 • channel stable"
          final versionLine = lines.firstWhere(
            (line) => line.contains('Flutter'),
            orElse: () => lines.first,
          );
          // Extract version number using regex
          final versionMatch = RegExp(
            r'Flutter (\d+\.\d+\.\d+)',
          ).firstMatch(versionLine);
          if (versionMatch != null) {
            _flutterVersion = versionMatch.group(1);
          } else {
            _flutterVersion = 'Unknown';
          }
        } else {
          _flutterVersion = 'Available';
        }
      } else {
        _flutterAvailable = false;
        _flutterVersion = null;
      }

      if (mounted) {
        setState(() {
          _flutterStatusChecked = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _flutterStatusChecked = true;
          _flutterAvailable = false;
          _flutterVersion = null;
        });
      }
    }
  }

  Future<void> _checkGitStatus() async {
    try {
      // Check Git availability and get version
      final shell = Shell();
      final results = await shell.run('git --version');

      if (results.isNotEmpty && results.first.exitCode == 0) {
        _gitAvailable = true;
        // Extract version from output (format: "git version 2.39.3")
        final output = results.first.stdout.toString().trim();
        final versionMatch = RegExp(
          r'git version (\d+\.\d+\.\d+)',
        ).firstMatch(output);
        if (versionMatch != null) {
          _gitVersion = versionMatch.group(1);
        } else {
          _gitVersion = 'Unknown';
        }
      } else {
        _gitAvailable = false;
        _gitVersion = null;
      }

      if (mounted) {
        setState(() {
          _gitStatusChecked = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _gitStatusChecked = true;
          _gitAvailable = false;
          _gitVersion = null;
        });
      }
    }
  }

  Future<void> _initializeDirectoryController() async {
    final directoryPath =
        CreateProjectScreen._testInitialDirectory ??
        widget.initialDirectory ??
        (await getApplicationDocumentsDirectory()).path;
    setState(() {
      directoryController = TextEditingController(text: directoryPath);
    });
  }

  Future<void> _checkOllamaStatus() async {
    try {
      // Check if Ollama is installed using which
      final whichResult = await Process.run('which', ['ollama']);
      final isInstalled = whichResult.exitCode == 0;

      if (isInstalled) {
        // Check if running by trying to list models
        final listResult = await Process.run('ollama', ['list']);
        _ollamaAvailable = listResult.exitCode == 0;
      } else {
        _ollamaAvailable = false;
      }

      if (mounted) {
        setState(() {
          _ollamaStatusChecked = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _ollamaStatusChecked = true;
          _ollamaAvailable = false;
        });
      }
    }
  }

  void _nextStep() {
    if (_currentStep == CreateProjectStep.nameAndFolder && _canGoToNextStep()) {
      setState(() {
        _currentStep = CreateProjectStep.localization;
      });
    } else if (_currentStep == CreateProjectStep.localization) {
      // Move to Step 3 and start creation
      setState(() {
        _currentStep = CreateProjectStep.creating;
        _projectCreationComplete = false; // Show "Creating..." immediately
      });
      _startProjectCreation();
    }
  }

  bool _canGoToNextStep() {
    if (_currentStep == CreateProjectStep.nameAndFolder) {
      return _step1CanProceed;
    } else if (_currentStep == CreateProjectStep.localization) {
      return _step2CanProceed;
    }
    return false;
  }

  late String _userProjectName;
  late String _userFinalProjectName;
  late String _userDirectory;

  void _startProjectCreation() {
    // Disable Open button while creating - already set in _nextStep

    // Initialize loading actions
    ref.read(loadingActionsProvider.notifier).state = [
      LoadingAction(
        1,
        'Validating settings and checking dependencies...',
        LoadingStatus.pending,
      ),
      LoadingAction(2, 'Creating Flutter project...', LoadingStatus.pending),
      LoadingAction(3, 'Setting up localization...', LoadingStatus.pending),
      LoadingAction(
        4,
        'Generating initial code structure...',
        LoadingStatus.pending,
      ),
      LoadingAction(5, 'Initializing Git repository...', LoadingStatus.pending),
      LoadingAction(
        6,
        'Final verification and cleanup...',
        LoadingStatus.pending,
      ),
    ];

    // Execute the creation process
    _executeProjectCreation();
  }

  Future<void> _executeProjectCreation() async {
    final projectPath =
        '$_userDirectory/${_userFinalProjectName.isNotEmpty ? _userFinalProjectName : _userProjectName}';

    try {
      // Step 1: Validate settings and check dependencies
      await _updateLoadingAction(
        1,
        'Validating settings and checking dependencies...',
        LoadingStatus.pending,
      );

      if (!_flutterAvailable) {
        throw Exception(
          'Flutter is not available. Please install Flutter and restart FIDE.',
        );
      }

      await _updateLoadingAction(
        1,
        'Dependencies validated successfully',
        LoadingStatus.success,
      );

      // Step 2: Create Flutter project
      await _updateLoadingAction(
        2,
        'Creating Flutter project...',
        LoadingStatus.pending,
      );

      final createResult =
          await Process.run('flutter', [
            'create',
            '--project-name',
            _userFinalProjectName.isNotEmpty
                ? _userFinalProjectName
                : _userProjectName,
            '--platforms',
            'android,ios,web,linux,macos,windows',
            projectPath,
          ], workingDirectory: _userDirectory).timeout(
            const Duration(
              seconds: 60,
            ), // 60 second timeout for project creation
            onTimeout: () => ProcessResult(
              0,
              -1,
              '',
              'Flutter create command timed out after 60 seconds',
            ),
          );

      if (createResult.exitCode != 0) {
        throw Exception(
          'Failed to create Flutter project: ${createResult.stderr}',
        );
      }

      await _updateLoadingAction(
        2,
        'Flutter project created successfully',
        LoadingStatus.success,
      );

      // Step 3: Set up localization
      await _updateLoadingAction(
        3,
        'Setting up localization...',
        LoadingStatus.pending,
      );

      if (_wantsLocalization) {
        final localizationService = LocalizationService();
        await localizationService.initializeLocalization(projectPath);

        // Setup selected languages - create ARB files for each language
        for (final lang in _selectedLanguages) {
          if (lang != 'en') {
            final arbPath = '$projectPath/lib/l10n/app_$lang.arb';
            final file = File(arbPath);
            if (!await file.exists()) {
              await file.writeAsString('{}\n');
            }
          }
        }

        await _updateLoadingAction(
          3,
          'Localization setup completed',
          LoadingStatus.success,
        );
      } else {
        await _updateLoadingAction(
          3,
          'Localization skipped',
          LoadingStatus.success,
        );
      }

      // Step 4: Generate initial code structure using AI
      await _updateLoadingAction(
        4,
        'Generating initial code structure...',
        LoadingStatus.pending,
      );

      if (_useAI && _ollamaAvailable) {
        try {
          final aiService = AIService();
          final projectName = _userFinalProjectName.isNotEmpty
              ? _userFinalProjectName
              : _userProjectName;

          // Generate a basic project description based on localization settings
          final baseDescription = _wantsLocalization
              ? 'a Flutter app with localization support using provider for state management'
              : 'a Flutter app using provider for state management';

          final fullDescription =
              '$baseDescription with the name "$projectName". Include proper project structure, basic routing, and theme configuration.';

          // Generate complete project files with timeout
          final aiFuture = aiService.generateProject(
            projectName,
            fullDescription,
          );

          final generatedFiles = await aiFuture.timeout(
            const Duration(
              seconds: 120,
            ), // 120 second timeout for AI project generation
            onTimeout: () => {
              'error': 'AI generation timed out after 120 seconds',
            },
          );

          if (generatedFiles.containsKey('error')) {
            await _updateLoadingAction(
              4,
              'AI code generation failed: ${generatedFiles['error']}',
              LoadingStatus.success,
            );
          } else {
            // Write generated files
            if (generatedFiles.containsKey('pubspec.yaml')) {
              final pubspecFile = File('$projectPath/pubspec.yaml');
              await pubspecFile.writeAsString(generatedFiles['pubspec.yaml']!);
            }

            if (generatedFiles.containsKey('lib/main.dart')) {
              final mainFile = File('$projectPath/lib/main.dart');
              await mainFile.writeAsString(generatedFiles['lib/main.dart']!);
            }

            if (generatedFiles.containsKey('README.md')) {
              final readmeFile = File('$projectPath/README.md');
              await readmeFile.writeAsString(generatedFiles['README.md']!);
            }

            await _updateLoadingAction(
              4,
              'AI-generated project files completed',
              LoadingStatus.success,
            );
          }
        } catch (e) {
          await _updateLoadingAction(
            4,
            'AI code generation failed, using defaults',
            LoadingStatus.success,
          );
        }
      } else {
        await _updateLoadingAction(
          4,
          'AI not available, using default structure',
          LoadingStatus.success,
        );
      }

      // Step 5: Initialize Git repository
      await _updateLoadingAction(
        5,
        'Initializing Git repository...',
        LoadingStatus.pending,
      );

      if (_gitAvailable) {
        try {
          final gitInitResult =
              await Process.run('git', [
                'init',
              ], workingDirectory: projectPath).timeout(
                const Duration(seconds: 10),
                onTimeout: () =>
                    ProcessResult(0, -1, '', 'Git init command timed out'),
              );
          if (gitInitResult.exitCode == 0) {
            // Add initial commit
            await Process.run('git', [
              'add',
              '.',
            ], workingDirectory: projectPath).timeout(
              const Duration(seconds: 30),
              onTimeout: () =>
                  ProcessResult(0, -1, '', 'Git add command timed out'),
            );
            await Process.run('git', [
              'commit',
              '-m',
              'Initial commit',
            ], workingDirectory: projectPath).timeout(
              const Duration(seconds: 30),
              onTimeout: () =>
                  ProcessResult(0, -1, '', 'Git commit command timed out'),
            );
            await _updateLoadingAction(
              5,
              'Git repository initialized',
              LoadingStatus.success,
            );
          } else {
            await _updateLoadingAction(
              5,
              'Git initialization failed',
              LoadingStatus.failed,
            );
          }
        } catch (e) {
          await _updateLoadingAction(
            5,
            'Git initialization failed',
            LoadingStatus.failed,
          );
        }
      } else {
        await _updateLoadingAction(
          5,
          'Git not available, skipped',
          LoadingStatus.success,
        );
      }

      // Step 6: Final verification
      await _updateLoadingAction(
        6,
        'Final verification and cleanup...',
        LoadingStatus.pending,
      );

      // Verify project structure
      final pubspecFile = File('$projectPath/pubspec.yaml');
      final mainFile = File('$projectPath/lib/main.dart');
      final androidDir = Directory('$projectPath/android');
      final iosDir = Directory('$projectPath/ios');

      if (await pubspecFile.exists() &&
          await mainFile.exists() &&
          await androidDir.exists() &&
          await iosDir.exists()) {
        await _updateLoadingAction(
          6,
          'Project verification completed successfully',
          LoadingStatus.success,
        );

        if (mounted) {
          setState(() {
            _projectCreationComplete = true; // Enable Open button
          });
        }
      } else {
        throw Exception(
          'Project verification failed - missing required files/directories',
        );
      }
    } catch (e) {
      // Mark current step as failed
      final actions = ref.read(loadingActionsProvider);
      final currentStep =
          actions
              .where((action) => action.status == LoadingStatus.pending)
              .isNotEmpty
          ? actions.firstWhere(
              (action) => action.status == LoadingStatus.pending,
            )
          : actions.last;

      await _updateLoadingAction(
        currentStep.step,
        'Error: ${e.toString()}',
        LoadingStatus.failed,
      );

      // Log the error
      print('Project creation failed: $e');
    }
  }

  Future<void> _updateLoadingAction(
    int step,
    String text,
    LoadingStatus status,
  ) async {
    _pendingActionUpdates[step] = LoadingAction(step, text, status);
    _scheduleLoadingUpdate();
  }

  String? get _currentFullPathToNewProject => _userDirectory.isEmpty
      ? null
      : '$_userDirectory/${_userFinalProjectName.isNotEmpty ? _userFinalProjectName : _userProjectName}';

  void _onOpenProject() {
    widget.onOpenProject(_currentFullPathToNewProject!);
  }

  void _onProjectNameChanged(String projectName, String? finalProjectName) {
    _userProjectName = projectName;
    _userFinalProjectName = finalProjectName ?? projectName;
  }

  void _onDirectoryChanged(String directory) {
    _userDirectory = directory;
  }

  void _onWantsLocalizationChanged(bool value) =>
      setState(() => _wantsLocalization = value);

  void _onLanguageSelectionChanged(String lang, bool selected) {
    setState(() {
      if (selected) {
        _selectedLanguages.add(lang);
      } else {
        _selectedLanguages.remove(lang);
        // Ensure default language is still selected
        if (_selectedLanguages.contains(_selectedLanguage) == false) {
          if (_selectedLanguages.isNotEmpty) {
            _selectedLanguage = _selectedLanguages.first;
          } else {
            // Reset to English if no languages selected
            _selectedLanguages.add('en');
            _selectedLanguage = 'en';
          }
        }
      }
    });
  }

  void _onDefaultLanguageChanged(String value) =>
      setState(() => _selectedLanguage = value);

  void _onStep1ValidationChanged(bool canProceed) {
    setState(() => _step1CanProceed = canProceed);
  }

  void _onStep2ValidationChanged(bool canProceed) {
    setState(() => _step2CanProceed = canProceed);
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case CreateProjectStep.nameAndFolder:
        return SingleChildScrollView(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              child: CreateProjectStep1(
                initialDirectory: widget.initialDirectory,
                testInitialDirectory: CreateProjectScreen._testInitialDirectory,
                flutterStatusChecked: _flutterStatusChecked,
                flutterAvailable: _flutterAvailable,
                flutterVersion: _flutterVersion,
                gitStatusChecked: _gitStatusChecked,
                gitAvailable: _gitAvailable,
                gitVersion: _gitVersion,
                ollamaStatusChecked: _ollamaStatusChecked,
                ollamaAvailable: _ollamaAvailable,
                onProjectNameChanged: _onProjectNameChanged,
                onDirectoryChanged: _onDirectoryChanged,
                onValidationChanged: _onStep1ValidationChanged,
                onUseAIChanged: (value) {
                  if (mounted) {
                    setState(() => _useAI = value);
                  }
                },
              ),
            ),
          ),
        );
      case CreateProjectStep.localization:
        return SingleChildScrollView(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              child: CreateProjectStep2(
                projectName: _userFinalProjectName.isNotEmpty
                    ? _userFinalProjectName
                    : (_finalProjectName ?? 'Project'),
                projectLocation: _userDirectory.isNotEmpty
                    ? _userDirectory
                    : (selectedDirectory ?? directoryController!.text),
                wantsLocalization: _wantsLocalization,
                selectedLanguages: _selectedLanguages,
                defaultLanguage: _selectedLanguage,
                onWantsLocalizationChanged: _onWantsLocalizationChanged,
                onLanguageSelectionChanged: _onLanguageSelectionChanged,
                onDefaultLanguageChanged: _onDefaultLanguageChanged,
                onValidationChanged: _onStep2ValidationChanged,
              ),
            ),
          ),
        );
      case CreateProjectStep.creating:
        // Step 3: Project creation in progress
        return Center(
          child: CreateProjectStep3(
            projectName: _userFinalProjectName.isNotEmpty
                ? _userFinalProjectName
                : _userProjectName,
            projectLocation: _userDirectory,
          ),
        );
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    directoryController?.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading if directory controller is not initialized yet
    if (directoryController == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Container(
        padding: EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header section
            HeroTitleWidget(
              title: 'New Flutter Project',
              subWidget: _currentFullPathToNewProject != null
                  ? FullPathWidget(path: _currentFullPathToNewProject!)
                  : null,
            ),
            const SizedBox(height: 32),

            // Form section - wizard steps
            Expanded(child: _buildStepContent()),

            // Action buttons at the bottom
            Container(
              padding: const EdgeInsets.only(top: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Cancel button - always present
                  OutlinedButton(
                    onPressed: widget.onCancel,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 16),

                  // Step 1: Next button
                  if (_currentStep == CreateProjectStep.nameAndFolder)
                    FilledButton(
                      onPressed: _canGoToNextStep() ? _nextStep : null,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                      child: const Text('Next'),
                    ),

                  // Step 2: Create button
                  if (_currentStep == CreateProjectStep.localization)
                    FilledButton(
                      onPressed: _canGoToNextStep() ? _nextStep : null,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                      child: const Text('Create'),
                    ),

                  // Step 3: Open button (when project creation is in progress)
                  if (_currentStep == CreateProjectStep.creating)
                    FilledButton(
                      onPressed: _projectCreationComplete
                          ? _onOpenProject
                          : null,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                      child: Text('Open'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
