import 'package:flutter_test/flutter_test.dart';
import 'package:math_blitz/services/difficulty_curve.dart';

void main() {
  group('tierForScore', () {
    test('score 0 is tier 1', () {
      expect(DifficultyCurve.tierForScore(0), equals(1));
    });

    test('score just under the tier-2 threshold is still tier 1', () {
      expect(DifficultyCurve.tierForScore(99), equals(1));
    });

    test('score at the tier-2 threshold increments to tier 2', () {
      expect(DifficultyCurve.tierForScore(100), equals(2));
    });

    test('score at the tier-3 threshold increments to tier 3', () {
      expect(DifficultyCurve.tierForScore(300), equals(3));
    });

    test('score just under the tier-4 threshold is still tier 3', () {
      expect(DifficultyCurve.tierForScore(599), equals(3));
    });

    test('score at the tier-4 threshold increments to tier 4', () {
      expect(DifficultyCurve.tierForScore(600), equals(4));
    });

    test('a very high score stays capped at tier 4', () {
      expect(DifficultyCurve.tierForScore(999999), equals(4));
    });
  });

  group('paramsForTier', () {
    test('tier 4 has a strictly smaller time limit than tier 1', () {
      final tier1 = DifficultyCurve.paramsForTier(1);
      final tier4 = DifficultyCurve.paramsForTier(4);
      expect(tier4.timeLimitSeconds, lessThan(tier1.timeLimitSeconds));
    });

    test('tier 4 has a strictly wider operand range than tier 1', () {
      final tier1 = DifficultyCurve.paramsForTier(1);
      final tier4 = DifficultyCurve.paramsForTier(4);
      final tier1Range = tier1.math.maxOperand - tier1.math.minOperand;
      final tier4Range = tier4.math.maxOperand - tier4.math.minOperand;
      expect(tier4Range, greaterThan(tier1Range));
    });

    test('familyTreeHopDepth increases monotonically from tier 1 to 4', () {
      final depths = [1, 2, 3, 4]
          .map((t) => DifficultyCurve.paramsForTier(t).reasoning
              .familyTreeHopDepth)
          .toList();
      for (var i = 1; i < depths.length; i++) {
        expect(depths[i], greaterThan(depths[i - 1]));
      }
    });

    test('allowed math operators grow (or stay the same) with tier', () {
      final tier1Ops =
          DifficultyCurve.paramsForTier(1).math.allowedOperators.length;
      final tier4Ops =
          DifficultyCurve.paramsForTier(4).math.allowedOperators.length;
      expect(tier4Ops, greaterThanOrEqualTo(tier1Ops));
    });

    test('out-of-range tiers clamp instead of throwing', () {
      expect(DifficultyCurve.paramsForTier(0).tier, equals(1));
      expect(DifficultyCurve.paramsForTier(-5).tier, equals(1));
      expect(DifficultyCurve.paramsForTier(99).tier, equals(4));
    });
  });
}
