import 'dart:io';

import 'package:fcheck/fcheck.dart';
import 'package:fide/models/app_icon_review.dart';
import 'package:fide/services/app_icon_inspector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// A report of two iOS slots, one still Flutter's default, with one issue.
const AppIconReport _report = AppIconReport(
  slots: [
    AppIconSlot(
      platform: AppIconPlatform.ios,
      group: 'iPhone',
      label: '20pt @2x',
      filePath: 'ios/Icon-40.png',
      size: 40,
      file: AppIconFileInfo(width: 40, height: 40),
      isFlutterDefault: true,
    ),
    AppIconSlot(
      platform: AppIconPlatform.ios,
      group: 'App Store',
      label: '1024pt',
      filePath: null,
      size: 1024,
      file: null,
    ),
    AppIconSlot(
      platform: AppIconPlatform.windows,
      group: 'Runner',
      label: 'app_icon.ico',
      filePath: 'windows/app_icon.ico',
      size: 256,
      file: AppIconFileInfo(width: 256, height: 256, icoSizes: {16, 256}),
    ),
  ],
  issues: [
    AppIconIssue(
      platform: AppIconPlatform.ios,
      type: AppIconIssueType.flutterDefault,
      filePath: 'ios/Icon-40.png',
      message: 'Still the default icon',
    ),
  ],
);

void main() {
  group('AppIconReview.fromReport', () {
    final review = AppIconReview.fromReport(
      _report,
      projectPath: '/demo',
      presentPlatforms: {'ios', 'windows'},
      master: const AppIconMaster('/demo/master.png', width: 1024, height: 512),
    );

    test('keeps the platforms present, with their slots and problems', () {
      expect(review.platforms.map((platform) => platform.id), [
        'ios',
        'windows',
      ]);
      final ios = review.platforms.first;
      expect(ios.label, 'iOS');
      expect(ios.hasIssues, isTrue);
      expect(ios.groups.keys, ['iPhone', 'App Store']);
      expect(review.platforms.last.hasIssues, isFalse);
      expect(review.brokenPlatforms.map((platform) => platform.id), ['ios']);
      expect(review.brokenPlatformCount, 1);
      expect(review.brokenPlatformLabels, {'iOS'});
      expect(review.issueCountOf('ios'), 1);
      expect(review.issueCountOf('windows'), 0);
      expect(review.hasIcons, isTrue);
    });

    test('a slot knows its file, its problems and whether it is shown', () {
      final [iphone, store] = review.platforms.first.slots;
      expect(iphone.path, '/demo/ios/Icon-40.png');
      expect(iphone.readablePath, iphone.path);
      expect(iphone.problems, ['Still the default icon']);
      expect(iphone.isFlutterDefault, isTrue);
      expect(iphone.isFilled, isTrue);
      expect(store.path, isNull);
      expect(store.readablePath, isNull);
      expect(store.isFilled, isFalse);
      expect(store.problems, isEmpty);
      final ico = review.platforms.last.slots.single;
      expect(ico.isIco, isTrue);
      expect([ico.fileWidth, ico.fileHeight], [256, 256]);
    });

    test('the master knows whether it is good enough', () {
      final master = review.master!;
      expect(master.isReadable, isTrue);
      expect(master.isNotSquare, isTrue);
      expect(master.isTooSmall, isTrue);
      const unreadable = AppIconMaster('/demo/missing.png');
      expect(unreadable.isReadable, isFalse);
      expect(unreadable.isNotSquare, isFalse);
      expect(unreadable.isTooSmall, isFalse);
      const good = AppIconMaster(
        '/demo/good.png',
        width: AppIconMaster.recommendedSize,
        height: AppIconMaster.recommendedSize,
      );
      expect(good.isNotSquare || good.isTooSmall, isFalse);
    });

    test('a project without icons has nothing to show', () {
      const empty = AppIconReview(platforms: [], issues: []);
      expect(empty.hasIcons, isFalse);
      expect(empty.brokenPlatforms, isEmpty);
    });
  });

  group('AppIconInspector.review', () {
    late Directory project;

    setUp(() {
      project = Directory.systemTemp.createTempSync('fide_review_');
      Directory(p.join(project.path, 'ios')).createSync();
      final image = img.Image(width: 64, height: 48)
        ..clear(img.ColorRgb8(30, 120, 200));
      File(p.join(project.path, 'master.png'))
          .writeAsBytesSync(img.encodePng(image));
    });
    tearDown(() => project.deleteSync(recursive: true));

    test('reads the platform folders and the master image', () async {
      final review = await const AppIconInspector().review(
        project.path,
        masterPath: p.join(project.path, 'master.png'),
      );

      expect(review.platforms.map((platform) => platform.id), ['ios']);
      expect(review.platforms.single.hasIssues, isTrue);
      expect([review.master?.width, review.master?.height], [64, 48]);
    });

    test('without a master there is none to show', () async {
      final review = await const AppIconInspector().review(project.path);

      expect(review.master, isNull);
    });
  });
}
