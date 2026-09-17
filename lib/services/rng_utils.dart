import 'dart:math' show acos, cos, sin;

import 'rng_service.dart';

/// Lays out an actual, proportioned triangle from its three side lengths
/// (`a`, `b`, `c`) via the law of cosines, flattened as
/// `DiagramKind.polygon` vertices (`[x0,y0,x1,y1,x2,y2]`): `v0`=(0,0),
/// `v1`=(c,0) (so |v0v1| = c), and `v2` placed using the angle at `v0` so
/// |v0v2| = b and |v1v2| = a — a real shape, not a generic outline.
/// `.polygon` (not `.triangle`, which always renders angle labels plus a
/// forced "?" on one vertex) is the right diagram kind wherever a
/// question is about side lengths, not angles — shared by every
/// mensuration generator that illustrates a triangle from its sides.
List<double> trianglePolygonVertices(int a, int b, int c) {
  final cosAngle0 = ((b * b + c * c - a * a) / (2 * b * c)).clamp(-1.0, 1.0);
  final angle0 = acos(cosAngle0);
  return [0, 0, c.toDouble(), 0, b * cos(angle0), b * sin(angle0)];
}

/// Shuffles [list] in place using [rng], via the standard Fisher-Yates
/// algorithm. Shared by every generator that needs to randomize the order
/// of a puzzle's multiple-choice options.
void shuffleList<T>(List<T> list, RngService rng) {
  for (var i = list.length - 1; i > 0; i--) {
    final j = rng.nextInt(0, i);
    final swap = list[i];
    list[i] = list[j];
    list[j] = swap;
  }
}

/// Builds a UUID-v4-*shaped* id string entirely from [rng].
///
/// Every puzzle generator should use this instead of leaving `Puzzle.id`
/// to its own default — the default uses the `uuid` package's own
/// independent randomness, which has no connection to [rng] at all. That
/// would silently break determinism: two calls to `RngService.seeded`
/// with the same seed would produce puzzles that are identical in every
/// field *except* id, which fails an exact `Puzzle ==` comparison and
/// would break Daily Challenge fairness (every player must generate a
/// byte-for-byte identical puzzle sequence from the same date seed).
String deterministicId(RngService rng) {
  const hexDigits = '0123456789abcdef';
  final buffer = StringBuffer();
  for (var i = 0; i < 32; i++) {
    if (i == 8 || i == 12 || i == 16 || i == 20) buffer.write('-');
    buffer.write(hexDigits[rng.nextInt(0, 15)]);
  }
  return buffer.toString();
}

/// Builds a shuffled list of 4 unique multiple-choice option *strings* for
/// a numeric puzzle answer: [correct] plus 3 unique distractors near it
/// (never negative, since no puzzle in this app shows a negative option).
/// Retries on collision, widening the search window if the immediate
/// neighborhood runs out of room — relevant mainly for very small correct
/// values (e.g. correct=1 has few non-negative neighbors).
List<String> buildNumericMcOptions(
  int correct,
  RngService rng, {
  required int spread,
}) {
  final distractors = <int>{};
  var currentSpread = spread < 1 ? 1 : spread;
  var attempts = 0;
  while (distractors.length < 3 && attempts < 60) {
    attempts++;
    final delta = rng.nextInt(-currentSpread, currentSpread);
    final candidate = correct + delta;
    if (candidate != correct && candidate >= 0) {
      distractors.add(candidate);
    }
    if (attempts % 20 == 0) currentSpread *= 2; // widen if struggling
  }
  // Defensive fallback (should be unreachable given the widening above,
  // but this must never throw or hang mid-fuzz-test): fill any remaining
  // slot by counting up from the largest distractor found so far.
  var filler =
      (distractors.isEmpty ? correct : distractors.reduce((a, b) => a > b ? a : b)) + 1;
  while (distractors.length < 3) {
    if (filler != correct) distractors.add(filler);
    filler++;
  }

  final options =
      [correct, ...distractors].map((n) => n.toString()).toList();
  shuffleList(options, rng);
  return options;
}

/// Builds a shuffled list of 4 unique multiple-choice option strings from
/// a fixed vocabulary: [correct] plus 3 distinct distractors drawn from
/// [candidates] (which must contain at least 3 entries other than
/// [correct]). Used where the options aren't numbers — e.g. family-tree
/// relationship terms.
List<String> buildMcOptionsFromCandidates(
  String correct,
  List<String> candidates,
  RngService rng,
) {
  final pool = candidates.where((c) => c != correct).toSet().toList();
  shuffleList(pool, rng);
  final options = [correct, ...pool.take(3)];
  shuffleList(options, rng);
  return options;
}

/// Greatest common divisor of two non-negative integers (Euclidean
/// algorithm). Used by [probability_generator.dart] to reduce a
/// favourable/total outcome count to its simplest fraction form, e.g.
/// `2/6` -> `1/3`.
int gcd(int a, int b) {
  var x = a.abs();
  var y = b.abs();
  while (y != 0) {
    final t = y;
    y = x % y;
    x = t;
  }
  return x == 0 ? 1 : x; // never divide by 0 if both inputs were 0
}
