import 'package:flutter/foundation.dart';

import 'game_session.dart';

/// What happened on one question: answered correctly, answered wrong, or
/// timed out unanswered. [GameSession.correctness] (a plain `List<bool>`)
/// can't represent "skipped" as distinct from "wrong" — both would show
/// as `false`, which would wrongly imply a skipped question cost marks.
enum AnswerOutcome { correct, wrong, skipped }

/// Wraps a [GameSession] with the extra per-question detail the marks-
/// based scoring system (+4 / -2 / 0) needs, **without** changing
/// `GameSession`'s own already-tested shape — this is purely additive,
/// the same pattern `Puzzle.category` used to add reasoning questions
/// without breaking the original math-only model.
class TestSession {
  final GameSession session;

  /// Parallel to `session.puzzlesAnswered`.
  final List<AnswerOutcome> outcomes;

  /// Parallel to [outcomes]: +4 for correct, -2 for wrong, 0 for skipped.
  final List<int> marksAwarded;

  TestSession({
    required this.session,
    required this.outcomes,
    required this.marksAwarded,
  })  : assert(
          outcomes.length == marksAwarded.length,
          'outcomes and marksAwarded must be parallel arrays',
        ),
        assert(
          outcomes.length == session.puzzlesAnswered.length,
          'outcomes must be parallel to session.puzzlesAnswered',
        );

  int get totalMarks => marksAwarded.fold(0, (sum, marks) => sum + marks);

  Map<String, dynamic> toJson() => {
        'session': session.toJson(),
        'outcomes': outcomes.map((o) => o.name).toList(),
        'marksAwarded': marksAwarded,
      };

  factory TestSession.fromJson(Map<String, dynamic> json) {
    return TestSession(
      session: GameSession.fromJson(json['session'] as Map<String, dynamic>),
      outcomes: (json['outcomes'] as List)
          .map((name) => AnswerOutcome.values.byName(name as String))
          .toList(),
      marksAwarded: List<int>.from(json['marksAwarded'] as List),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TestSession &&
        other.session == session &&
        listEquals(other.outcomes, outcomes) &&
        listEquals(other.marksAwarded, marksAwarded);
  }

  @override
  int get hashCode => Object.hash(
        session,
        Object.hashAll(outcomes),
        Object.hashAll(marksAwarded),
      );

  @override
  String toString() =>
      'TestSession(session: $session, outcomes: $outcomes, '
      'marksAwarded: $marksAwarded, totalMarks: $totalMarks)';
}
