import 'package:fide/models/flutter_platform.dart';
import 'package:fide/models/locale_number.dart';
import 'package:fide/models/project_paths.dart';
import 'package:fide/models/quality_issue.dart';
import 'package:fide/models/quality_issue.quality_finding.dart';
import 'package:fide/models/quick_fix.dart';
import 'package:fide/models/status_tone.dart';

part 'cocoa_pods_migration.cocoa_pods_blocker.dart';
part 'cocoa_pods_migration.hand_added_pod.dart';

/// Where a project stands on its way from CocoaPods to Swift Package
/// Manager on iOS and macOS, and the issues left in the way.
class CocoaPodsMigration {
  /// A project with no Apple platform, or nothing left to migrate.
  static const CocoaPodsMigration none = CocoaPodsMigration(
    projectPath: '',
    podPlatforms: {},
  );

  /// The Podfile name, in each Apple platform folder.
  static const String podfileName = 'Podfile';

  /// A `pod 'Name'` line of a Podfile; group 1 is the name.
  static final RegExp _podLine = RegExp(r'''^\s*pod\s+['"]([^'"]+)['"]''');

  /// How to replace the packages still on CocoaPods.
  static const String _blockersGuidance =
      'These packages ship an iOS plugin without a Swift Package Manager '
      'manifest (`ios/<package>/Package.swift` or '
      '`darwin/<package>/Package.swift`), so Flutter falls back to '
      'CocoaPods for the whole app. Apple and Flutter have moved to Swift '
      'Package Manager, and the CocoaPods trunk becomes read-only on '
      'December 2, 2026.\n\n'
      'For each package:\n\n'
      '1. Upgrade it: newer versions often add Swift Package Manager '
      'support.\n'
      '2. When its latest version still lacks it, replace it with a '
      'maintained package that has it, or ask its maintainers.\n'
      '3. A package listed "through" another one goes away once that '
      'direct dependency is upgraded or replaced.';

  /// How to move pods added by hand.
  static const String _handAddedGuidance =
      'Flutter only migrates plugins: add these libraries as Swift packages '
      'in Xcode (File › Add Package Dependencies…) or through a plugin '
      'that supports Swift Package Manager, then remove them from the '
      'Podfile.';

  /// Why turning Swift Package Manager off is a dead end.
  static const String _swiftPackageManagerOffGuidance =
      'Flutter uses Swift Package Manager by default since 3.44 and will '
      'stop allowing it to be turned off. Remove '
      '`enable-swift-package-manager: false` from the pubspec.';

  /// What removing CocoaPods does.
  static const String _removeGuidance =
      'Every plugin supports Swift Package Manager, so CocoaPods is no '
      'longer needed. Removing it runs `pod deintegrate`, deletes the '
      'Podfile, Podfile.lock, `Pods/` and `.symlinks/`, and drops the '
      'CocoaPods `#include` lines of the `Flutter/*.xcconfig` files. Build '
      'each Apple platform afterwards: Flutter re-creates a Podfile if a '
      'plugin still needs CocoaPods.';

  /// Creates the migration state of the project at [projectPath].
  const CocoaPodsMigration({
    required this.projectPath,
    required this.podPlatforms,
    this.blockers = const [],
    this.handAddedPods = const [],
    this.swiftPackageManagerOffLine,
  });

  /// Packages that still need CocoaPods, by package name.
  final List<CocoaPodsBlocker> blockers;

  /// Pods the Podfiles add by hand.
  final List<HandAddedPod> handAddedPods;

  /// Apple platforms that still have a Podfile.
  final Set<FlutterPlatform> podPlatforms;

  /// Root of the project.
  final String projectPath;

  /// 1-based pubspec line turning Swift Package Manager off; null when it
  /// is on.
  final int? swiftPackageManagerOffLine;

  /// Whether CocoaPods can go: some platform still has it and nothing
  /// needs it.
  bool get canRemove =>
      podPlatforms.isNotEmpty &&
      blockers.isEmpty &&
      handAddedPods.isEmpty &&
      swiftPackageManagerOffLine == null;

  /// Whether the project is on Swift Package Manager only.
  bool get isDone =>
      podPlatforms.isEmpty &&
      blockers.isEmpty &&
      swiftPackageManagerOffLine == null;

  /// What stands between the project and Swift Package Manager only, each
  /// with how to fix it; empty when [isDone].
  List<QualityIssue> get issues => [
    if (swiftPackageManagerOffLine case final line?)
      QualityIssue(
        tone: StatusTone.error,
        label: 'Swift Package Manager is turned off',
        guidance: _swiftPackageManagerOffGuidance,
        findings: [
          QualityFinding(
            path: _pubspec,
            line: line,
            text: 'enable-swift-package-manager: false',
          ),
        ],
        rootPath: projectPath,
        aiVerb: null,
      ),
    if (blockers.isNotEmpty)
      QualityIssue(
        label: '${blockers.length.count('package')} still on CocoaPods',
        title: 'Still on CocoaPods',
        guidance: _blockersGuidance,
        findings: [
          for (final blocker in blockers)
            QualityFinding(
              path: _pubspec,
              line: blocker.line,
              text: blocker.description,
            ),
        ],
        rootPath: projectPath,
        quickFixes: const [QuickFix.upgradePackages],
        aiVerb: null,
      ),
    if (handAddedPods.isNotEmpty)
      QualityIssue(
        label: '${handAddedPods.length.count('pod')} added by hand',
        title: 'Pod added by hand',
        guidance: _handAddedGuidance,
        findings: [
          for (final pod in handAddedPods)
            QualityFinding(path: pod.podfile, line: pod.line, text: pod.name),
        ],
        rootPath: projectPath,
        aiVerb: null,
      ),
    if (canRemove)
      QualityIssue(
        tone: StatusTone.info,
        label:
            'CocoaPods still set up for '
            '${podPlatforms.map((platform) => platform.displayName).join(', ')}',
        guidance: _removeGuidance,
        rootPath: projectPath,
        quickFixes: const [QuickFix.removeCocoaPods],
        aiVerb: null,
      ),
  ];

  /// The project's pubspec.
  String get _pubspec => ProjectPaths(projectPath).pubspec;

  /// The pods the Podfile at [podfile], reading [content], adds by hand:
  /// Flutter's own Podfile only installs the plugins' pods.
  static List<HandAddedPod> handAddedPodsIn(String podfile, String content) {
    final lines = content.split('\n');
    return [
      for (var index = 0; index < lines.length; index++)
        if (_podLine.firstMatch(lines[index]) case final match?)
          HandAddedPod(podfile: podfile, name: match[1]!, line: index + 1),
    ];
  }
}
