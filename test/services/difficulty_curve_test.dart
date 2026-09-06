import 'package:flutter_test/flutter_test.dart';
import 'package:math_blitz/services/difficulty_curve.dart';
import 'package:math_blitz/services/rng_service.dart';

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
    // Phase 2 amendment: time limits moved from an 8-20 SECOND fast-blitz
    // range to a 2-30 MINUTE exam-pacing range, which also flips the
    // relationship — a harder question now gets MORE time to work
    // through, not less, unlike the original arcade-style design.
    test('tier 4 has a strictly larger time limit than tier 1', () {
      final tier1 = DifficultyCurve.paramsForTier(1);
      final tier4 = DifficultyCurve.paramsForTier(4);
      expect(tier4.timeLimitSeconds, greaterThan(tier1.timeLimitSeconds));
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

  group('randomTierForScore', () {
    test('below 30: only ever picks tier 1 or 2', () {
      final rng = RngService.seeded('band-low');
      for (var i = 0; i < 300; i++) {
        final tier = DifficultyCurve.randomTierForScore(10, rng);
        expect(tier, anyOf(1, 2));
      }
    });

    test('30 to just under 300: only ever picks tier 2, 3, or 4', () {
      final rng = RngService.seeded('band-mid');
      for (var i = 0; i < 300; i++) {
        final tier = DifficultyCurve.randomTierForScore(150, rng);
        expect(tier, anyOf(2, 3, 4));
      }
    });

    test('300 and above: can pick any tier, but 3/4 are the majority', () {
      final rng = RngService.seeded('band-high');
      final counts = {1: 0, 2: 0, 3: 0, 4: 0};
      const samples = 1000;
      for (var i = 0; i < samples; i++) {
        final tier = DifficultyCurve.randomTierForScore(500, rng);
        counts[tier] = counts[tier]! + 1;
      }
      final tier3And4 = counts[3]! + counts[4]!;
      // "mostly" tier 3+, not exclusively — expect a clear majority
      // without demanding every single draw be 3 or 4.
      expect(tier3And4, greaterThan(samples ~/ 2));
    });

    test('negative scores behave like the lowest band (no crash)', () {
      final rng = RngService.seeded('band-negative');
      for (var i = 0; i < 50; i++) {
        expect(
          DifficultyCurve.randomTierForScore(-10, rng),
          anyOf(1, 2),
        );
      }
    });

    test('same seed produces the same tier sequence', () {
      // Mirrors real usage: one shared RngService instance drawing across
      // repeated calls (as GameController does), not a fresh seed per call.
      final scores = [0, 50, 400, 40, 600];
      final rngA = RngService.seeded('shared-tier-seed');
      final rngB = RngService.seeded('shared-tier-seed');
      final sequenceA =
          scores.map((s) => DifficultyCurve.randomTierForScore(s, rngA)).toList();
      final sequenceB =
          scores.map((s) => DifficultyCurve.randomTierForScore(s, rngB)).toList();
      expect(sequenceA, equals(sequenceB));
    });
  });

  group('randomHighTier', () {
    test('only ever picks tier 3 or 4', () {
      final rng = RngService.seeded('high-tier');
      for (var i = 0; i < 300; i++) {
        expect(DifficultyCurve.randomHighTier(rng), anyOf(3, 4));
      }
    });

    test('both tier 3 and tier 4 actually occur (not always the same one)', () {
      final rng = RngService.seeded('high-tier-spread');
      final seen = <int>{};
      for (var i = 0; i < 200; i++) {
        seen.add(DifficultyCurve.randomHighTier(rng));
      }
      expect(seen, equals({3, 4}));
    });

    test('same seed produces the same tier sequence', () {
      final rngA = RngService.seeded('shared-high-tier-seed');
      final rngB = RngService.seeded('shared-high-tier-seed');
      final sequenceA =
          List.generate(20, (_) => DifficultyCurve.randomHighTier(rngA));
      final sequenceB =
          List.generate(20, (_) => DifficultyCurve.randomHighTier(rngB));
      expect(sequenceA, equals(sequenceB));
    });
  });
}
