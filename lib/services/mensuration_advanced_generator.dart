import 'dart:math' show pi;

import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

/// Mensuration & Geometry Formulas (Phase 11B, topics 8 & 19) — the
/// shapes not already covered by `area_volume_generator.dart`
/// (rectangle/circle/cylinder) or `perimeter_generator.dart`: sphere,
/// cone, hemisphere, Heron's-formula triangles, and rhombus area. Cone
/// dimensions are drawn from Pythagorean triples so the slant height is
/// always an exact integer, never a rounded √(r²+h²).
abstract final class MensurationAdvancedGenerator {
  // (radius, height, slant) triples for the cone sub-case.
  static const _coneTriples = [(3, 4, 5), (6, 8, 10), (5, 12, 13), (9, 12, 15)];

  // (a, b, c, area) — integer-sided triangles with an exact Heron area.
  static const _heronTriangles = [
    (3, 4, 5, 6),
    (5, 5, 6, 12),
    (5, 5, 8, 12),
    (6, 8, 10, 24),
    (9, 12, 15, 54),
    (13, 14, 15, 84),
  ];

  static Puzzle generate({required int tier, required RngService rng}) {
    final params = DifficultyCurve.paramsForTier(tier);
    return switch (rng.nextInt(0, 4)) {
      0 => _sphere(tier, params.timeLimitSeconds, rng),
      1 => _cone(tier, params.timeLimitSeconds, rng),
      2 => _hemisphere(tier, params.timeLimitSeconds, rng),
      3 => _heron(tier, params.timeLimitSeconds, rng),
      _ => _rhombus(tier, params.timeLimitSeconds, rng),
    };
  }

  static Puzzle _sphere(int tier, int timeLimitSeconds, RngService rng) {
    final r = rng.nextInt(_rangeForTier(tier).min, _rangeForTier(tier).max);
    final wantsVolume = rng.nextBool();
    final answer = wantsVolume
        ? ((4 / 3) * pi * r * r * r).round()
        : (4 * pi * r * r).round();
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.mensurationAdvanced,
      questionText: 'Find the ${wantsVolume ? 'volume' : 'surface area'} '
          'of a sphere with radius $r cm.',
      options: buildNumericMcOptions(answer, rng, spread: _spreadFor(answer)),
      correctAnswer: answer,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: wantsVolume ? 'Volume = (4/3)πr³' : 'Surface area = 4πr²',
    );
  }

  static Puzzle _cone(int tier, int timeLimitSeconds, RngService rng) {
    final (r, h, l) = _coneTriples[rng.nextInt(0, _coneTriples.length - 1)];
    final wantsVolume = rng.nextBool();
    final answer = wantsVolume
        ? ((1 / 3) * pi * r * r * h).round()
        : (pi * r * l).round();
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.mensurationAdvanced,
      questionText: wantsVolume
          ? 'Find the volume of a cone with radius $r cm and height $h cm.'
          : 'Find the curved surface area of a cone with radius $r cm and '
              'slant height $l cm.',
      options: buildNumericMcOptions(answer, rng, spread: _spreadFor(answer)),
      correctAnswer: answer,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: wantsVolume ? 'Volume = (1/3)πr²h' : 'Curved surface area = πrl',
    );
  }

  static Puzzle _hemisphere(int tier, int timeLimitSeconds, RngService rng) {
    final r = rng.nextInt(_rangeForTier(tier).min, _rangeForTier(tier).max);
    final choice = rng.nextInt(0, 2);
    final answer = switch (choice) {
      0 => ((2 / 3) * pi * r * r * r).round(),
      1 => (2 * pi * r * r).round(),
      _ => (3 * pi * r * r).round(),
    };
    final label = switch (choice) {
      0 => 'volume',
      1 => 'curved surface area',
      _ => 'total surface area',
    };
    final hint = switch (choice) {
      0 => 'Volume = (2/3)πr³',
      1 => 'Curved surface area = 2πr²',
      _ => 'Total surface area = 3πr²',
    };
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.mensurationAdvanced,
      questionText: 'Find the $label of a hemisphere with radius $r cm.',
      options: buildNumericMcOptions(answer, rng, spread: _spreadFor(answer)),
      correctAnswer: answer,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: hint,
    );
  }

  static Puzzle _heron(int tier, int timeLimitSeconds, RngService rng) {
    final (a, b, c, area) =
        _heronTriangles[rng.nextInt(0, _heronTriangles.length - 1)];
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.mensurationAdvanced,
      questionText:
          "Using Heron's formula, find the area of a triangle with sides "
          '$a cm, $b cm, and $c cm.',
      options: buildNumericMcOptions(area, rng, spread: _spreadFor(area)),
      correctAnswer: area,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: 's = (a+b+c)/2, Area = √[s(s-a)(s-b)(s-c)]',
    );
  }

  static Puzzle _rhombus(int tier, int timeLimitSeconds, RngService rng) {
    final range = _rangeForTier(tier);
    // Diagonals kept even so d1*d2/2 is always an exact integer.
    final d1 = rng.nextInt(range.min, range.max) * 2;
    final d2 = rng.nextInt(range.min, range.max) * 2;
    final area = (d1 * d2) ~/ 2;
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.mensurationAdvanced,
      questionText: 'Find the area of a rhombus with diagonals $d1 cm and '
          '$d2 cm.',
      options: buildNumericMcOptions(area, rng, spread: _spreadFor(area)),
      correctAnswer: area,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: 'Area = ½ × d₁ × d₂',
    );
  }

  static int _spreadFor(int answer) => (answer * 0.25).round().clamp(4, 400);

  static ({int min, int max}) _rangeForTier(int tier) => switch (tier) {
        1 => (min: 2, max: 6),
        2 => (min: 3, max: 9),
        3 => (min: 4, max: 14),
        _ => (min: 5, max: 20),
      };
}
