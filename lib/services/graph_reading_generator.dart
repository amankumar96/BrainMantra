import '../models/diagram_data.dart';
import '../models/puzzle.dart';
import 'difficulty_curve.dart';
import 'rng_service.dart';
import 'rng_utils.dart';

const List<String> _allCategoryLabels = ['A', 'B', 'C', 'D', 'E'];

/// Builds a bar-graph reading question — random distinct values per
/// category, then either "which category is highest/second-highest?"
/// (answer: a category label) or "what's the difference between two
/// categories?" (answer: a number) — both derived straight from the
/// generated `values`, never asked about separately from what's rendered.
/// No hint at any tier: reading a graph isn't formula-driven, so a
/// theorem-name nudge wouldn't help.
abstract final class GraphReadingGenerator {
  static Puzzle generate({required int tier, required RngService rng}) {
    final params = DifficultyCurve.paramsForTier(tier);
    final categoryCount = _categoryCountForTier(tier);
    final categories = _allCategoryLabels.take(categoryCount).toList();

    // Distinct values only — a tie for "highest" would make the question
    // ambiguous.
    final valueSet = <int>{};
    while (valueSet.length < categoryCount) {
      valueSet.add(rng.nextInt(10, 100));
    }
    final values = valueSet.toList();
    shuffleList(values, rng);

    final diagramData = DiagramData(
      kind: DiagramKind.barGraph,
      categories: categories,
      values: values,
    );

    return rng.nextBool()
        ? _rankingQuestion(tier, params.timeLimitSeconds, categories, values,
            diagramData, rng)
        : _differenceQuestion(tier, params.timeLimitSeconds, categories,
            values, diagramData, rng);
  }

  static Puzzle _rankingQuestion(
    int tier,
    int timeLimitSeconds,
    List<String> categories,
    List<int> values,
    DiagramData diagramData,
    RngService rng,
  ) {
    final rankedIndices = List.generate(values.length, (i) => i)
      ..sort((a, b) => values[b].compareTo(values[a]));
    final askSecond = rng.nextBool();
    final targetIndex = rankedIndices[askSecond ? 1 : 0];
    final correctAnswer = categories[targetIndex];

    final options = List<String>.from(categories);
    shuffleList(options, rng);

    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.graphReading,
      questionText:
          'Which category has the ${askSecond ? 'second-highest' : 'highest'} '
          'value?',
      options: options,
      correctAnswer: correctAnswer,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      diagramData: diagramData,
    );
  }

  static Puzzle _differenceQuestion(
    int tier,
    int timeLimitSeconds,
    List<String> categories,
    List<int> values,
    DiagramData diagramData,
    RngService rng,
  ) {
    final i = rng.nextInt(0, categories.length - 1);
    int j;
    do {
      j = rng.nextInt(0, categories.length - 1);
    } while (j == i);
    final correctAnswer = (values[i] - values[j]).abs();

    return Puzzle(
      id: deterministicId(rng),
      category: PuzzleCategory.mathTest,
      type: PuzzleType.graphReading,
      questionText: 'What is the difference between category ${categories[i]} '
          'and category ${categories[j]}?',
      options: buildNumericMcOptions(correctAnswer, rng, spread: 15),
      correctAnswer: correctAnswer,
      difficultyTier: tier,
      timeLimitSeconds: timeLimitSeconds,
      diagramData: diagramData,
    );
  }

  /// TUNABLE — initial defaults: fewer bars (simpler to scan) at low
  /// tiers, up to 5 at high tiers.
  static int _categoryCountForTier(int tier) => switch (tier) {
        1 => 3,
        2 => 4,
        _ => 5,
      };
}
