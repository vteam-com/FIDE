import 'package:fide/constants/constants.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/providers/create_project_draft_notifier.dart';
import 'package:fide/providers/tool_availability_provider.dart';
import 'package:fide/widgets/app_text_field.dart';
import 'package:fide/widgets/status_indicator.dart';
import 'package:fide/widgets/step_header.dart';
import 'package:fide/widgets/tool_status_row.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The wizard's first step: project name, parent folder, the installed
/// tools and AI generation, all kept in [createProjectDraftProvider].
class CreateProjectStep1 extends ConsumerStatefulWidget {
  /// Creates the step.
  const CreateProjectStep1({super.key});

  @override
  ConsumerState<CreateProjectStep1> createState() => _CreateProjectStep1State();
}

class _CreateProjectStep1State extends ConsumerState<CreateProjectStep1> {
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

  late final TextEditingController _nameController;
  late final TextEditingController _directoryController;
  late final TextEditingController _descriptionController;

  CreateProjectDraftNotifier get _notifier =>
      ref.read(createProjectDraftProvider.notifier);

  @override
  void initState() {
    super.initState();
    final draft = ref.read(createProjectDraftProvider);
    _nameController = TextEditingController(text: draft.name);
    _directoryController = TextEditingController(text: draft.parentDirectory);
    _descriptionController = TextEditingController(text: draft.description);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _directoryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(createProjectDraftProvider);
    final tools = ref.watch(toolAvailabilityProvider).value;
    final packageName = draft.packageName;
    final ollamaAvailable = tools?.ollamaAvailable ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppIconSize.xLarge,
      children: [
        StepHeader(number: _stepNumber, title: 'Project Details'),

        const SizedBox(height: AppSpacing.xLarge),

        AppTextField(
          controller: _nameController,
          labelText: 'Project Name',
          hintText: 'Enter project name',
          onChanged: _notifier.setName,
        ),

        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _directoryController,
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
        if (packageName != null && packageName != draft.name)
          StatusIndicator.tone(
            StatusTone.warning,
            label: 'Project name will be: "$packageName"',
          ),

        if (tools != null) ...[
          ToolStatusRow(
            name: 'Flutter SDK',
            available: tools.flutterAvailable,
            version: tools.flutterVersion,
            installInstructions: _flutterInstallInstructions,
          ),
          ToolStatusRow(
            name: 'Git',
            available: tools.gitAvailable,
            version: tools.gitVersion,
            installInstructions: _gitInstallInstructions,
          ),
        ],

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
              value: draft.useAi,
              onChanged: ollamaAvailable ? _notifier.setUseAi : null,
            ),
          ],
        ),

        // Description field only if AI is enabled AND Ollama is available
        if (draft.useAi && ollamaAvailable)
          AppTextField(
            controller: _descriptionController,
            labelText: 'App Description (AI-powered generation)',
            hintText: 'Describe what kind of app you want to create...',
            maxLines: AppMetric.aiInputMaxLines,
            minLines: AppMetric.doubleLineLimit,
            onChanged: _notifier.setDescription,
          ),
      ],
    );
  }

  /// Opens a directory picker and makes the chosen folder the parent.
  Future<void> _handleBrowseDirectory() async {
    final selectedDir = await FilePicker.getDirectoryPath();
    if (selectedDir == null || !mounted) return;
    _directoryController.text = selectedDir;
    _notifier.setParentDirectory(selectedDir);
  }
}
