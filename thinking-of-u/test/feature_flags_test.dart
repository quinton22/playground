import 'package:flutter_test/flutter_test.dart';
import 'package:thinking_of_u/config/feature_flags.dart';

void main() {
  group('FeatureFlags', () {
    test('defaultDailyLimit is 3', () {
      expect(FeatureFlags.defaultDailyLimit, equals(3));
    });

    test('maxDailyLimit is greater than defaultDailyLimit', () {
      expect(FeatureFlags.maxDailyLimit,
          greaterThan(FeatureFlags.defaultDailyLimit));
    });

    test('maxExtensionDays is positive', () {
      expect(FeatureFlags.maxExtensionDays, greaterThan(0));
    });

    test('extensionHours is positive', () {
      expect(FeatureFlags.extensionHours, greaterThan(0));
    });
  });
}
