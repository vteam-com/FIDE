import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:process_run/shell.dart';

import 'create_project_step1.dart';
import 'create_project_step2.dart';

class CreateProjectScreen extends StatefulWidget {
  final String? initialDirectory;
  final VoidCallback onCancel;
  final void Function(Map<String, String>) onCreate;

  // Static variable for testing to override initial directory
  static String? _testInitialDirectory;

  const CreateProjectScreen({
    super.key,
    this.initialDirectory,
    required this.onCancel,
    required this.onCreate,
  });

  // Method to set initial directory for testing
  static void setTestInitialDirectory(String? directory) {
    _testInitialDirectory = directory;
  }

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  final TextEditingController nameController = TextEditingController();
  TextEditingController? directoryController;
  TextEditingController descriptionController = TextEditingController();
  String? selectedDirectory;
  String? _finalProjectName;

  // Wizard step management
  int _currentStep = 1;
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
    if (_currentStep == 1 && _canGoToNextStep()) {
      setState(() {
        _currentStep = 2;
      });
    }
  }

  bool _canGoToNextStep() {
    return _userProjectName.isNotEmpty && _userDirectory.isNotEmpty;
  }

  late String _userProjectName;
  late String _userFinalProjectName;
  late String _userDirectory;

  void _handleCreate() {
    final projectName = _userFinalProjectName.isNotEmpty
        ? _userFinalProjectName
        : _userProjectName;
    final directory = _userDirectory;

    final result = <String, String>{
      'name': projectName,
      'directory': directory,
      'language': _selectedLanguage,
    };

    if (_ollamaAvailable && descriptionController.text.isNotEmpty) {
      result['description'] = descriptionController.text;
    }

    widget.onCreate(result);
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Header section
            Text(
              'New Flutter Project',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 32),

            // Form section - wizard steps
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: _currentStep == 1
                      ? CreateProjectStep1(
                          initialDirectory: widget.initialDirectory,
                          testInitialDirectory:
                              CreateProjectScreen._testInitialDirectory,
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
                        )
                      : CreateProjectStep2(
                          projectName: _userFinalProjectName.isNotEmpty
                              ? _userFinalProjectName
                              : (_finalProjectName ?? 'Project'),
                          projectLocation: _userDirectory.isNotEmpty
                              ? _userDirectory
                              : (selectedDirectory ??
                                    directoryController!.text),
                          wantsLocalization: _wantsLocalization,
                          selectedLanguages: _selectedLanguages,
                          defaultLanguage: _selectedLanguage,
                          onWantsLocalizationChanged:
                              _onWantsLocalizationChanged,
                          onLanguageSelectionChanged:
                              _onLanguageSelectionChanged,
                          onDefaultLanguageChanged: _onDefaultLanguageChanged,
                        ),
                ),
              ),
            ),

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
                  if (_currentStep == 1)
                    ElevatedButton(
                      onPressed: _canGoToNextStep() ? _nextStep : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                      child: const Text('Next'),
                    ),

                  // Step 2: Create button
                  if (_currentStep == 2)
                    ElevatedButton(
                      onPressed: _handleCreate,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                      child: const Text('Create'),
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
