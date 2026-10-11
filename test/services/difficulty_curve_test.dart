import 'package:flutter_test/flutter_test.dart';
import 'package:brain_mantra/services/difficulty_curve.dart';
import 'package:brain_mantra/services/rng_service.dart';

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
    test('tier 6 has a strictly larger time limit than tier 1', () {
      final tier1 = DifficultyCurve.paramsForTier(1);
      final tier6 = DifficultyCurve.paramsForTier(6);
      expect(tier6.timeLimitSeconds, greaterThan(tier1.timeLimitSeconds));
    });

    test('tier 6 has a strictly wider operand range than tier 1', () {
      final tier1 = DifficultyCurve.paramsForTier(1);
      final tier6 = DifficultyCurve.paramsForTier(6);
      final tier1Range = tier1.math.maxOperand - tier1.math.minOperand;
      final tier6Range = tier6.math.maxOperand - tier6.math.minOperand;
      expect(tier6Range, greaterThan(tier1Range));
    });

    test('familyTreeHopDepth never decreases from tier 1 to 6, and is '
        'strictly higher at tier 6 than tier 1', () {
      final depths = [1, 2, 3, 4, 5, 6]
          .map((t) => DifficultyCurve.paramsForTier(t).reasoning
              .familyTreeHopDepth)
          .toList();
      for (var i = 1; i < depths.length; i++) {
        expect(depths[i], greaterThanOrEqualTo(depths[i - 1]));
      }
      expect(depths.last, greaterThan(depths.first));
    });

    test('allowed math operators grow (or stay the same) with tier', () {
      final tier1Ops =
          DifficultyCurve.paramsForTier(1).math.allowedOperators.length;
      final tier6Ops =
          DifficultyCurve.paramsForTier(6).math.allowedOperators.length;
      expect(tier6Ops, greaterThanOrEqualTo(tier1Ops));
    });

    test('out-of-range tiers clamp instead of throwing', () {
      expect(DifficultyCurve.paramsForTier(0).tier, equals(1));
      expect(DifficultyCurve.paramsForTier(-5).tier, equals(1));
      expect(DifficultyCurve.paramsForTier(99).tier, equals(6));
    });
  });

  group('randomTierForScore', () {
    test('below 25: always tier 1', () {
      final rng = RngService.seeded('band-low');
      for (var i = 0; i < 300; i++) {
        expect(DifficultyCurve.randomTierForScore(10, rng), equals(1));
      }
    });

    test('24 is still below the band (always tier 1)', () {
      final rng = RngService.seeded('band-boundary-low');
      for (var i = 0; i < 100; i++) {
        expect(DifficultyCurve.randomTierForScore(24, rng), equals(1));
      }
    });

    test('25 to 49: only ever picks tier 1 or 2, both appear', () {
      final rng = RngService.seeded('band-step1');
      final seen = <int>{};
      for (var i = 0; i < 300; i++) {
        final tier = DifficultyCurve.randomTierForScore(35, rng);
        expect(tier, anyOf(1, 2));
        seen.add(tier);
      }
      expect(seen, equals({1, 2}));
      expect(DifficultyCurve.randomTierForScore(25, rng), anyOf(1, 2));
      expect(DifficultyCurve.randomTierForScore(49, rng), anyOf(1, 2));
    });

    test('50 to 74: only ever picks tier 3 or 4, both appear (leaning 3)',
        () {
      final rng = RngService.seeded('band-step2');
      final seen = <int>{};
      var tier3Count = 0;
      for (var i = 0; i < 300; i++) {
        final tier = DifficultyCurve.randomTierForScore(60, rng);
        expect(tier, anyOf(3, 4));
        seen.add(tier);
        if (tier == 3) tier3Count++;
      }
      expect(seen, equals({3, 4}));
      expect(tier3Count, greaterThan(150)); // leans tier 3 (2:1 weight)
    });

    test('75 to 99: only ever picks tier 3 or 4, both appear (leaning 4)',
        () {
      final rng = RngService.seeded('band-step3');
      final seen = <int>{};
      var tier4Count = 0;
      for (var i = 0; i < 300; i++) {
        final tier = DifficultyCurve.randomTierForScore(90, rng);
        expect(tier, anyOf(3, 4));
        seen.add(tier);
        if (tier == 4) tier4Count++;
      }
      expect(seen, equals({3, 4}));
      expect(tier4Count, greaterThan(150)); // leans tier 4 (2:1 weight)
    });

    test('100 and above: only ever picks tier 5 or 6, both appear', () {
      final rng = RngService.seeded('band-high');
      final seen = <int>{};
      for (var i = 0; i < 300; i++) {
        final tier = DifficultyCurve.randomTierForScore(500, rng);
        expect(tier, anyOf(5, 6));
        seen.add(tier);
      }
      expect(seen, equals({5, 6}));
      expect(DifficultyCurve.randomTierForScore(100, rng), anyOf(5, 6));
    });

    test('negative scores behave like the lowest band (no crash)', () {
      final rng = RngService.seeded('band-negative');
      for (var i = 0; i < 50; i++) {
        expect(DifficultyCurve.randomTierForScore(-10, rng), equals(1));
      }
    });

    test('same seed produces the same tier sequence', () {
      // Mirrors real usage: one shared RngService instance drawing across
      // repeated calls (as GameController does), not a fresh seed per call.
      final scores = [0, 30, 60, 90, 400, 40, 600];
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
    test('only ever picks tier 5 or 6', () {
      final rng = RngService.seeded('high-tier');
      for (var i = 0; i < 300; i++) {
        expect(DifficultyCurve.randomHighTier(rng), anyOf(5, 6));
      }
    });

    test('both tier 5 and tier 6 actually occur (not always the same one)', () {
      final rng = RngService.seeded('high-tier-spread');
      final seen = <int>{};
      for (var i = 0; i < 200; i++) {
        seen.add(DifficultyCurve.randomHighTier(rng));
      }
      expect(seen, equals({5, 6}));
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
