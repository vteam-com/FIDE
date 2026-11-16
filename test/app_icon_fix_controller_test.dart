import 'package:fcheck/fcheck.dart';
import 'package:fide/models/app_icon_review.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/providers/app_icon_fix_controller.dart';
import 'package:fide/services/app_icon_fixer.dart';
import 'package:fide/services/project_config_reader.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Writes nothing: records the platforms fixed and fails the ones in
/// [failing].
class FakeFixer extends AppIconFixer {
  const FakeFixer() : super(const ProjectConfigReader());

  static final List<AppIconPlatform> fixed = [];
  static final List<String> sources = [];
  static Set<AppIconPlatform> failing = {};

  @override
  Future<String> fixMaster(String masterPath) async =>
      '/demo/assets/master.png';

  @override
  Future<List<String>> fix(
    String projectPath,
    AppIconPlatform platform,
    String masterPath,
  ) async {
    fixed.add(platform);
    sources.add(masterPath);
    if (failing.contains(platform)) throw StateError('no icon set');
    return ['${platform.name}/icon.png'];
  }
}

/// The platforms a fix is asked for.
const List<AppIconPlatformReview> _platforms = [
  AppIconPlatformReview(id: 'ios', label: 'iOS', issues: [], slots: []),
  AppIconPlatformReview(id: 'web', label: 'Web', issues: [], slots: []),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Iterable<String>> reloaded;
  late List<String> used;
  late AppIconFixController controller;

  setUp(() {
    FakeFixer.fixed.clear();
    FakeFixer.sources.clear();
    FakeFixer.failing = {};
    reloaded = [];
    used = [];
    controller = AppIconFixController(
      fixer: const FakeFixer(),
      reloadWritten: (paths) async => reloaded.add(paths),
      useMaster: used.add,
    );
  });
  tearDown(() => controller.dispose());

  test('fixes each platform, reloads what it wrote and counts it', () async {
    final states = <Set<String>>[];
    controller.addListener(states.add, fireImmediately: false);
    PaintingBinding.instance.imageCache.maximumSize = 1;

    final outcome = await controller.fix('/demo', _platforms, '/m.png');

    expect(outcome.tone, StatusTone.success);
    expect(outcome.message, 'Wrote 2 files');
    expect(FakeFixer.fixed, [AppIconPlatform.ios, AppIconPlatform.web]);
    expect(reloaded.single, ['/demo/ios/icon.png', '/demo/web/icon.png']);
    expect(states, [
      {'ios', 'web'},
      {'web'},
      <String>{},
    ]);
    expect(PaintingBinding.instance.imageCache.currentSize, 0);
  });

  test('a platform that fails is named, the others still written', () async {
    FakeFixer.failing = {AppIconPlatform.ios};

    final outcome = await controller.fix('/demo', _platforms, '/m.png');

    expect(outcome.tone, StatusTone.error);
    expect(outcome.message, startsWith('iOS: '));
    expect(reloaded.single, ['/demo/web/icon.png']);
    expect(controller.state, isEmpty);
  });

  test('fixes the master first, then the platforms from it', () async {
    final states = <Set<String>>[];
    controller.addListener(states.add, fireImmediately: false);

    final outcome = await controller.fix(
      '/demo',
      _platforms.take(1),
      '/demo/assets/master.jpg',
      fixMaster: true,
    );

    expect(outcome.message, 'Wrote 2 files');
    expect(used, ['/demo/assets/master.png']);
    expect(FakeFixer.sources, ['/demo/assets/master.png']);
    expect(reloaded.single, ['/demo/assets/master.png', '/demo/ios/icon.png']);
    expect(states, [
      {AppIconFixController.masterId, 'ios'},
      {'ios'},
      <String>{},
    ]);
  });
}
