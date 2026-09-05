import 'package:flutter_test/flutter_test.dart';
import 'package:math_blitz/services/family_tree.dart';
import 'package:math_blitz/services/family_tree_generator.dart';
import 'package:math_blitz/services/rng_service.dart';

// Checks the structural invariants a generated tree must always satisfy,
// regardless of tier or seed.
void _assertStructurallyValid(FamilyTree tree) {
  // Nobody has more than 2 parents.
  for (final entry in tree.parentsOf.entries) {
    expect(
      entry.value.length,
      lessThanOrEqualTo(2),
      reason: 'person ${entry.key} has more than 2 parents',
    );
  }

  // Every id referenced anywhere actually exists in `people`.
  final knownIds = tree.people.map((p) => p.id).toSet();
  for (final parentIds in tree.parentsOf.values) {
    for (final id in parentIds) {
      expect(knownIds.contains(id), isTrue, reason: 'unknown parent id $id');
    }
  }
  for (final childIds in tree.childrenOf.values) {
    for (final id in childIds) {
      expect(knownIds.contains(id), isTrue, reason: 'unknown child id $id');
    }
  }

  // Spouse links are always symmetric.
  for (final entry in tree.spouseOf.entries) {
    expect(
      tree.spouseOf[entry.value],
      equals(entry.key),
      reason: 'asymmetric spouse link ${entry.key} <-> ${entry.value}',
    );
  }

  // No duplicate names or ids within one tree.
  final names = tree.people.map((p) => p.name).toList();
  expect(names.toSet().length, equals(names.length),
      reason: 'duplicate name found in generated tree');
  final ids = tree.people.map((p) => p.id).toList();
  expect(ids.toSet().length, equals(ids.length),
      reason: 'duplicate id found in generated tree');
}

void main() {
  group('structural validity across tiers', () {
    for (final tier in [1, 2, 3, 4]) {
      test('tier $tier generates 50 structurally valid trees', () {
        for (var i = 0; i < 50; i++) {
          final tree = FamilyTreeGenerator.generate(
            tier: tier,
            rng: RngService.free(),
          );
          expect(tree.people, isNotEmpty);
          _assertStructurallyValid(tree);
        }
      });
    }
  });

  group('determinism', () {
    test('the same seeded RngService produces an identical tree twice', () {
      final treeA = FamilyTreeGenerator.generate(
        tier: 3,
        rng: RngService.seeded('family-tree-seed'),
      );
      final treeB = FamilyTreeGenerator.generate(
        tier: 3,
        rng: RngService.seeded('family-tree-seed'),
      );
      expect(
        treeA.people.map((p) => p.id).toList(),
        equals(treeB.people.map((p) => p.id).toList()),
      );
      expect(
        treeA.people.map((p) => p.name).toList(),
        equals(treeB.people.map((p) => p.name).toList()),
      );
      expect(
        treeA.people.map((p) => p.sex).toList(),
        equals(treeB.people.map((p) => p.sex).toList()),
      );
      expect(treeA.parentsOf, equals(treeB.parentsOf));
      expect(treeA.childrenOf, equals(treeB.childrenOf));
      expect(treeA.spouseOf, equals(treeB.spouseOf));
    });

    test('different seeds produce different trees', () {
      final treeA = FamilyTreeGenerator.generate(
        tier: 3,
        rng: RngService.seeded('seed-one'),
      );
      final treeB = FamilyTreeGenerator.generate(
        tier: 3,
        rng: RngService.seeded('seed-two'),
      );
      expect(
        treeA.people.map((p) => p.name).toList(),
        isNot(equals(treeB.people.map((p) => p.name).toList())),
      );
    });
  });

  group('tree size grows with tier', () {
    test('tier 4 trees have more people on average than tier 1 trees', () {
      var totalTier1 = 0;
      var totalTier4 = 0;
      const samples = 30;
      for (var i = 0; i < samples; i++) {
        totalTier1 += FamilyTreeGenerator.generate(
          tier: 1,
          rng: RngService.free(),
        ).people.length;
        totalTier4 += FamilyTreeGenerator.generate(
          tier: 4,
          rng: RngService.free(),
        ).people.length;
      }
      expect(totalTier4 / samples, greaterThan(totalTier1 / samples));
    });
  });

  group('root couple', () {
    test(
        'the tree always starts with one married root couple with no '
        'recorded parents', () {
      final tree = FamilyTreeGenerator.generate(
        tier: 1,
        rng: RngService.seeded('root-check'),
      );
      final rootMale = tree.people[0];
      final rootFemale = tree.people[1];
      expect(tree.parentsOf.containsKey(rootMale.id), isFalse);
      expect(tree.parentsOf.containsKey(rootFemale.id), isFalse);
      expect(tree.spouseOf[rootMale.id], equals(rootFemale.id));
      expect(tree.spouseOf[rootFemale.id], equals(rootMale.id));
      expect(rootMale.sex, equals(Sex.male));
      expect(rootFemale.sex, equals(Sex.female));
    });
  });
}
