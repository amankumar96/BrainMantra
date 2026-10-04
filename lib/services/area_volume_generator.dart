import 'dart:math' show pi;

import '../models/app_language.dart';
import '../models/diagram_data.dart';
import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

/// Builds an area/volume question — rectangle area, circle area, or
/// cylinder volume, picked at random each call (the same "one PuzzleType,
/// several sub-cases" shape `ShapeReasoningGenerator` already uses). Every
/// answer is computed directly from the generated dimensions, never a
/// separately-chosen value.
abstract final class AreaVolumeGenerator {
  static Puzzle generate({
    required int tier,
    required RngService rng,
    required AppLanguage language,
  }) {
    final params = DifficultyCurve.paramsForTier(tier);
    final range = _lengthRangeForTier(tier);

    return switch (rng.nextInt(0, 2)) {
      0 => _rectangle(tier, params.timeLimitSeconds, range, rng, language),
      1 => _circle(tier, params.timeLimitSeconds, range, rng, language),
      _ => _cylinder(tier, params.timeLimitSeconds, range, rng, language),
    };
  }

  static Puzzle _rectangle(
    int tier,
    int timeLimitSeconds,
    ({int min, int max}) range,
    RngService rng,
    AppLanguage language,
  ) {
    final length = rng.nextInt(range.min, range.max);
    final width = rng.nextInt(range.min, range.max);
    final area = length * width;
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.areaVolume,
      questionText: language == AppLanguage.english
          ? 'Find the area of a rectangle with length $length cm and width '
              '$width cm.'
          : '$length सेमी लंबाई और $width सेमी चौड़ाई वाले एक आयत का '
              'क्षेत्रफल ज्ञात करें।',
      options: buildNumericMcOptions(area, rng, spread: _spreadFor(area)),
      correctAnswer: area,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      diagramData: DiagramData(
        kind: DiagramKind.rectangle,
        dimensions: [length.toDouble(), width.toDouble()],
      ),
      hint: language == AppLanguage.english
          ? 'Area = length × width'
          : 'क्षेत्रफल = लंबाई × चौड़ाई',
    );
  }

  static Puzzle _circle(
    int tier,
    int timeLimitSeconds,
    ({int min, int max}) range,
    RngService rng,
    AppLanguage language,
  ) {
    final radius = rng.nextInt(range.min, range.max);
    final area = (pi * radius * radius).round();
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.areaVolume,
      questionText: language == AppLanguage.english
          ? 'Find the area of a circle with radius $radius cm.'
          : '$radius सेमी अर्धव्यास (radius) वाले एक वृत्त का क्षेत्रफल '
              'ज्ञात करें।',
      options: buildNumericMcOptions(area, rng, spread: _spreadFor(area)),
      correctAnswer: area,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      diagramData:
          DiagramData(kind: DiagramKind.circle, dimensions: [radius.toDouble()]),
      hint: language == AppLanguage.english ? 'Area = πr²' : 'क्षेत्रफल = πr²',
    );
  }

  static Puzzle _cylinder(
    int tier,
    int timeLimitSeconds,
    ({int min, int max}) range,
    RngService rng,
    AppLanguage language,
  ) {
    final radius = rng.nextInt(range.min, range.max);
    final height = rng.nextInt(range.min, range.max);
    final volume = (pi * radius * radius * height).round();
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.areaVolume,
      questionText: language == AppLanguage.english
          ? 'Find the volume of a cylinder with radius $radius cm and '
              'height $height cm.'
          : '$radius सेमी अर्धव्यास (radius) और $height सेमी ऊंचाई वाले '
              'एक बेलन (cylinder) का आयतन ज्ञात करें।',
      options: buildNumericMcOptions(volume, rng, spread: _spreadFor(volume)),
      correctAnswer: volume,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      diagramData: DiagramData(
        kind: DiagramKind.cylinder,
        dimensions: [radius.toDouble(), height.toDouble()],
      ),
      hint: language == AppLanguage.english
          ? 'Volume = πr²h'
          : 'आयतन = πr²h',
    );
  }

  /// Distractor spread scales with the magnitude of the answer, so a
  /// volume in the hundreds doesn't get distractors only 2-3 apart.
  static int _spreadFor(int answer) => (answer * 0.25).round().clamp(4, 300);

  /// TUNABLE — initial defaults: small, easy-to-multiply-by-hand
  /// dimensions at low tiers, larger ones at high tiers.
  static ({int min, int max}) _lengthRangeForTier(int tier) => switch (tier) {
        1 => (min: 2, max: 8),
        2 => (min: 3, max: 12),
        3 => (min: 4, max: 18),
        _ => (min: 5, max: 25),
      };
}
