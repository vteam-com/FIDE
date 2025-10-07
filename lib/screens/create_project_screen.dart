import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:process_run/shell.dart';

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
    nameController.addListener(_onProjectNameChanged);
    _initializeDirectoryController();
    _checkFlutterStatus();
    _checkGitStatus();
    _checkOllamaStatus();
  }

  void _onProjectNameChanged() {
    _validateProjectName(nameController.text);
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

  /// Validates and converts project name to valid Flutter package name
  String? _validateProjectName(String inputName) {
    if (inputName.isEmpty) {
      return null;
    }

    // Only normalize if needed (spaces, special chars, etc.)
    String normalized = inputName;

    // Replace spaces and special characters with underscores
    normalized = normalized.replaceAll(RegExp(r'[^a-z0-9_]'), '_');

    // Remove consecutive underscores
    normalized = normalized.replaceAll(RegExp(r'_+'), '_');

    // Remove leading/trailing underscores
    normalized = normalized.replaceAll(RegExp(r'^_+|_+$'), '');

    // Ensure it doesn't start with a digit
    if (normalized.isNotEmpty && normalized.startsWith(RegExp(r'[0-9]'))) {
      normalized = 'app_$normalized';
    }

    // Ensure it's not empty after normalization
    if (normalized.isEmpty) {
      normalized = 'flutter_app';
    }

    // Check if it's a reserved Dart word and prefix if needed
    const reservedWords = {
      'abstract',
      'as',
      'assert',
      'async',
      'await',
      'break',
      'case',
      'catch',
      'class',
      'const',
      'continue',
      'default',
      'deferred',
      'do',
      'dynamic',
      'else',
      'enum',
      'export',
      'extends',
      'extension',
      'external',
      'factory',
      'false',
      'final',
      'finally',
      'for',
      'function',
      'get',
      'hide',
      'if',
      'implements',
      'import',
      'in',
      'interface',
      'is',
      'late',
      'library',
      'mixin',
      'new',
      'null',
      'on',
      'operator',
      'part',
      'required',
      'rethrow',
      'return',
      'set',
      'show',
      'static',
      'super',
      'switch',
      'sync',
      'this',
      'throw',
      'true',
      'try',
      'typedef',
      'var',
      'void',
      'while',
      'with',
      'yield',
    };

    if (reservedWords.contains(normalized)) {
      normalized = '${normalized}_app';
    }

    // Update the final name state
    setState(() {
      _finalProjectName = normalized;
    });

    return normalized;
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Header section
            Text(
              'New Flutter Project',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 32),

            // Form section
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 24,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Project Name',
                          hintText: 'Enter project name',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: directoryController,
                              decoration: const InputDecoration(
                                labelText: 'Parent Directory',
                                hintText: 'Select parent directory',
                                border: OutlineInputBorder(),
                              ),
                              readOnly: true,
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: () async {
                              final selectedDir = await FilePicker.platform
                                  .getDirectoryPath();
                              if (selectedDir != null && mounted) {
                                setState(() {
                                  selectedDirectory = selectedDir;
                                  directoryController!.text = selectedDir;
                                });
                              }
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Text('Browse'),
                            ),
                          ),
                        ],
                      ),

                      // Description field only if Ollama is available
                      if (_ollamaStatusChecked && _ollamaAvailable)
                        TextField(
                          controller: descriptionController,
                          decoration: const InputDecoration(
                            labelText:
                                'App Description (AI-powered generation)',
                            hintText:
                                'Describe what kind of app you want to create...',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                          minLines: 2,
                        ),

                      // Show final project name if it's different from input
                      if (_finalProjectName != null &&
                          _finalProjectName != nameController.text)
                        Container(
                          padding: const EdgeInsets.only(top: 4, bottom: 16),
                          child: Row(
                            spacing: 8,
                            children: [
                              Icon(
                                _flutterAvailable
                                    ? Icons.check_circle
                                    : Icons.error,
                                color: Colors.orange,
                                size: 16,
                              ),

                              Text(
                                'Project name will be: "$_finalProjectName"',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Flutter status
                      if (_flutterStatusChecked)
                        Container(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            spacing: 8,
                            children: [
                              Icon(
                                _flutterAvailable
                                    ? Icons.check_circle
                                    : Icons.error,
                                color: _flutterAvailable
                                    ? Colors.green
                                    : Colors.red,
                                size: 16,
                              ),

                              Text(
                                _flutterAvailable
                                    ? 'Flutter SDK: $_flutterVersion'
                                    : 'Flutter SDK: Not Found',
                                style: TextStyle(
                                  color: _flutterAvailable
                                      ? Colors.green
                                      : Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (!_flutterAvailable) ...[
                                TextButton(
                                  onPressed: () {
                                    // Show installation instructions
                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                          title: const Text(
                                            'Install Flutter SDK',
                                          ),
                                          content: const SingleChildScrollView(
                                            child: Text(
                                              'Flutter SDK is not installed or not available in PATH.\n\n'
                                              'To install Flutter:\n\n'
                                              '1. Visit: https://flutter.dev/docs/get-started/install\n'
                                              '2. Download the Flutter SDK for your platform\n'
                                              '3. Extract the SDK to a location (e.g., ~/flutter)\n'
                                              '4. Add the flutter/bin directory to your PATH:\n'
                                              '   - macOS/Linux: Add to ~/.bashrc or ~/.zshrc:\n'
                                              '     export PATH="\$PATH:~/flutter/bin"\n'
                                              '   - Windows: Add to System Environment Variables\n'
                                              '5. Run: flutter doctor\n\n'
                                              'For detailed instructions, visit: https://flutter.dev/docs/get-started/install',
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(context).pop(),
                                              child: const Text('OK'),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(50, 30),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Install',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                      // Git status
                      if (_gitStatusChecked)
                        Container(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            spacing: 8,
                            children: [
                              Icon(
                                _gitAvailable
                                    ? Icons.check_circle
                                    : Icons.error,
                                color: _gitAvailable
                                    ? Colors.green
                                    : Colors.red,
                                size: 16,
                              ),

                              Text(
                                _gitAvailable
                                    ? 'Git: $_gitVersion'
                                    : 'Git: Not Found',
                                style: TextStyle(
                                  color: _gitAvailable
                                      ? Colors.green
                                      : Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (!_gitAvailable) ...[
                                TextButton(
                                  onPressed: () {
                                    // Show installation instructions
                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                          title: const Text('Install Git'),
                                          content: const SingleChildScrollView(
                                            child: Text(
                                              'Git is not installed or not available in PATH.\n\n'
                                              'To install Git:\n\n'
                                              '• macOS: Install Xcode Command Line Tools:\n'
                                              '  xcode-select --install\n'
                                              '  Or install Git from: https://git-scm.com/download/mac\n\n'
                                              '• Linux (Ubuntu/Debian):\n'
                                              '  sudo apt-get update && sudo apt-get install git\n\n'
                                              '• Windows: Download from https://git-scm.com/download/win\n\n'
                                              'For detailed instructions, visit: https://git-scm.com/book/en/v2/Getting-Started-Installing-Git',
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(context).pop(),
                                              child: const Text('OK'),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(50, 30),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Install',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
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
                  ElevatedButton(
                    onPressed: () {
                      final directory =
                          selectedDirectory ?? directoryController!.text;
                      if (nameController.text.isNotEmpty &&
                          directory.isNotEmpty) {
                        // Use the validated project name or validate it now
                        final projectName =
                            _finalProjectName ??
                            _validateProjectName(nameController.text) ??
                            nameController.text;

                        final result = <String, String>{
                          'name': projectName,
                          'directory': directory,
                        };

                        if (_ollamaAvailable &&
                            descriptionController.text.isNotEmpty) {
                          result['description'] = descriptionController.text;
                        }

                        widget.onCreate(result);
                      }
                    },
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
