import 'package:flutter_test/flutter_test.dart';
import 'package:defile/src/features/file_explorer/services/update_check_service.dart';

void main() {
  group('UpdateCheckResult.compareVersions', () {
    test('detects newer releases', () {
      expect(
        UpdateCheckResult.compareVersions('0.6.13', '0.6.12'),
        greaterThan(0),
      );
      expect(
        UpdateCheckResult.compareVersions('0.7.0', '0.6.12'),
        greaterThan(0),
      );
      expect(
        UpdateCheckResult.compareVersions('1.0.0', '0.6.12'),
        greaterThan(0),
      );
    });

    test('treats equal versions as equal regardless of the v prefix', () {
      expect(UpdateCheckResult.compareVersions('v0.6.12', '0.6.12'), 0);
      expect(UpdateCheckResult.compareVersions('0.6.12+1', '0.6.12'), 0);
    });

    test('detects older releases', () {
      expect(
        UpdateCheckResult.compareVersions('0.6.11', '0.6.12'),
        lessThan(0),
      );
      expect(
        UpdateCheckResult.compareVersions('0.5.9', '0.6.12'),
        lessThan(0),
      );
    });
  });

  group('UpdateCheckResult.hasUpdate', () {
    test('true when latest is newer than current', () {
      const UpdateCheckResult result = UpdateCheckResult(
        currentVersion: '0.6.12',
        latestVersion: '0.7.0',
      );
      expect(result.hasUpdate, isTrue);
    });

    test('false when up to date or the check failed', () {
      const UpdateCheckResult upToDate = UpdateCheckResult(
        currentVersion: '0.6.12',
        latestVersion: '0.6.12',
      );
      expect(upToDate.hasUpdate, isFalse);

      const UpdateCheckResult failed = UpdateCheckResult(
        currentVersion: '0.6.12',
        error: 'network unavailable',
      );
      expect(failed.hasUpdate, isFalse);
      expect(failed.succeeded, isFalse);
    });
  });
}
