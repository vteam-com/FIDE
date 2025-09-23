import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:process_run/shell.dart';

/// A dialog for creating new Flutter projects
class CreateProjectDialog extends StatefulWidget {
  final String? initialDirectory;

  // Static variable for testing to override initial directory
  static String? _testInitialDirectory;

  const CreateProjectDialog({super.key, this.initialDirectory});

  // Method to set initial directory for testing
  static void setTestInitialDirectory(String? directory) {
    _testInitialDirectory = directory;
  }

  @override
  State<CreateProjectDialog> createState() => _CreateProjectDialogState();
}

class _CreateProjectDialogState extends State<CreateProjectDialog> {
  final TextEditingController nameController = TextEditingController();
  TextEditingController? directoryController;
  String? selectedDirectory;

  // Flutter status tracking
  bool _flutterStatusChecked = false;
  bool _flutterAvailable = false;
  String? _flutterVersion;

  // Git status tracking
  bool _gitStatusChecked = false;
  bool _gitAvailable = false;
  String? _gitVersion;

  @override
  void initState() {
    super.initState();
    _initializeDirectoryController();
    _checkFlutterStatus();
    _checkGitStatus();
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
        CreateProjectDialog._testInitialDirectory ??
        widget.initialDirectory ??
        (await getApplicationDocumentsDirectory()).path;
    setState(() {
      directoryController = TextEditingController(text: directoryPath);
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    directoryController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading if directory controller is not initialized yet
    if (directoryController == null) {
      return const AlertDialog(
        title: Text('New Flutter Project'),
        content: SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return AlertDialog(
      title: const Text('New Flutter Project'),
      content: SizedBox(
        width: 500,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
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
                const SizedBox(width: 8),
                TextButton(
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
                  child: const Text('Browse'),
                ),
              ],
            ),
            // Flutter status above action buttons
            if (_flutterStatusChecked)
              Container(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  spacing: 8,
                  children: [
                    Icon(
                      _flutterAvailable ? Icons.check_circle : Icons.error,
                      color: _flutterAvailable ? Colors.green : Colors.red,
                      size: 16,
                    ),

                    Text(
                      _flutterAvailable
                          ? 'Flutter SDK: $_flutterVersion'
                          : 'Flutter SDK: Not Found',
                      style: TextStyle(
                        color: _flutterAvailable ? Colors.green : Colors.red,
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
                                title: const Text('Install Flutter SDK'),
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
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
            // Git status above action buttons
            if (_gitStatusChecked)
              Container(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  spacing: 8,
                  children: [
                    Icon(
                      _gitAvailable ? Icons.check_circle : Icons.error,
                      color: _gitAvailable ? Colors.green : Colors.red,
                      size: 16,
                    ),

                    Text(
                      _gitAvailable ? 'Git: $_gitVersion' : 'Git: Not Found',
                      style: TextStyle(
                        color: _gitAvailable ? Colors.green : Colors.red,
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
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

      actions: [
        // Action buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () {
                final directory =
                    selectedDirectory ?? directoryController!.text;
                if (nameController.text.isNotEmpty && directory.isNotEmpty) {
                  Navigator.of(
                    context,
                  ).pop({'name': nameController.text, 'directory': directory});
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Shows the create project dialog and returns the result
Future<Map<String, String>?> showCreateProjectDialog(
  BuildContext context, {
  String? initialDirectory,
}) async {
  return showDialog<Map<String, String>>(
    context: context,
    builder: (BuildContext context) {
      return CreateProjectDialog(initialDirectory: initialDirectory);
    },
  );
}
