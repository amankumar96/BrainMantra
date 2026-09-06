import 'package:flutter_test/flutter_test.dart';
import 'package:math_blitz/controllers/game_controller.dart';
import 'package:math_blitz/models/puzzle.dart';
import 'package:math_blitz/models/test_session.dart';
import 'package:math_blitz/services/rng_service.dart';

void main() {
  group('answering', () {
    test('a correct submission awards +4 marks and records outcome.correct',
        () {
      final controller = GameController(
        totalQuestions: 3,
        isDailyChallenge: false,
        rng: RngService.seeded('test-seed-1'),
      );
      final correctAnswer =
          controller.currentPuzzle!.correctAnswer.toString();

      controller.selectOption(correctAnswer);
      expect(controller.hasSelection, isTrue);

      controller.submitSelected();

      expect(controller.totalMarks, equals(4));
      expect(controller.lastOutcome, equals(AnswerOutcome.correct));
      expect(controller.isSubmitted, isTrue);
    });

    test('a wrong submission awards -2 marks and records outcome.wrong', () {
      final controller = GameController(
        totalQuestions: 3,
        isDailyChallenge: false,
        rng: RngService.seeded('test-seed-2'),
      );
      final puzzle = controller.currentPuzzle!;
      final wrongOption = puzzle.options
          .firstWhere((o) => o != puzzle.correctAnswer.toString());

      controller.selectOption(wrongOption);
      controller.submitSelected();

      expect(controller.totalMarks, equals(-2));
      expect(controller.lastOutcome, equals(AnswerOutcome.wrong));
    });

    test('skipDueToTimeout awards 0 marks and records outcome.skipped', () {
      final controller = GameController(
        totalQuestions: 3,
        isDailyChallenge: false,
        rng: RngService.seeded('test-seed-3'),
      );

      controller.skipDueToTimeout();

      expect(controller.totalMarks, equals(0));
      expect(controller.lastOutcome, equals(AnswerOutcome.skipped));
      expect(controller.hasSelection, isFalse);
    });

    test('submitSelected does nothing without a prior selection', () {
      final controller = GameController(
        totalQuestions: 3,
        isDailyChallenge: false,
        rng: RngService.seeded('test-seed-4'),
      );

      controller.submitSelected();

      expect(controller.isSubmitted, isFalse);
      expect(controller.lastOutcome, isNull);
    });

    test(
        'a correct answer to a trueFalse question still scores +4 '
        'despite the True/False vs true/false case mismatch between the '
        'displayed option and bool.toString()', () {
      // Regression test: PuzzleType.trueFalse's options are "True"/
      // "False" (capitalized for display) but correctAnswer.toString()
      // on a bool yields lowercase "true"/"false" — a case-sensitive
      // compare in submitSelected() would silently mark every true/false
      // question wrong. Search seeds for a trueFalse puzzle to exercise
      // this specific path end-to-end.
      GameController? controller;
      for (var seed = 0; seed < 200; seed++) {
        final candidate = GameController(
          totalQuestions: 1,
          isDailyChallenge: false,
          rng: RngService.seeded('truefalse-search-$seed'),
        );
        if (candidate.currentPuzzle!.type == PuzzleType.trueFalse) {
          controller = candidate;
          break;
        }
      }
      expect(controller, isNotNull,
          reason: 'no trueFalse puzzle found in 200 seeds - unexpected');

      final puzzle = controller!.currentPuzzle!;
      final correctLabel = puzzle.options.firstWhere(
        (o) => o.toLowerCase() == puzzle.correctAnswer.toString(),
      );

      controller.selectOption(correctLabel);
      controller.submitSelected();

      expect(controller.totalMarks, equals(4));
      expect(controller.lastOutcome, equals(AnswerOutcome.correct));
    });

    test('a second select/submit is ignored once an answer is locked in',
        () {
      final controller = GameController(
        totalQuestions: 3,
        isDailyChallenge: false,
        rng: RngService.seeded('test-seed-5'),
      );
      final correctAnswer =
          controller.currentPuzzle!.correctAnswer.toString();
      controller.selectOption(correctAnswer);
      controller.submitSelected();
      expect(controller.totalMarks, equals(4));

      // Trying to select/submit again before advancing must not
      // double-score the same question.
      controller.selectOption('something else');
      controller.submitSelected();
      expect(controller.totalMarks, equals(4));
    });
  });

  group('progressing through a test', () {
    test('advances the question number and loads a new puzzle after '
        'feedback completes', () {
      final controller = GameController(
        totalQuestions: 3,
        isDailyChallenge: false,
        rng: RngService.seeded('test-seed-6'),
      );
      expect(controller.questionNumber, equals(1));

      controller.skipDueToTimeout();
      controller.onFeedbackAnimationComplete();

      expect(controller.questionNumber, equals(2));
      expect(controller.isSubmitted, isFalse);
      expect(controller.hasSelection, isFalse);
      expect(controller.currentPuzzle, isNotNull);
    });

    test('isTestComplete only becomes true after totalQuestions are '
        'answered', () {
      final controller = GameController(
        totalQuestions: 3,
        isDailyChallenge: false,
        rng: RngService.seeded('test-seed-7'),
      );

      for (var i = 0; i < 3; i++) {
        expect(controller.isTestComplete, isFalse);
        controller.skipDueToTimeout();
        controller.onFeedbackAnimationComplete();
      }

      expect(controller.isTestComplete, isTrue);
    });

    test('finalTestSession is null until complete, then well-formed', () {
      final controller = GameController(
        totalQuestions: 2,
        isDailyChallenge: false,
        rng: RngService.seeded('test-seed-8'),
      );
      expect(controller.finalTestSession, isNull);

      final firstCorrect =
          controller.currentPuzzle!.correctAnswer.toString();
      controller.selectOption(firstCorrect);
      controller.submitSelected();
      controller.onFeedbackAnimationComplete();

      expect(controller.finalTestSession, isNull); // still 1 of 2 done

      controller.skipDueToTimeout();
      controller.onFeedbackAnimationComplete();

      final session = controller.finalTestSession;
      expect(session, isNotNull);
      expect(
        session!.outcomes,
        equals([AnswerOutcome.correct, AnswerOutcome.skipped]),
      );
      expect(session.marksAwarded, equals([4, 0]));
      expect(session.totalMarks, equals(4));
      expect(session.session.puzzlesAnswered, hasLength(2));
      expect(session.session.score, equals(4));
      expect(session.session.isDailyChallenge, isFalse);
      expect(session.session.seedUsed, isNull);
    });
  });

  group('determinism', () {
    test('two controllers sharing a seed stay in lockstep when answered '
        'identically', () {
      final a = GameController(
        totalQuestions: 3,
        isDailyChallenge: false,
        rng: RngService.seeded('daily-fairness'),
      );
      final b = GameController(
        totalQuestions: 3,
        isDailyChallenge: false,
        rng: RngService.seeded('daily-fairness'),
      );

      expect(a.currentPuzzle, equals(b.currentPuzzle));

      for (var i = 0; i < 3; i++) {
        final answer = a.currentPuzzle!.correctAnswer.toString();
        a.selectOption(answer);
        a.submitSelected();
        b.selectOption(answer);
        b.submitSelected();
        expect(a.totalMarks, equals(b.totalMarks));

        a.onFeedbackAnimationComplete();
        b.onFeedbackAnimationComplete();
        if (!a.isTestComplete) {
          expect(a.currentPuzzle, equals(b.currentPuzzle));
        }
      }

      expect(a.finalTestSession, equals(b.finalTestSession));
    });

    test('a Daily Challenge instance self-seeds without throwing when no '
        'rng is passed explicitly', () {
      // Cross-run daily-seed fairness itself is exercised above via an
      // explicit shared seed (the part that actually matters); this just
      // confirms the isDailyChallenge auto-seeding path works at all.
      final controller = GameController(totalQuestions: 1, isDailyChallenge: true);
      expect(controller.currentPuzzle, isNotNull);
    });
  });

  group('question type selection', () {
    test('draws from more than one puzzle type over many questions', () {
      final controller = GameController(
        totalQuestions: 40,
        isDailyChallenge: false,
        rng: RngService.seeded('type-variety'),
      );
      final seenTypes = <String>{};
      for (var i = 0; i < 40; i++) {
        seenTypes.add(controller.currentPuzzle!.type.name);
        controller.skipDueToTimeout();
        controller.onFeedbackAnimationComplete();
      }
      expect(seenTypes.length, greaterThan(1));
    });
  });
}
