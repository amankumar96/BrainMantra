import '../models/app_language.dart';
import '../models/diagram_data.dart';
import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

/// Builds a perimeter question — fencing a rectangular garden, a ribbon
/// around a square photo frame, or walking the boundary of a triangular
/// park (picked at random each call, the same "one PuzzleType, several
/// sub-cases" shape `AreaVolumeGenerator` already uses). Every real-life
/// framing here asks for the *distance around* a shape, which is what
/// separates this topic from `areaVolume` (area/volume, the space a shape
/// covers).
abstract final class PerimeterGenerator {
  static Puzzle generate({
    required int tier,
    required RngService rng,
    required AppLanguage language,
  }) {
    final params = DifficultyCurve.paramsForTier(tier);
    final range = _lengthRangeForTier(tier);

    return switch (rng.nextInt(0, 2)) {
      0 => _rectangleGarden(
          tier, params.timeLimitSeconds, range, rng, language),
      1 => _squareFrame(tier, params.timeLimitSeconds, range, rng, language),
      _ => _triangularPark(
          tier, params.timeLimitSeconds, range, rng, language),
    };
  }

  static Puzzle _rectangleGarden(
    int tier,
    int timeLimitSeconds,
    ({int min, int max}) range,
    RngService rng,
    AppLanguage language,
  ) {
    final length = rng.nextInt(range.min, range.max);
    final width = rng.nextInt(range.min, range.max);
    final perimeter = 2 * (length + width);
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.perimeter,
      questionText: language == AppLanguage.english
          ? 'You want to put a fence around a rectangular garden that is '
              '$length m long and $width m wide. How many metres of fencing '
              'do you need?'
          : 'आप एक आयताकार बगीचे के चारों ओर बाड़ लगाना चाहते हैं, जो '
              '$length मीटर लंबा और $width मीटर चौड़ा है। आपको कितने मीटर '
              'बाड़ की जरूरत है?',
      options: buildNumericMcOptions(perimeter, rng, spread: _spreadFor(perimeter)),
      correctAnswer: perimeter,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      diagramData: DiagramData(
        kind: DiagramKind.rectangle,
        dimensions: [length.toDouble(), width.toDouble()],
      ),
      hint: language == AppLanguage.english
          ? 'Perimeter of a rectangle = 2 × (length + width)'
          : 'आयत की परिमाप = 2 × (लंबाई + चौड़ाई)',
    );
  }

  static Puzzle _squareFrame(
    int tier,
    int timeLimitSeconds,
    ({int min, int max}) range,
    RngService rng,
    AppLanguage language,
  ) {
    final side = rng.nextInt(range.min, range.max);
    final perimeter = 4 * side;
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.perimeter,
      questionText: language == AppLanguage.english
          ? 'A square photo frame has sides of $side cm. How much '
              'ribbon do you need to go all the way around its border?'
          : 'एक चौकोर फोटो फ्रेम की भुजा $side सेमी है। उसके बॉर्डर के '
              'चारों ओर पूरा घेरने के लिए कितना रिबन चाहिए?',
      options: buildNumericMcOptions(perimeter, rng, spread: _spreadFor(perimeter)),
      correctAnswer: perimeter,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      diagramData: DiagramData(
        kind: DiagramKind.rectangle,
        dimensions: [side.toDouble(), side.toDouble()],
      ),
      hint: language == AppLanguage.english
          ? 'Perimeter of a square = 4 × side'
          : 'वर्ग की परिमाप = 4 × भुजा',
    );
  }

  static Puzzle _triangularPark(
    int tier,
    int timeLimitSeconds,
    ({int min, int max}) range,
    RngService rng,
    AppLanguage language,
  ) {
    // Sides drawn close together around a random common base (offsets
    // 0-2, base clamped >= 3) so the triangle inequality always holds
    // without a retry loop: worst case largest = base+2, smallest pair
    // sums to at least 2*base, and 2*base > base+2 whenever base > 2.
    final minBase = range.min < 3 ? 3 : range.min;
    final maxBase = minBase > range.max ? minBase : range.max;
    final base = rng.nextInt(minBase, maxBase);
    final a = base + rng.nextInt(0, 2);
    final b = base + rng.nextInt(0, 2);
    final c = base + rng.nextInt(0, 2);
    final perimeter = a + b + c;
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.perimeter,
      questionText: language == AppLanguage.english
          ? 'A triangular park has sides measuring $a m, $b m and $c m. Find '
              'the total distance around the park (its perimeter).'
          : 'एक त्रिकोणीय पार्क की भुजाएं $a मीटर, $b मीटर और $c मीटर हैं। '
              'पार्क के चारों ओर की कुल दूरी (परिमाप) ज्ञात करें।',
      options: buildNumericMcOptions(perimeter, rng, spread: _spreadFor(perimeter)),
      correctAnswer: perimeter,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      diagramData: DiagramData(
        kind: DiagramKind.polygon,
        vertices: trianglePolygonVertices(a, b, c),
      ),
      hint: language == AppLanguage.english
          ? 'Perimeter of a triangle = sum of its three sides'
          : 'त्रिभुज की परिमाप = उसकी तीनों भुजाओं का योग',
    );
  }

  /// Distractor spread scales with the magnitude of the answer, same
  /// rationale as `AreaVolumeGenerator._spreadFor`.
  static int _spreadFor(int answer) => (answer * 0.25).round().clamp(2, 100);

  /// TUNABLE — initial defaults. Small, easy-to-add dimensions at low
  /// tiers; larger ones at high tiers. Kept >= 3 always so the triangle
  /// sub-case's base assumption above holds at every tier.
  static ({int min, int max}) _lengthRangeForTier(int tier) => switch (tier) {
        1 => (min: 3, max: 10),
        2 => (min: 3, max: 15),
        3 => (min: 4, max: 20),
        _ => (min: 5, max: 30),
      };
}
