import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:path/path.dart' as p;

part 'app_icon_review.app_icon_master.dart';
part 'app_icon_review.app_icon_platform_review.dart';
part 'app_icon_review.app_icon_problem.dart';
part 'app_icon_review.app_icon_slot_info.dart';

/// What the App Icons view shows for a project: the platforms it has,
/// each with its icon slots and problems, and the master image the icons
/// are generated from. Read from fCheck's report once, off the UI thread,
/// so the view only reads values.
class AppIconReview {
  /// Every problem found, across all platforms.
  final List<AppIconProblem> issues;

  /// The image the icons are generated from; null when there is none.
  final AppIconMaster? master;

  /// The platforms the project has a folder for, in fCheck's order.
  final List<AppIconPlatformReview> platforms;

  /// Creates a review.
  const AppIconReview({
    required this.platforms,
    required this.issues,
    this.master,
  });

  /// Reads fCheck's [report] of the project at [projectPath], keeping the
  /// platforms whose id is in [presentPlatforms]: those with a folder.
  factory AppIconReview.fromReport(
    fcheck.AppIconReport report, {
    required String projectPath,
    required Set<String> presentPlatforms,
    AppIconMaster? master,
  }) {
    final issues = [
      for (final issue in report.issues) AppIconProblem.fromIssue(issue),
    ];
    return AppIconReview(
      issues: issues,
      master: master,
      platforms: [
        for (final platform in fcheck.AppIconPlatform.values)
          if (presentPlatforms.contains(platform.name))
            AppIconPlatformReview(
              id: platform.name,
              label: platform.label,
              issues: [
                for (final issue in issues)
                  if (issue.platformId == platform.name) issue,
              ],
              slots: [
                for (final slot in report.slots)
                  if (slot.platform == platform)
                    AppIconSlotInfo.fromSlot(
                      slot,
                      projectPath: projectPath,
                      issues: issues,
                    ),
              ],
            ),
      ],
    );
  }

  /// How many platforms have a problem.
  int get brokenPlatformCount => brokenPlatformLabels.length;

  /// The names of the platforms with a problem, in the order the problems
  /// name them.
  Set<String> get brokenPlatformLabels => {
    for (final issue in issues) issue.platformLabel,
  };

  /// The platforms with a problem, the ones Fix all regenerates.
  List<AppIconPlatformReview> get brokenPlatforms => [
    for (final platform in platforms)
      if (platform.hasIssues) platform,
  ];

  /// Whether the project has icon slots or icon problems to show.
  bool get hasIcons =>
      issues.isNotEmpty ||
      platforms.any((platform) => platform.slots.isNotEmpty);

  /// How many problems the platform with id [platformId] has.
  int issueCountOf(String platformId) =>
      issues.where((issue) => issue.platformId == platformId).length;
}
