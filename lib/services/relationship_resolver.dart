import 'family_tree.dart';

/// Thrown when no relationship in this resolver's vocabulary connects two
/// people (e.g. they're too many generations apart, or simply unrelated).
/// The generator that calls [RelationshipResolver.resolve] catches this
/// and picks a different pair — it should never reach the player.
class NoRelationFoundException implements Exception {
  final String message;
  const NoRelationFoundException(this.message);

  @override
  String toString() => 'NoRelationFoundException: $message';
}

/// The reasoning-category counterpart to `expression_evaluator.dart` —
/// the single place that actually *computes* a family relationship, so a
/// family-tree puzzle's answer is never a hardcoded lookup. Both the
/// puzzle generator (to build the question) and the tests (to
/// independently double-check the generator's answer) call into this.
abstract final class RelationshipResolver {
  /// Returns how [fromId] is related to [toId], as an English term, in the
  /// sense "[fromId] is [toId]'s `<term>`". For example
  /// `resolve(tree, fromId: aliceId, toId: bobId) == 'mother'` means
  /// "Alice is Bob's mother."
  ///
  /// Throws [ArgumentError] if [fromId] and [toId] are the same person, or
  /// [NoRelationFoundException] if no relationship in this resolver's
  /// vocabulary connects them.
  static String resolve(
    FamilyTree tree, {
    required String fromId,
    required String toId,
  }) {
    if (fromId == toId) {
      throw ArgumentError('fromId and toId must refer to different people');
    }

    // 1. Are they married to each other? Checked first since marriage
    // isn't a blood relationship the ancestor-search below would find.
    if (tree.spouseOf[fromId] == toId) {
      return _spouseTerm(tree, fromId);
    }

    // 2. Blood relationship: find the lowest common ancestor and map its
    // "shape" (how many hops up from fromId, how many hops down to toId)
    // to an English term.
    final directShape = _lowestCommonAncestor(tree, fromId, toId);
    if (directShape != null) {
      final term = _termForShape(
        directShape.up,
        directShape.down,
        tree.byId(fromId).sex,
      );
      if (term != null) return term;
    }

    // 3. One in-law hop, tried both directions — e.g. "my spouse's
    // brother" (fromId's spouse is blood-related to toId) or "my
    // brother's spouse" (fromId is blood-related to toId's spouse).
    final viaFromSpouse = _resolveInLawViaFromSpouse(tree, fromId, toId);
    if (viaFromSpouse != null) return viaFromSpouse;
    final viaToSpouse = _resolveInLawViaToSpouse(tree, fromId, toId);
    if (viaToSpouse != null) return viaToSpouse;

    throw NoRelationFoundException(
      'No relation in vocabulary between $fromId and $toId',
    );
  }

  /// Reconstructs the same relationship [resolve] computes as a series of
  /// simple, direct sentences (e.g. "Ram is Shyam's father. Shyam is
  /// Geeta's brother.") — so the *player* can work out the answer from the
  /// puzzle's question text alone, not just verify it internally.
  static List<String> narrate(
    FamilyTree tree, {
    required String fromId,
    required String toId,
  }) {
    if (fromId == toId) {
      throw ArgumentError('fromId and toId must refer to different people');
    }

    if (tree.spouseOf[fromId] == toId) {
      final term = _spouseTerm(tree, fromId);
      return ['${_name(tree, fromId)} is ${_name(tree, toId)}\'s $term.'];
    }

    final directShape = _lowestCommonAncestor(tree, fromId, toId);
    if (directShape != null &&
        _termForShape(
              directShape.up,
              directShape.down,
              tree.byId(fromId).sex,
            ) !=
            null) {
      return _narrateBloodPath(tree, fromId, toId, directShape);
    }

    // In-law: narrate the blood path to/through the spouse, then add one
    // sentence for the marriage itself.
    final fromSpouseId = tree.spouseOf[fromId];
    if (fromSpouseId != null) {
      final shape = _lowestCommonAncestor(tree, fromSpouseId, toId);
      if (shape != null &&
          _inLawCategory(
                _termForShape(shape.up, shape.down, tree.byId(fromSpouseId).sex),
              ) !=
              null) {
        return [
          '${_name(tree, fromId)} is ${_name(tree, fromSpouseId)}\'s '
              '${_spouseTerm(tree, fromId)}.',
          ..._narrateBloodPath(tree, fromSpouseId, toId, shape),
        ];
      }
    }
    final toSpouseId = tree.spouseOf[toId];
    if (toSpouseId != null) {
      final shape = _lowestCommonAncestor(tree, fromId, toSpouseId);
      if (shape != null &&
          _inLawCategory(
                _termForShape(shape.up, shape.down, tree.byId(fromId).sex),
              ) !=
              null) {
        return [
          ..._narrateBloodPath(tree, fromId, toSpouseId, shape),
          '${_name(tree, toSpouseId)} is ${_name(tree, toId)}\'s '
              '${_spouseTerm(tree, toSpouseId)}.',
        ];
      }
    }

    throw NoRelationFoundException(
      'No relation in vocabulary between $fromId and $toId',
    );
  }

  static String _name(FamilyTree tree, String id) => tree.byId(id).name;

  static String _spouseTerm(FamilyTree tree, String personId) =>
      tree.byId(personId).sex == Sex.male ? 'husband' : 'wife';

  /// Case A of the in-law check: fromId's spouse's blood relation to toId,
  /// *re-gendered* for fromId's own sex. E.g. if fromId's husband Tom is
  /// toId's son (category "child"), then fromId is toId's daughter — i.e.
  /// "daughter-in-law".
  static String? _resolveInLawViaFromSpouse(
    FamilyTree tree,
    String fromId,
    String toId,
  ) {
    final fromSpouseId = tree.spouseOf[fromId];
    if (fromSpouseId == null) return null;
    final shape = _lowestCommonAncestor(tree, fromSpouseId, toId);
    if (shape == null) return null;
    final baseTerm =
        _termForShape(shape.up, shape.down, tree.byId(fromSpouseId).sex);
    if (baseTerm == null) return null;
    final category = _inLawCategory(baseTerm);
    if (category == null) return null;
    return '${_genderedCategoryTerm(category, tree.byId(fromId).sex)}-in-law';
  }

  /// Case B of the in-law check: fromId's own blood relation to toId's
  /// spouse. Already gendered correctly by fromId's own sex (since fromId
  /// is literally the "from" person in that sub-lookup), so no
  /// re-gendering step is needed — just append "-in-law" directly.
  static String? _resolveInLawViaToSpouse(
    FamilyTree tree,
    String fromId,
    String toId,
  ) {
    final toSpouseId = tree.spouseOf[toId];
    if (toSpouseId == null) return null;
    final shape = _lowestCommonAncestor(tree, fromId, toSpouseId);
    if (shape == null) return null;
    final baseTerm =
        _termForShape(shape.up, shape.down, tree.byId(fromId).sex);
    if (baseTerm == null || _inLawCategory(baseTerm) == null) return null;
    return '$baseTerm-in-law';
  }

  /// Maps a gendered blood term to the neutral "category" in-law
  /// composition is defined for. Only parent/child/sibling have common
  /// English in-law terms (father-in-law, son-in-law, sister-in-law); more
  /// distant relations (grandparent, uncle, cousin, ...) don't compose
  /// with "-in-law" in everyday English, so they return null here and the
  /// in-law lookup simply fails for those shapes.
  static String? _inLawCategory(String? term) {
    if (term == null) return null;
    switch (term) {
      case 'father':
      case 'mother':
        return 'parent';
      case 'son':
      case 'daughter':
        return 'child';
      case 'brother':
      case 'sister':
        return 'sibling';
      default:
        return null;
    }
  }

  static String _genderedCategoryTerm(String category, Sex sex) {
    switch (category) {
      case 'parent':
        return sex == Sex.male ? 'father' : 'mother';
      case 'child':
        return sex == Sex.male ? 'son' : 'daughter';
      case 'sibling':
        return sex == Sex.male ? 'brother' : 'sister';
      default:
        throw ArgumentError('Unknown in-law category "$category"');
    }
  }

  /// The fixed naming rule for a given ancestor "shape": [up] hops from
  /// fromId to the shared ancestor, [down] hops from that ancestor to
  /// toId. This is domain knowledge (a naming *rule*, like "a pentagon has
  /// 5 sides") applied fresh to a different pair of people every call —
  /// not a per-instance cached answer.
  ///
  /// Every term is gendered by [fromSex] (fromId's own sex), since the
  /// term always describes what fromId *is* to toId. Cousin terminology is
  /// deliberately capped at a plain "cousin" for any shape with both
  /// up>=2 and down>=2 (no "once removed" precision) — simpler and more
  /// game-appropriate than full genealogical accuracy.
  static String? _termForShape(int up, int down, Sex fromSex) {
    final isMale = fromSex == Sex.male;
    if (up == 0 && down == 1) return isMale ? 'father' : 'mother';
    if (up == 1 && down == 0) return isMale ? 'son' : 'daughter';
    if (up == 0 && down == 2) return isMale ? 'grandfather' : 'grandmother';
    if (up == 2 && down == 0) {
      return isMale ? 'grandson' : 'granddaughter';
    }
    if (up == 0 && down == 3) {
      return isMale ? 'great-grandfather' : 'great-grandmother';
    }
    if (up == 3 && down == 0) {
      return isMale ? 'great-grandson' : 'great-granddaughter';
    }
    if (up == 1 && down == 1) return isMale ? 'brother' : 'sister';
    if (up == 1 && down == 2) return isMale ? 'uncle' : 'aunt';
    if (up == 2 && down == 1) return isMale ? 'nephew' : 'niece';
    if (up == 1 && down == 3) return isMale ? 'grand-uncle' : 'grand-aunt';
    if (up == 3 && down == 1) {
      return isMale ? 'grand-nephew' : 'grand-niece';
    }
    if (up >= 2 && down >= 2) return 'cousin';
    return null; // shape outside this resolver's vocabulary
  }

  /// Finds the shared ancestor of [fromId] and [toId] that minimizes total
  /// hops, by walking upward through parents from both people at once
  /// (breadth-first, so the first shared id found is guaranteed nearest).
  static ({String ancestorId, int up, int down})? _lowestCommonAncestor(
    FamilyTree tree,
    String fromId,
    String toId,
  ) {
    final upDistances = _ancestorDistances(tree, fromId);
    final downDistances = _ancestorDistances(tree, toId);

    String? bestId;
    var bestUp = 0;
    var bestDown = 0;
    var bestTotal = 1 << 30;

    for (final entry in upDistances.entries) {
      final down = downDistances[entry.key];
      if (down == null) continue; // not a shared ancestor
      final up = entry.value;
      final total = up + down;
      // Prefer the smallest total hop count; break ties by smaller `up`,
      // then by id, purely for deterministic output (ties only arise when
      // a person has two parents both leading to a shared ancestor at the
      // same distance, in which case the resulting term is identical
      // either way — e.g. siblings via either shared parent).
      final isBetter = total < bestTotal ||
          (total == bestTotal && up < bestUp) ||
          (total == bestTotal &&
              up == bestUp &&
              bestId != null &&
              entry.key.compareTo(bestId) < 0);
      if (bestId == null || isBetter) {
        bestId = entry.key;
        bestUp = up;
        bestDown = down;
        bestTotal = total;
      }
    }

    if (bestId == null) return null;
    return (ancestorId: bestId, up: bestUp, down: bestDown);
  }

  /// Breadth-first walk upward from [personId] through parentsOf,
  /// recording how many hops it took to reach each ancestor (0 = the
  /// person themself). Bounded to a generous depth since real trees in
  /// this app never exceed a handful of generations.
  static Map<String, int> _ancestorDistances(FamilyTree tree, String personId) {
    final distances = <String, int>{personId: 0};
    var frontier = [personId];
    var hop = 0;
    while (frontier.isNotEmpty && hop < 8) {
      hop++;
      final next = <String>[];
      for (final id in frontier) {
        for (final parentId in tree.parentsOf[id] ?? const []) {
          if (!distances.containsKey(parentId)) {
            distances[parentId] = hop;
            next.add(parentId);
          }
        }
      }
      frontier = next;
    }
    return distances;
  }

  /// Reconstructs the exact chain of direct parent<->child sentences
  /// connecting fromId to toId through their shared ancestor, e.g. for
  /// "Ram (up 1) -> ancestor -> Geeta (down 1)" this emits one sentence
  /// per adjacent pair — always a plain parent/child fact, never
  /// requiring the reader to reason about the whole shape at once.
  static List<String> _narrateBloodPath(
    FamilyTree tree,
    String fromId,
    String toId,
    ({String ancestorId, int up, int down}) shape,
  ) {
    final upPath = _pathUpToAncestor(tree, fromId, shape.ancestorId);
    final downPathDescending = _pathUpToAncestor(tree, toId, shape.ancestorId);
    final downPath = downPathDescending.reversed.toList();
    // Full chain from fromId to toId, through the ancestor exactly once.
    final chain = [...upPath, ...downPath.skip(1)];

    final sentences = <String>[];
    for (var i = 0; i < chain.length - 1; i++) {
      final onUpSide = i < upPath.length - 1;
      // Every adjacent pair in the chain is a direct parent/child link;
      // state each one as "parent is child's father/mother" regardless of
      // which side of the ancestor it's on, since that's always true and
      // always simple enough for a player to chain together themselves.
      final parentId = onUpSide ? chain[i + 1] : chain[i];
      final childId = onUpSide ? chain[i] : chain[i + 1];
      final parentTerm = tree.byId(parentId).sex == Sex.male
          ? 'father'
          : 'mother';
      sentences.add(
        '${_name(tree, parentId)} is ${_name(tree, childId)}\'s $parentTerm.',
      );
    }
    return sentences;
  }

  /// Walks upward from [personId] to [ancestorId] and returns the exact
  /// path of ids, starting with [personId] and ending with [ancestorId].
  static List<String> _pathUpToAncestor(
    FamilyTree tree,
    String personId,
    String ancestorId,
  ) {
    if (personId == ancestorId) return [personId];
    final cameFrom = <String, String>{}; // parentId -> the child we came from
    final visited = {personId};
    var frontier = [personId];
    while (frontier.isNotEmpty && !visited.contains(ancestorId)) {
      final next = <String>[];
      for (final id in frontier) {
        for (final parentId in tree.parentsOf[id] ?? const []) {
          if (visited.add(parentId)) {
            cameFrom[parentId] = id;
            next.add(parentId);
          }
        }
      }
      frontier = next;
    }
    // Walk back down from ancestorId to personId using cameFrom, then
    // reverse so the result reads personId -> ... -> ancestorId.
    final descending = <String>[ancestorId];
    var current = ancestorId;
    while (current != personId) {
      current = cameFrom[current]!;
      descending.add(current);
    }
    return descending.reversed.toList();
  }
}
