import 'package:flutter_test/flutter_test.dart';
import 'package:brain_mantra/services/rng_service.dart';

// Draws an interleaved sequence of nextInt/nextBool calls, so a test can
// compare "did these two RngServices behave identically" in one shot.
List<Object> _draw20(RngService rng) {
  final results = <Object>[];
  for (var i = 0; i < 20; i++) {
    results.add(rng.nextInt(0, 1000000));
    results.add(rng.nextBool());
  }
  return results;
}

void main() {
  group('RngService.seeded determinism', () {
    test('same seed produces the same 20-call sequence every time', () {
      final first = _draw20(RngService.seeded('daily-2026-09-05'));
      final second = _draw20(RngService.seeded('daily-2026-09-05'));
      expect(second, equals(first));
    });

    test('different seeds produce different sequences', () {
      final a = _draw20(RngService.seeded('seed-a'));
      final b = _draw20(RngService.seeded('seed-b'));
      // Comparing whole 20-call sequences, not single draws: a false
      // collision across all 20 paired values is astronomically unlikely,
      // so this is a safe determinism check without needing a full
      // statistical randomness test suite.
      expect(a, isNot(equals(b)));
    });

    test('an empty seed string still produces a valid, stable sequence',
        () {
      final first = _draw20(RngService.seeded(''));
      final second = _draw20(RngService.seeded(''));
      expect(second, equals(first));
    });
  });

  group('RngService.free', () {
    test('1000 nextInt calls stay within the requested bounds', () {
      final rng = RngService.free();
      for (var i = 0; i < 1000; i++) {
        final value = rng.nextInt(1, 6);
        expect(value, inInclusiveRange(1, 6));
      }
    });

    test('1000 nextBool calls complete without throwing', () {
      final rng = RngService.free();
      for (var i = 0; i < 1000; i++) {
        // Just confirming no exception — the value itself is unconstrained.
        rng.nextBool();
      }
    });

    test('nextInt supports a single-value range (min == max)', () {
      final rng = RngService.free();
      expect(rng.nextInt(7, 7), equals(7));
    });
  });

  group('RngService.seeded bounds', () {
    test('nextInt always stays within the requested inclusive range', () {
      final rng = RngService.seeded('bounds-check');
      for (var i = 0; i < 1000; i++) {
        final value = rng.nextInt(-5, 5);
        expect(value, inInclusiveRange(-5, 5));
      }
    });
  });
}
