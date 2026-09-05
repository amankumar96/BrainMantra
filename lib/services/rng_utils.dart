import 'rng_service.dart';

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
