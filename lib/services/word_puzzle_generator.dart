import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

/// Puzzles Based on Words (Phase 12, reasoning topic 7): the classic
/// "odd one out" among words — three from one category, one from
/// another. A curated category bank keeps every answer unambiguous
/// (never an accidental cross-category overlap).
abstract final class WordPuzzleGenerator {
  static const _categories = {
    'fruits': ['Apple', 'Mango', 'Banana', 'Grape', 'Orange'],
    'animals': ['Dog', 'Cat', 'Lion', 'Tiger', 'Elephant'],
    'colors': ['Red', 'Blue', 'Green', 'Yellow', 'Purple'],
    'vegetables': ['Carrot', 'Potato', 'Onion', 'Spinach', 'Cabbage'],
    'countries': ['India', 'Japan', 'France', 'Brazil', 'Egypt'],
    'instruments': ['Guitar', 'Piano', 'Violin', 'Drum', 'Flute'],
  };

  static Puzzle generate({required int tier, required RngService rng}) {
    final params = DifficultyCurve.paramsForTier(tier);
    final categoryNames = _categories.keys.toList();
    final mainIndex = rng.nextInt(0, categoryNames.length - 1);
    var oddIndex = rng.nextInt(0, categoryNames.length - 1);
    while (oddIndex == mainIndex) {
      oddIndex = rng.nextInt(0, categoryNames.length - 1);
    }
    final mainWords = List.of(_categories[categoryNames[mainIndex]]!);
    shuffleList(mainWords, rng);
    final oddWords = _categories[categoryNames[oddIndex]]!;
    final oddWord = oddWords[rng.nextInt(0, oddWords.length - 1)];

    final options = [...mainWords.take(3), oddWord];
    shuffleList(options, rng);

    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.reasoningTest,
      type: PuzzleType.wordPuzzle,
      questionText: 'Which word does NOT belong with the others?',
      options: options,
      correctAnswer: oddWord,
      difficultyTier: tier,
      timeLimitSeconds: params.timeLimitSeconds,
      hint: 'Three words share a category; one comes from somewhere else.',
    );
  }
}
