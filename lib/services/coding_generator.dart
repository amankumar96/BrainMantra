import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

/// Letter/Number/Word Coding (Phase 12, reasoning topic 5): a
/// letter-shift cipher applied to a real word, and a letter-to-number
/// substitution cipher (A=1, B=2, ...) — both classic coding-decoding
/// formats, both exact by construction (apply the same rule to a new
/// word/letter and ask for the result).
abstract final class CodingGenerator {
  static const _words = [
    'CAT', 'DOG', 'SUN', 'MAP', 'BIRD', 'FISH', 'STAR', 'TREE',
    'BOOK', 'LAMP', 'CHAIR', 'TABLE', 'HOUSE', 'PLANT',
  ];

  static Puzzle generate({required int tier, required RngService rng}) {
    final params = DifficultyCurve.paramsForTier(tier);
    return rng.nextBool()
        ? _letterShift(tier, params.timeLimitSeconds, rng)
        : _numberCode(tier, params.timeLimitSeconds, rng);
  }

  static Puzzle _letterShift(int tier, int timeLimitSeconds, RngService rng) {
    final maxShift = switch (tier) {
      1 => 2,
      2 => 3,
      3 => 4,
      _ => 5,
    };
    final shift = rng.nextInt(1, maxShift);
    final sample = _words[rng.nextInt(0, _words.length - 1)];
    var target = _words[rng.nextInt(0, _words.length - 1)];
    while (target == sample) {
      target = _words[rng.nextInt(0, _words.length - 1)];
    }
    String shiftWord(String w) => String.fromCharCodes(
          w.codeUnits.map((c) => ((c - 65 + shift) % 26) + 65),
        );
    final correct = shiftWord(target);
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.reasoningTest,
      type: PuzzleType.coding,
      questionText: 'In a certain code, $sample is written as '
          '${shiftWord(sample)}. How will $target be written in the same code?',
      options: buildMcOptionsFromCandidates(
        correct,
        [
          shiftWord(target).split('').reversed.join(),
          String.fromCharCodes(
            target.codeUnits.map((c) => ((c - 65 + shift + 1) % 26) + 65),
          ),
          String.fromCharCodes(
            target.codeUnits.map((c) => ((c - 65 - shift + 26) % 26) + 65),
          ),
          target,
        ],
        rng,
      ),
      correctAnswer: correct,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: 'Find the fixed letter-shift the code uses, then apply it.',
    );
  }

  static Puzzle _numberCode(int tier, int timeLimitSeconds, RngService rng) {
    final word = _words[rng.nextInt(0, _words.length - 1)];
    final codes = word.codeUnits.map((c) => c - 64).toList(); // A=1
    final correct = codes.join('-');
    final shuffled = List.of(codes);
    shuffleList(shuffled, rng);
    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.reasoningTest,
      type: PuzzleType.coding,
      questionText: 'Using A=1, B=2, C=3, ... Z=26, how is the word '
          '$word written in numbers?',
      options: buildMcOptionsFromCandidates(
        correct,
        [
          codes.reversed.join('-'),
          codes.map((c) => c + 1).join('-'),
          codes.map((c) => c - 1 < 1 ? c : c - 1).join('-'),
          shuffled.join('-'),
        ],
        rng,
      ),
      correctAnswer: correct,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      hint: 'A=1, B=2, C=3, ... each letter maps to its position in the alphabet.',
    );
  }
}
