part of 'app_icon_review.dart';

/// One problem with a platform's app icons, as fCheck words it.
class AppIconProblem {
  /// Project-relative path of the file concerned, with `/` separators.
  final String filePath;

  /// What is wrong.
  final String message;

  /// The id of the platform concerned, its folder name such as `ios`.
  final String platformId;

  /// The name of the platform concerned, such as `iOS`.
  final String platformLabel;

  /// Creates a problem.
  const AppIconProblem({
    required this.platformId,
    required this.platformLabel,
    required this.filePath,
    required this.message,
  });

  /// Reads fCheck's [issue].
  factory AppIconProblem.fromIssue(fcheck.AppIconIssue issue) => AppIconProblem(
    platformId: issue.platform.name,
    platformLabel: issue.platform.label,
    filePath: issue.filePath,
    message: issue.message,
  );
}
