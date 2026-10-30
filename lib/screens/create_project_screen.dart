// ignore: fcheck_dead_code
import 'package:fide/constants/constants.dart';
import 'package:fide/models/app_theme.dart';
import 'package:fide/models/project_creation_request.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/project_creation_service.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/screens/create_project_step1.dart';
import 'package:fide/screens/create_project_step2.dart';
import 'package:fide/screens/create_project_step3.dart';
import 'package:fide/widgets/full_path_widget.dart';
import 'package:fide/widgets/hero_title_widget.dart';
import 'package:fide/widgets/loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

// Enum for wizard steps
enum CreateProjectStep {
  nameAndFolder, // Step 1
  localization, // Step 2
  creating, // Step 3
}

/// Represents `CreateProjectScreen`.
class CreateProjectScreen extends ConsumerStatefulWidget {
  final String? initialDirectory;
  final VoidCallback onCancel;
  final void Function(String) onOpenProject;

  const CreateProjectScreen({
    super.key,
    this.initialDirectory,
    required this.onOpenProject,
    required this.onCancel,
  });

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

  /// Batches rapid state changes into a single UI update after a short delay.
  void _scheduleLoadingUpdate() {
    if (_hasScheduledLoadingUpdate) return;

    _hasScheduledLoadingUpdate = true;

    // Batch updates to avoid overwhelming the UI.
    Future.delayed(AppDuration.loadingUpdateBatch, () {
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

  /// Detects Flutter availability and version, updating [_flutterAvailable] and [_flutterVersion].
  Future<void> _checkFlutterStatus() async {
    final versions = await ref.read(flutterSdkProvider).versions();
    if (!mounted) return;
    setState(() {
      _flutterStatusChecked = true;
      _flutterAvailable = versions != null;
      _flutterVersion = versions == null ? null : versions.flutter ?? 'Unknown';
    });
  }

  /// Detects Git availability and version, updating [_gitAvailable] and [_gitVersion].
  Future<void> _checkGitStatus() async {
    final version = await ref.read(gitServiceProvider).version();
    if (!mounted) return;
    setState(() {
      _gitStatusChecked = true;
      _gitAvailable = version != null;
      _gitVersion = version;
    });
  }

  Future<void> _initializeDirectoryController() async {
    final directoryPath =
        ref.read(newProjectParentDirectoryProvider) ??
        widget.initialDirectory ??
        (await getApplicationDocumentsDirectory()).path;
    setState(() {
      directoryController = TextEditingController(text: directoryPath);
    });
  }

  /// Checks whether Ollama is installed and running, updating the corresponding state fields.
  Future<void> _checkOllamaStatus() async {
    try {
      final ollama = ref.read(ollamaInstallerProvider);
      _ollamaAvailable = await ollama.isInstalled() && await ollama.isRunning();

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

  /// Advances the wizard to the next step, or triggers project creation on the final step.
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

  /// Resets the progress list and runs project creation, enabling the Open
  /// button once it succeeds.
  Future<void> _startProjectCreation() async {
    ref.read(loadingActionsProvider.notifier).state =
        ProjectCreationService.initialActions();

    final created = await ref
        .read(projectCreationServiceProvider)
        .create(
          ProjectCreationRequest(
            name: _newProjectName,
            parentDirectory: _userDirectory,
            flutterAvailable: _flutterAvailable,
            languages: _wantsLocalization ? {..._selectedLanguages} : null,
            useAi: _useAI && _ollamaAvailable,
            initGit: _gitAvailable,
          ),
          _updateLoadingAction,
        );
    if (created && mounted) {
      setState(() => _projectCreationComplete = true);
    }
  }

  /// Queues a progress change for the next batched UI update.
  void _updateLoadingAction(int step, String text, LoadingStatus status) {
    _pendingActionUpdates[step] = LoadingAction(step, text, status);
    _scheduleLoadingUpdate();
  }

  String? get _currentFullPathToNewProject =>
      _userDirectory.isEmpty ? null : '$_userDirectory/$_newProjectName';

  /// The package name the user settled on.
  String get _newProjectName => _userFinalProjectName.isNotEmpty
      ? _userFinalProjectName
      : _userProjectName;

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

  /// Adds or removes [lang] from the selected language set and ensures the primary language stays selected.
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

  /// Returns the appropriate step widget for the current wizard step.
  Widget _buildStepContent() {
    switch (_currentStep) {
      case CreateProjectStep.nameAndFolder:
        return SingleChildScrollView(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(
                maxWidth: AppSize.wizardMaxWidth,
              ),
              child: CreateProjectStep1(
                initialDirectory: widget.initialDirectory,
                defaultParentDirectory: ref.read(
                  newProjectParentDirectoryProvider,
                ),
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
              constraints: const BoxConstraints(
                maxWidth: AppSize.wizardMaxWidth,
              ),
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
      return const Scaffold(body: LoadingIndicator());
    }

    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(AppSpacing.huge),
        decoration: AppTheme.screenBackground(context),
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
            const SizedBox(height: AppSpacing.huge),

            // Form section - wizard steps
            Expanded(child: _buildStepContent()),

            // Action buttons at the bottom
            Container(
              padding: const EdgeInsets.only(top: AppSpacing.xxLarge),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Cancel button - always present
                  OutlinedButton(
                    onPressed: widget.onCancel,
                    style: OutlinedButton.styleFrom(
                      padding: AppPadding.wizardButton,
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: AppSpacing.xLarge),
                  _buildPrimaryButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The step's forward action: Next, Create, then Open once the project
  /// has been created.
  Widget _buildPrimaryButton() {
    final (label, onPressed) = switch (_currentStep) {
      CreateProjectStep.nameAndFolder => (
        'Next',
        _canGoToNextStep() ? _nextStep : null,
      ),
      CreateProjectStep.localization => (
        'Create',
        _canGoToNextStep() ? _nextStep : null,
      ),
      CreateProjectStep.creating => (
        'Open',
        _projectCreationComplete ? _onOpenProject : null,
      ),
    };
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(padding: AppPadding.wizardButton),
      child: Text(label),
    );
  }
}
