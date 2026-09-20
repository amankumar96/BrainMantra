import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:brain_mantra/services/ads_service.dart';

void main() {
  test('ads are always capped at PG (13+ general audience), any build', () {
    for (final debug in [true, false]) {
      final config = AdsService.buildRequestConfiguration(debugMode: debug);
      expect(config.maxAdContentRating, equals(MaxAdContentRating.pg));
    }
  });

  test('test-device ids are debug-only, never in a release build', () {
    expect(
      AdsService.buildRequestConfiguration(debugMode: false).testDeviceIds,
      isNull,
    );
    expect(
      AdsService.buildRequestConfiguration(debugMode: true).testDeviceIds,
      isNotEmpty,
    );
  });

  test('not child-directed (matches the 13+ Play Target Audience)', () {
    expect(AdsService.isChildDirectedTreatment, isFalse);
    expect(
      AdsService.buildRequestConfiguration(debugMode: false)
          .ageRestrictedTreatment,
      isNull,
    );
  });
}
