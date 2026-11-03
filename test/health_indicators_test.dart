import 'package:fide/constants/constants.dart';
import 'package:fide/models/dependency_version.dart';
import 'package:fide/models/health_check.dart';
import 'package:fide/models/health_indicators.dart';
import 'package:fide/models/status_tone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HealthIndicators.deductions', () {
    test('a healthy project loses nothing', () {
      const health = HealthIndicators(hasPubspecLock: true);

      expect(health.deductions.map((deduction) => deduction.check), [
        HealthCheck.missingLock,
        HealthCheck.buildErrors,
        HealthCheck.buildWarnings,
        HealthCheck.largeFiles,
      ]);
      expect(health.deductions.any((deduction) => deduction.isActive), false);
      expect(health.qualityScore, AppMetric.maxScore);
    });

    test('a deduction becomes the issue the health card shows', () {
      const health = HealthIndicators(
        buildErrors: 2,
        largeFiles: ['assets/big.bin'],
      );
      final issues = {
        for (final deduction in health.deductions)
          deduction.check: deduction.toIssue('/demo'),
      };

      expect(issues[HealthCheck.missingLock]?.label, 'Missing pubspec.lock');
      expect(issues[HealthCheck.buildErrors]?.label, '2 build errors');
      expect(issues[HealthCheck.buildErrors]?.tone, StatusTone.error);
      expect(issues[HealthCheck.buildErrors]?.findings, isEmpty);
      final large = issues[HealthCheck.largeFiles]!;
      expect(large.tone, StatusTone.info);
      expect(large.rootPath, '/demo');
      expect(large.findings.single.path, '/demo/assets/big.bin');
      expect(large.findings.single.text, 'big.bin');
      expect(large.guidance, contains('Git LFS'));
      // Without a project folder the files can't be located
      expect(health.deductions.last.toIssue(null).findings, isEmpty);
    });

    test('the score subtracts every active deduction, capped', () {
      final health = HealthIndicators(
        buildErrors: 100,
        buildWarnings: 1,
        largeFiles: List.filled(AppMetric.maxAllowedLargeFiles + 1, 'big'),
      );
      final points = {
        for (final deduction in health.deductions)
          deduction.check: deduction.points,
      };

      expect(points, {
        HealthCheck.missingLock: AppMetric.missingLockDeduction,
        HealthCheck.buildErrors: AppMetric.buildErrorDeductionMax,
        HealthCheck.buildWarnings: AppMetric.buildWarningDeductionPer,
        HealthCheck.largeFiles: AppMetric.largeFilesDeduction,
      });
      expect(
        health.qualityScore,
        AppMetric.maxScore - points.values.reduce((a, b) => a + b),
      );
    });

    test('a few large files are counted but cost nothing', () {
      const health = HealthIndicators(
        hasPubspecLock: true,
        largeFiles: ['big'],
      );
      final largeFiles = health.deductions.last;

      expect(largeFiles.count, 1);
      expect(largeFiles.isActive, false);
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
