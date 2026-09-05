import 'package:flutter_test/flutter_test.dart';
import 'package:math_blitz/services/family_tree.dart';
import 'package:math_blitz/services/relationship_resolver.dart';

// A small, fixed family tree built by hand (not via the generator) so
// every relationship shape can be checked against a known-correct answer:
//
//        ravi === sita
//         /          \
//     mohan===anita  suresh===kavita
//      /   \            \
//  arjun  priya         neha
//
// (=== marks a marriage; outsiders anita/kavita have no recorded parents)
// vikram is a totally unconnected stranger, for the "no relation" case.
FamilyTree _buildTree() {
  const people = [
    Person(id: 'ravi', name: 'Ravi', sex: Sex.male),
    Person(id: 'sita', name: 'Sita', sex: Sex.female),
    Person(id: 'mohan', name: 'Mohan', sex: Sex.male),
    Person(id: 'anita', name: 'Anita', sex: Sex.female),
    Person(id: 'suresh', name: 'Suresh', sex: Sex.male),
    Person(id: 'kavita', name: 'Kavita', sex: Sex.female),
    Person(id: 'arjun', name: 'Arjun', sex: Sex.male),
    Person(id: 'priya', name: 'Priya', sex: Sex.female),
    Person(id: 'neha', name: 'Neha', sex: Sex.female),
    Person(id: 'vikram', name: 'Vikram', sex: Sex.male),
  ];

  const childrenOf = {
    'ravi': ['mohan', 'suresh'],
    'sita': ['mohan', 'suresh'],
    'mohan': ['arjun', 'priya'],
    'anita': ['arjun', 'priya'],
    'suresh': ['neha'],
    'kavita': ['neha'],
  };

  const parentsOf = {
    'mohan': ['ravi', 'sita'],
    'suresh': ['ravi', 'sita'],
    'arjun': ['mohan', 'anita'],
    'priya': ['mohan', 'anita'],
    'neha': ['suresh', 'kavita'],
  };

  const spouseOf = {
    'ravi': 'sita',
    'sita': 'ravi',
    'mohan': 'anita',
    'anita': 'mohan',
    'suresh': 'kavita',
    'kavita': 'suresh',
  };

  return const FamilyTree(
    people: people,
    childrenOf: childrenOf,
    parentsOf: parentsOf,
    spouseOf: spouseOf,
  );
}

void main() {
  final tree = _buildTree();

  group('resolve — direct relations (shape (0,1)/(1,0))', () {
    test('mohan is arjun\'s father', () {
      expect(
        RelationshipResolver.resolve(tree, fromId: 'mohan', toId: 'arjun'),
        equals('father'),
      );
    });

    test('anita is priya\'s mother', () {
      expect(
        RelationshipResolver.resolve(tree, fromId: 'anita', toId: 'priya'),
        equals('mother'),
      );
    });

    test('arjun is mohan\'s son', () {
      expect(
        RelationshipResolver.resolve(tree, fromId: 'arjun', toId: 'mohan'),
        equals('son'),
      );
    });
  });

  group('resolve — grandparents (shape (0,2)/(2,0))', () {
    test('ravi is arjun\'s grandfather', () {
      expect(
        RelationshipResolver.resolve(tree, fromId: 'ravi', toId: 'arjun'),
        equals('grandfather'),
      );
    });

    test('arjun is ravi\'s grandson', () {
      expect(
        RelationshipResolver.resolve(tree, fromId: 'arjun', toId: 'ravi'),
        equals('grandson'),
      );
    });
  });

  group('resolve — siblings (shape (1,1))', () {
    test('mohan is suresh\'s brother', () {
      expect(
        RelationshipResolver.resolve(tree, fromId: 'mohan', toId: 'suresh'),
        equals('brother'),
      );
    });

    test('arjun is priya\'s brother', () {
      expect(
        RelationshipResolver.resolve(tree, fromId: 'arjun', toId: 'priya'),
        equals('brother'),
      );
    });
  });

  group('resolve — uncle/aunt/nephew/niece (shape (1,2)/(2,1))', () {
    test('mohan is neha\'s uncle', () {
      expect(
        RelationshipResolver.resolve(tree, fromId: 'mohan', toId: 'neha'),
        equals('uncle'),
      );
    });

    test('neha is mohan\'s niece', () {
      expect(
        RelationshipResolver.resolve(tree, fromId: 'neha', toId: 'mohan'),
        equals('niece'),
      );
    });
  });

  group('resolve — cousins (shape (2,2), capped precision)', () {
    test('arjun is neha\'s cousin', () {
      expect(
        RelationshipResolver.resolve(tree, fromId: 'arjun', toId: 'neha'),
        equals('cousin'),
      );
    });

    test('cousin term is gender-neutral', () {
      expect(
        RelationshipResolver.resolve(tree, fromId: 'neha', toId: 'arjun'),
        equals('cousin'),
      );
    });
  });

  group('resolve — spouse', () {
    test('ravi is sita\'s husband', () {
      expect(
        RelationshipResolver.resolve(tree, fromId: 'ravi', toId: 'sita'),
        equals('husband'),
      );
    });

    test('sita is ravi\'s wife', () {
      expect(
        RelationshipResolver.resolve(tree, fromId: 'sita', toId: 'ravi'),
        equals('wife'),
      );
    });
  });

  group('resolve — in-law composition', () {
    test(
        'anita is ravi\'s daughter-in-law '
        '(case A: spouse\'s blood relation, re-gendered)', () {
      expect(
        RelationshipResolver.resolve(tree, fromId: 'anita', toId: 'ravi'),
        equals('daughter-in-law'),
      );
    });

    test(
        'anita is suresh\'s sister-in-law '
        '(case A: spouse\'s sibling, re-gendered)', () {
      expect(
        RelationshipResolver.resolve(tree, fromId: 'anita', toId: 'suresh'),
        equals('sister-in-law'),
      );
    });

    test(
        'mohan is kavita\'s brother-in-law '
        '(case B: own blood relation to the spouse, already gendered)', () {
      expect(
        RelationshipResolver.resolve(tree, fromId: 'mohan', toId: 'kavita'),
        equals('brother-in-law'),
      );
    });
  });

  group('resolve — errors', () {
    test('resolving a person against themselves throws ArgumentError', () {
      expect(
        () => RelationshipResolver.resolve(tree, fromId: 'arjun', toId: 'arjun'),
        throwsArgumentError,
      );
    });

    test('an unconnected stranger throws NoRelationFoundException', () {
      expect(
        () => RelationshipResolver.resolve(tree, fromId: 'arjun', toId: 'vikram'),
        throwsA(isA<NoRelationFoundException>()),
      );
    });

    test('aunt/uncle-by-marriage is outside the in-law vocabulary and '
        'throws NoRelationFoundException', () {
      // arjun has no spouse, and his blood relation to kavita's spouse
      // (suresh) is "nephew" — not a category this resolver composes
      // with "-in-law" (see _inLawCategory), so this is expected to fail
      // rather than silently guess a term.
      expect(
        () => RelationshipResolver.resolve(tree, fromId: 'arjun', toId: 'kavita'),
        throwsA(isA<NoRelationFoundException>()),
      );
    });
  });

  group('narrate', () {
    test('direct relation is a single sentence', () {
      expect(
        RelationshipResolver.narrate(tree, fromId: 'mohan', toId: 'arjun'),
        equals(["Mohan is Arjun's father."]),
      );
    });

    test('grandparent relation narrates as two chained sentences', () {
      expect(
        RelationshipResolver.narrate(tree, fromId: 'ravi', toId: 'arjun'),
        equals(["Ravi is Mohan's father.", "Mohan is Arjun's father."]),
      );
    });

    test('cousin relation narrates the full four-person chain', () {
      // arjun -> mohan -> ravi (shared ancestor) -> suresh -> neha:
      // narration walks from fromId out to the ancestor, then down to
      // toId, one direct parent/child sentence per hop.
      final sentences =
          RelationshipResolver.narrate(tree, fromId: 'arjun', toId: 'neha');
      expect(sentences, hasLength(4));
      expect(sentences[0], equals("Mohan is Arjun's father."));
      expect(sentences[1], equals("Ravi is Mohan's father."));
      expect(sentences[2], equals("Ravi is Suresh's father."));
      expect(sentences[3], equals("Suresh is Neha's father."));
    });

    test('spouse relation is a single sentence naming the marriage', () {
      expect(
        RelationshipResolver.narrate(tree, fromId: 'ravi', toId: 'sita'),
        equals(["Ravi is Sita's husband."]),
      );
    });

    test('in-law relation narrates the marriage plus the blood path', () {
      final sentences =
          RelationshipResolver.narrate(tree, fromId: 'anita', toId: 'ravi');
      expect(sentences.first, equals("Anita is Mohan's wife."));
      expect(sentences.last, equals("Ravi is Mohan's father."));
    });
  });
}
