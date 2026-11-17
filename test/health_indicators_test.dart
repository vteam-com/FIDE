import 'package:fide/constants/constants.dart';
import 'package:fide/models/dependency_version.dart';
import 'package:fide/models/health_check.dart';
import 'package:fide/models/health_indicators.dart';
import 'package:fide/models/status_tone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HealthIndicators.issues', () {
    test('a healthy project has none', () {
      const health = HealthIndicators(hasPubspecLock: true);

      expect(health.issues('/demo'), isEmpty);
    });

    test('each failed check becomes an issue with how to fix it', () {
      final health = HealthIndicators(
        buildErrors: 2,
        largeFiles: [
          for (var i = 0; i <= AppMetric.maxAllowedLargeFiles; i++)
            'assets/big$i.bin',
        ],
      );
      final issues = health.issues('/demo');

      expect(issues.map((issue) => issue.label), [
        HealthCheck.missingLock.issueLabel(1),
        '2 build errors',
        '${AppMetric.maxAllowedLargeFiles + 1} large files',
      ]);
      expect(issues[1].tone, StatusTone.error);
      expect(issues[1].findings, isEmpty);
      final large = issues.last;
      expect(large.tone, StatusTone.info);
      expect(large.rootPath, '/demo');
      expect(large.findings.first.path, '/demo/assets/big0.bin');
      expect(large.findings.first.text, 'big0.bin');
      expect(large.guidance, contains('Git LFS'));
      // Without a project folder the files can't be located
      expect(health.issues(null).last.findings, isEmpty);
    });

    test('a few large files are no issue', () {
      const health = HealthIndicators(
        hasPubspecLock: true,
        largeFiles: ['big'],
      );

      expect(health.issues('/demo'), isEmpty);
    });
  });

  group('DependencyVersion', () {
    test('reads pubspec values', () {
      expect(
        DependencyVersion.fromPubspec('^1.0.0'),
        const DependencyVersion.hosted('^1.0.0'),
      );
      expect(
        DependencyVersion.fromPubspec({'sdk': 'flutter'}),
        DependencyVersion.sdk,
      );
      expect(
        DependencyVersion.fromPubspec({'path': '../x'}),
        DependencyVersion.complex,
      );
      expect(DependencyVersion.fromPubspec(null), DependencyVersion.complex);
    });

    test('only hosted versions are on pub.dev', () {
      expect(const DependencyVersion.hosted('1.0.0').isHosted, true);
      expect(DependencyVersion.sdk.isHosted, false);
      expect(DependencyVersion.complex.isHosted, false);
    });

    test('survives the JSON round trip', () {
      for (final version in [
        const DependencyVersion.hosted('^2.0.0'),
        DependencyVersion.sdk,
        DependencyVersion.complex,
      ]) {
        expect(DependencyVersion.fromJson(version.toJson()), version);
      }
    });
  });
}
