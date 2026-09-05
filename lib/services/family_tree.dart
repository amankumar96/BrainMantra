/// A person's sex, used only to pick the correct English kinship term
/// (father vs. mother, uncle vs. aunt, etc.) when describing how two
/// people in a [FamilyTree] are related — see `relationship_resolver.dart`.
enum Sex { male, female }

/// One person in a family tree.
class Person {
  final String id;
  final String name;
  final Sex sex;

  const Person({required this.id, required this.name, required this.sex});
}

/// A family tree: who exists, who their parents/children are, and who
/// they're married to. Built either by hand (e.g. small fixed trees in
/// tests) or randomly by `FamilyTreeGenerator.generate`, and walked by
/// `RelationshipResolver` to compute how any two people in it are related.
class FamilyTree {
  final List<Person> people;

  /// parentId -> that parent's childIds.
  final Map<String, List<String>> childrenOf;

  /// childId -> that child's parentIds (0, 1, or 2 entries).
  final Map<String, List<String>> parentsOf;

  /// Symmetric: if `spouseOf[a] == b` then `spouseOf[b] == a`.
  final Map<String, String> spouseOf;

  const FamilyTree({
    required this.people,
    required this.childrenOf,
    required this.parentsOf,
    required this.spouseOf,
  });

  /// Looks up a person by id. Throws [ArgumentError] if [id] isn't in this
  /// tree — a bug in whatever built the tree, never a case to silently
  /// ignore.
  Person byId(String id) {
    for (final person in people) {
      if (person.id == id) return person;
    }
    throw ArgumentError('No person with id "$id" in this tree');
  }
}
