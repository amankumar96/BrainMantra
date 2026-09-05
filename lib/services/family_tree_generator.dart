import 'difficulty_curve.dart';
import 'family_tree.dart';
import 'rng_service.dart';

/// Builds a random, structurally-valid [FamilyTree] for reasoning-category
/// puzzles to ask questions about. The tree's depth (how many generations
/// of descendants exist below the root couple) scales with the tier's
/// `familyTreeHopDepth` — more generations means more distant
/// relationships (aunts/uncles, cousins, in-laws) become possible simply
/// because there's more tree to draw them from.
abstract final class FamilyTreeGenerator {
  static FamilyTree generate({required int tier, required RngService rng}) {
    final hopDepth =
        DifficultyCurve.paramsForTier(tier).reasoning.familyTreeHopDepth;
    // +1 for the root couple's own generation: hopDepth 1 (tier 1) means
    // "root couple + one generation of children"; hopDepth 4 (tier 4)
    // means four generations of descendants below the root.
    final generationCount = hopDepth + 1;

    final people = <Person>[];
    final childrenOf = <String, List<String>>{};
    final parentsOf = <String, List<String>>{};
    final spouseOf = <String, String>{};
    final usedNames = <String>{};
    var nextId = 0;

    // Creates one new Person with a name not already used in this tree,
    // and registers them in `people`.
    Person addPerson(Sex sex) {
      final name = _pickUnusedName(sex, usedNames, rng);
      final person = Person(id: 'p${nextId++}', name: name, sex: sex);
      people.add(person);
      return person;
    }

    void marry(Person a, Person b) {
      spouseOf[a.id] = b.id;
      spouseOf[b.id] = a.id;
    }

    void recordParentage(Person parentA, Person parentB, Person child) {
      childrenOf.putIfAbsent(parentA.id, () => []).add(child.id);
      childrenOf.putIfAbsent(parentB.id, () => []).add(child.id);
      parentsOf[child.id] = [parentA.id, parentB.id];
    }

    // Generation 0: one root couple, already married to each other.
    final rootMale = addPerson(Sex.male);
    final rootFemale = addPerson(Sex.female);
    marry(rootMale, rootFemale);

    // The couples whose children are about to be generated this round.
    var currentCouples = [(rootMale, rootFemale)];

    for (var level = 1; level < generationCount; level++) {
      final childrenThisLevel = <Person>[];
      for (final (parentA, parentB) in currentCouples) {
        // Each couple has 1-3 children, each independently male or female.
        final childCount = rng.nextInt(1, 3);
        for (var i = 0; i < childCount; i++) {
          final child = addPerson(rng.nextBool() ? Sex.male : Sex.female);
          recordParentage(parentA, parentB, child);
          childrenThisLevel.add(child);
        }
      }

      final isLastLevel = level == generationCount - 1;
      if (isLastLevel) {
        // Leaf generation reached — nobody here needs a spouse, since no
        // further generation will be built from them.
        break;
      }

      // Every child at a non-leaf level marries a brand-new outsider (a
      // person with no recorded parents of their own) so they can have
      // children next level. This is exactly what makes in-law
      // relationships exist once the tree is deep enough (tier >= 2) —
      // simplification: every non-leaf child marries in, rather than only
      // some of them, so the tree reliably reaches the requested depth on
      // every generation instead of risking an early dead end.
      currentCouples = [];
      for (final child in childrenThisLevel) {
        final outsiderSex = child.sex == Sex.male ? Sex.female : Sex.male;
        final outsider = addPerson(outsiderSex);
        marry(child, outsider);
        currentCouples.add((child, outsider));
      }
    }

    return FamilyTree(
      people: people,
      childrenOf: childrenOf,
      parentsOf: parentsOf,
      spouseOf: spouseOf,
    );
  }
}

// Two fixed first-name pools, sized generously against the largest tree
// this generator ever builds (tier 4 tops out around 20-30 people), so
// name collisions within one tree are rare — and even if the pool were
// exhausted, _pickUnusedName below falls back to a numbered variant
// rather than looping forever.
const List<String> _malePool = [
  'Aarav', 'Vihaan', 'Arjun', 'Reyansh', 'Krishna', 'Ishaan', 'Rohan',
  'Aditya', 'Kabir', 'Vivaan', 'Ayaan', 'Dhruv', 'Karan', 'Rahul', 'Sameer',
  'Nikhil', 'Amit', 'Raj', 'Vikram', 'Suresh', 'Mohan', 'Ravi', 'Anil',
  'Sanjay', 'Deepak', 'Ajay', 'Vijay', 'Manoj', 'Rakesh', 'Ashok', 'Gopal',
  'Harish', 'Naveen', 'Prakash', 'Ramesh', 'Sunil', 'Tarun', 'Uday',
  'Varun', 'Yash',
];

const List<String> _femalePool = [
  'Aanya', 'Diya', 'Isha', 'Kavya', 'Meera', 'Nisha', 'Pooja', 'Riya',
  'Sana', 'Tara', 'Uma', 'Vidya', 'Anita', 'Kavita', 'Sita', 'Priya',
  'Neha', 'Divya', 'Geeta', 'Radha', 'Lata', 'Maya', 'Nita', 'Pallavi',
  'Renu', 'Shanti', 'Usha', 'Veena', 'Anjali', 'Bhavna', 'Chitra', 'Deepa',
  'Esha', 'Falguni', 'Gauri', 'Hema', 'Indira', 'Jaya', 'Komal', 'Leela',
];

/// Picks a first name not already used elsewhere in this tree.
String _pickUnusedName(Sex sex, Set<String> usedNames, RngService rng) {
  final pool = sex == Sex.male ? _malePool : _femalePool;
  for (var attempt = 0; attempt < 50; attempt++) {
    final candidate = pool[rng.nextInt(0, pool.length - 1)];
    if (usedNames.add(candidate)) return candidate;
  }
  // Pool exhausted (should never happen at these tree sizes) — append a
  // number rather than risk looping forever.
  var suffix = 2;
  while (true) {
    final candidate = '${pool[rng.nextInt(0, pool.length - 1)]} $suffix';
    if (usedNames.add(candidate)) return candidate;
    suffix++;
  }
}
