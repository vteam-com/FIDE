import 'package:fide/constants/constants.dart';
import 'package:fide/models/project_name.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/widgets/app_text_field.dart';
import 'package:fide/widgets/status_indicator.dart';
import 'package:fide/widgets/step_header.dart';
import 'package:fide/widgets/tool_status_row.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Represents `CreateProjectStep1`.
class CreateProjectStep1 extends StatefulWidget {
  const CreateProjectStep1({
    super.key,
    required this.initialDirectory,
    required this.defaultParentDirectory,
    required this.flutterStatusChecked,
    required this.flutterAvailable,
    required this.flutterVersion,
    required this.gitStatusChecked,
    required this.gitAvailable,
    required this.gitVersion,
    required this.ollamaStatusChecked,
    required this.ollamaAvailable,
    required this.onProjectNameChanged,
    required this.onDirectoryChanged,
    required this.onValidationChanged,
    required this.onUseAIChanged,
  });

  final String? defaultParentDirectory;

  final bool flutterAvailable;

  final bool flutterStatusChecked;

  final String? flutterVersion;

  final bool gitAvailable;

  final bool gitStatusChecked;

  final String? gitVersion;

  final String? initialDirectory;

  final bool ollamaAvailable;

  final bool ollamaStatusChecked;

  final void Function(String directory) onDirectoryChanged;

  final void Function(String projectName, String? finalProjectName)
  onProjectNameChanged;

  final void Function(bool useAI) onUseAIChanged;

  final void Function(bool canProceed) onValidationChanged;

  @override
  State<CreateProjectStep1> createState() => _CreateProjectStep1State();
}

class _CreateProjectStep1State extends State<CreateProjectStep1> {
  String? _directory;

  String? _finalProjectName;

  /// How to install Flutter, shown when it isn't found.
  static const String _flutterInstallInstructions =
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
      'For detailed instructions, visit: https://flutter.dev/docs/get-started/install';

  /// How to install Git, shown when it isn't found.
  static const String _gitInstallInstructions =
      'Git is not installed or not available in PATH.\n\n'
      'To install Git:\n\n'
      '• macOS: Install Xcode Command Line Tools:\n'
      '  xcode-select --install\n'
      '  Or install Git from: https://git-scm.com/download/mac\n\n'
      '• Linux (Ubuntu/Debian):\n'
      '  sudo apt-get update && sudo apt-get install git\n\n'
      '• Windows: Download from https://git-scm.com/download/win\n\n'
      'For detailed instructions, visit: https://git-scm.com/book/en/v2/Getting-Started-Installing-Git';

  /// This step's place in the wizard.
  static const int _stepNumber = 1;
  bool _useAI = false;

  final TextEditingController descriptionController = TextEditingController();

  final TextEditingController directoryController = TextEditingController();

  final TextEditingController nameController = TextEditingController();

  String? selectedDirectory;

  @override
  void initState() {
    super.initState();
    nameController.addListener(_onProjectNameChanged);
    _initializeDirectoryController();
    // Defer notifying parent until after first build to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onUseAIChanged(_useAI);
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    directoryController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppIconSize.xLarge,
      children: [
        StepHeader(number: _stepNumber, title: 'Project Details'),

        const SizedBox(height: AppSpacing.xLarge),

        AppTextField(
          controller: nameController,
          labelText: 'Project Name',
          hintText: 'Enter project name',
        ),

        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: directoryController,
                labelText: 'Parent Directory',
                hintText: 'Select parent directory',
                readOnly: true,
              ),
            ),
            const SizedBox(width: AppSpacing.xLarge),
            ElevatedButton(
              onPressed: _handleBrowseDirectory,
              child: const Text('Browse'),
            ),
          ],
        ),

        // Show final project name if it's different from input
        if (_finalProjectName != null &&
            _finalProjectName != nameController.text)
          StatusIndicator.tone(
            StatusTone.warning,
            label: 'Project name will be: "$_finalProjectName"',
          ),

        if (widget.flutterStatusChecked)
          ToolStatusRow(
            name: 'Flutter SDK',
            available: widget.flutterAvailable,
            version: widget.flutterVersion,
            installInstructions: _flutterInstallInstructions,
          ),

        if (widget.gitStatusChecked)
          ToolStatusRow(
            name: 'Git',
            available: widget.gitAvailable,
            version: widget.gitVersion,
            installInstructions: _gitInstallInstructions,
          ),

        // AI-powered generation toggle
        Row(
          children: [
            Expanded(
              child: Text(
                'Use AI-powered app generation (requires Ollama)',
                style: AppTextStyle.label,
              ),
            ),
            Switch(
              value: _useAI,
              onChanged: widget.ollamaStatusChecked && widget.ollamaAvailable
                  ? _onUseAIChanged
                  : null,
            ),
          ],
        ),

        // Description field only if AI is enabled AND Ollama is available
        if (_useAI && widget.ollamaStatusChecked && widget.ollamaAvailable)
          AppTextField(
            controller: descriptionController,
            labelText: 'App Description (AI-powered generation)',
            hintText: 'Describe what kind of app you want to create...',
            maxLines: AppMetric.aiInputMaxLines,
            minLines: AppMetric.doubleLineLimit,
          ),
      ],
    );
  }

  /// Opens a directory picker and updates the project directory selection.
  void _handleBrowseDirectory() async {
    final selectedDir = await FilePicker.getDirectoryPath();
    if (selectedDir != null && mounted) {
      setState(() {
        selectedDirectory = selectedDir;
        directoryController.text = selectedDir;
        _directory = selectedDir;
      });
      widget.onDirectoryChanged(selectedDir);
      _updateValidation();
    }
  }

  /// Resolves the initial directory (from args or documents folder) and populates the directory controller.
  Future<void> _initializeDirectoryController() async {
    final directoryPath =
        widget.defaultParentDirectory ??
        widget.initialDirectory ??
        (await getApplicationDocumentsDirectory()).path;
    if (!mounted) return;
    setState(() {
      directoryController.text = directoryPath;
      _directory = directoryPath;
    });
    widget.onDirectoryChanged(directoryPath);
    // Delay validation update until after widget is built to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateValidation();
    });
  }

  /// Reacts to project name field changes by validating and notifying the parent widget.
  void _onProjectNameChanged() {
    final validatedName = ProjectName.normalize(nameController.text);
    if (_finalProjectName != validatedName) {
      setState(() {
        _finalProjectName = validatedName;
      });
      widget.onProjectNameChanged(nameController.text, validatedName);
      _updateValidation();
    }
  }

  void _onUseAIChanged(bool value) {
    setState(() {
      _useAI = value;
    });
    widget.onUseAIChanged(value);
  }

  void _updateValidation() {
    final canProceed =
        _finalProjectName != null &&
        _directory != null &&
        _directory!.isNotEmpty;
    widget.onValidationChanged(canProceed);
  }
}
