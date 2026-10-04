import 'package:flutter_test/flutter_test.dart';
import 'package:brain_mantra/models/app_language.dart';
import 'package:brain_mantra/models/puzzle.dart';
import 'package:brain_mantra/services/puzzle_generator.dart';
import 'package:brain_mantra/services/rng_service.dart';

/// Matches any Devanagari codepoint (U+0900–U+097F) — the script every
/// Hindi translation in this app uses, confirmed present rather than
/// just "not crashing."
final _devanagari = RegExp(r'[ऀ-ॿ]');

/// Every math-category `PuzzleType` whose `questionText` is pure
/// numeric/symbolic notation with zero English words to begin with, by
/// deliberate design — these are expected to look identical in both
/// languages (nothing to translate), so they're excluded from the
/// "Hindi must appear somewhere" assertion below. See each generator's
/// own doc comment for why (e.g. `puzzle_generator_basic_math.dart`).
const _symbolOnlyTypes = {
  PuzzleType.arithmetic,
  PuzzleType.trueFalse,
  PuzzleType.missingNumber,
  PuzzleType.sequence,
  PuzzleType.targetNumber,
};

void main() {
  group('Hindi actually appears for every translatable math type', () {
    // This is the exact entry point GameController uses
    // (`PuzzleGenerator.generate`), not individual generator classes
    // directly — so this test fails if the real app's wiring from
    // GameController -> PuzzleGenerator -> an individual generator ever
    // drops the `language` param anywhere along that chain.
    final mathTypesToCheck = PuzzleType.values.where(
      (t) =>
          !_symbolOnlyTypes.contains(t) &&
          _categoryOf(t) == PuzzleCategory.mathTest,
    );

    for (final type in mathTypesToCheck) {
      test('$type: at least one Devanagari draw over 40 attempts across '
          'tiers 1-4', () {
        final rng = RngService.free();
        var sawDevanagari = false;
        for (var i = 0; i < 40 && !sawDevanagari; i++) {
          final tier = (i % 4) + 1;
          final puzzle = PuzzleGenerator.generate(
            tier: tier,
            type: type,
            rng: rng,
            language: AppLanguage.hindi,
          );
          final combinedText = '${puzzle.questionText} ${puzzle.hint ?? ''}';
          if (_devanagari.hasMatch(combinedText)) sawDevanagari = true;
        }
        expect(
          sawDevanagari,
          isTrue,
          reason: '$type never produced any Devanagari text in '
              'questionText/hint across 40 draws with '
              'language: AppLanguage.hindi — the Hindi branch for this '
              'type may be missing or unreachable.',
        );
      });
    }
  });

  group('symbol-only types correctly have nothing to translate', () {
    // Sanity check the other direction: these should NEVER show
    // Devanagari, in either language, since their questionText is pure
    // numeric/symbolic notation by design (confirms the exclusion list
    // above is accurate, not just a convenient way to shrink the test).
    for (final type in _symbolOnlyTypes) {
      test('$type: never produces Devanagari text (nothing to '
          'translate, by design)', () {
        final rng = RngService.free();
        for (var i = 0; i < 20; i++) {
          final puzzle = PuzzleGenerator.generate(
            tier: (i % 4) + 1,
            type: type,
            rng: rng,
            language: AppLanguage.hindi,
          );
          expect(
            _devanagari.hasMatch(puzzle.questionText),
            isFalse,
            reason: '$type unexpectedly produced Devanagari questionText: '
                '"${puzzle.questionText}" — if this type now has '
                'translatable content, remove it from _symbolOnlyTypes '
                'above instead of leaving this test wrong.',
          );
        }
      });
    }
  });

  group('English stays English when language: AppLanguage.english', () {
    // Confirms the ternary's *other* branch — that passing english
    // explicitly never accidentally renders Hindi — for a handful of
    // representative sentence-based types across all 3 translation
    // batches done in this feature.
    const representativeTypes = [
      PuzzleType.ratio,
      PuzzleType.profitLoss,
      PuzzleType.speedDistance,
      PuzzleType.statistics,
      PuzzleType.trigRatio,
      PuzzleType.unitConversion,
    ];

    for (final type in representativeTypes) {
      test('$type: never produces Devanagari text when '
          'language: AppLanguage.english', () {
        final rng = RngService.free();
        for (var i = 0; i < 20; i++) {
          final puzzle = PuzzleGenerator.generate(
            tier: (i % 4) + 1,
            type: type,
            rng: rng,
            language: AppLanguage.english,
          );
          final combinedText = '${puzzle.questionText} ${puzzle.hint ?? ''}';
          expect(_devanagari.hasMatch(combinedText), isFalse);
        }
      });
    }
  });
}

/// Mirrors `GameController`'s own private `_categoryOf` — duplicated
/// here (rather than imported) since it's private to that file; this
/// local copy only needs to be right for the math/reasoning split, not
/// kept in perfect lockstep with every future PuzzleType addition.
PuzzleCategory _categoryOf(PuzzleType type) => switch (type) {
      PuzzleType.familyTree ||
      PuzzleType.shapeIdentification ||
      PuzzleType.mirrorImage ||
      PuzzleType.paperFolding ||
      PuzzleType.figureSeries ||
      PuzzleType.seatingArrangement ||
      PuzzleType.coding ||
      PuzzleType.directionSense ||
      PuzzleType.wordPuzzle ||
      PuzzleType.analogy ||
      PuzzleType.ranking ||
      PuzzleType.statementConclusion =>
        PuzzleCategory.reasoningTest,
      _ => PuzzleCategory.mathTest,
    };
