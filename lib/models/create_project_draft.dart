import 'package:fide/models/create_project_step.dart';
import 'package:fide/models/project_creation_request.dart';
import 'package:fide/models/project_name.dart';
import 'package:fide/models/tool_availability.dart';
import 'package:path/path.dart' as p;

/// What the new-project wizard has collected so far, shared by its steps.
class CreateProjectDraft {
  /// Language every project starts with as its default.
  static const String initialLanguage = ProjectCreationRequest.englishLanguage;

  /// Languages selected when the wizard opens.
  static const Set<String> initialLanguages = {initialLanguage, _french};

  static const String _french = 'fr';

  /// Creates a draft; every value defaults to what the wizard opens with.
  const CreateProjectDraft({
    this.name = '',
    this.parentDirectory,
    this.wantsLocalization = true,
    this.languages = initialLanguages,
    this.defaultLanguage = initialLanguage,
    this.useAi = false,
    this.description = '',
    this.step = CreateProjectStep.nameAndFolder,
    this.created = false,
  });

  /// Whether creation has finished successfully.
  final bool created;

  /// Language the generated app falls back to.
  final String defaultLanguage;

  /// What the app should do, for AI generation.
  final String description;

  /// Languages to set up when [wantsLocalization].
  final Set<String> languages;

  /// Project name as typed.
  final String name;

  /// Folder the project is created in; null until resolved.
  final String? parentDirectory;

  /// The wizard page on show.
  final CreateProjectStep step;

  /// Whether to generate the starter code with AI.
  final bool useAi;

  /// Whether to set up localization.
  final bool wantsLocalization;

  /// Whether the details step has what creation needs: a name and a
  /// folder.
  bool get canLeaveDetails =>
      packageName != null && (parentDirectory?.isNotEmpty ?? false);

  /// [name] as a valid Dart package name; null while it is empty.
  String? get packageName => ProjectName.normalize(name);

  /// Full path of the project to create; null until both the folder and a
  /// name are known.
  String? get projectPath {
    final directory = parentDirectory;
    final package = packageName;
    if (directory == null || directory.isEmpty || package == null) return null;
    return p.join(directory, package);
  }

  /// Copies this draft with the given values replaced.
  CreateProjectDraft copyWith({
    String? name,
    String? parentDirectory,
    bool? wantsLocalization,
    Set<String>? languages,
    String? defaultLanguage,
    bool? useAi,
    String? description,
    CreateProjectStep? step,
    bool? created,
  }) => CreateProjectDraft(
    name: name ?? this.name,
    parentDirectory: parentDirectory ?? this.parentDirectory,
    wantsLocalization: wantsLocalization ?? this.wantsLocalization,
    languages: languages ?? this.languages,
    defaultLanguage: defaultLanguage ?? this.defaultLanguage,
    useAi: useAi ?? this.useAi,
    description: description ?? this.description,
    step: step ?? this.step,
    created: created ?? this.created,
  );

  /// The request creating this draft's project with the installed [tools];
  /// AI generation and Git only run when their tool is available.
  ProjectCreationRequest toRequest(ToolAvailability tools) =>
      ProjectCreationRequest(
        name: packageName ?? ProjectName.fallback,
        parentDirectory: parentDirectory ?? '',
        flutterAvailable: tools.flutterAvailable,
        languages: wantsLocalization ? {...languages} : null,
        defaultLanguage: defaultLanguage,
        useAi: useAi && tools.ollamaAvailable,
        description: useAi ? description.trim() : '',
        initGit: tools.gitAvailable,
      );
}
