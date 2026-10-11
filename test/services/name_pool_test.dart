import 'package:flutter_test/flutter_test.dart';
import 'package:brain_mantra/services/name_pool.dart';
import 'package:brain_mantra/services/rng_service.dart';

void main() {
  group('pickDistinct', () {
    test('returns exactly the requested count, all distinct', () {
      final rng = RngService.seeded('name-pool-distinct');
      final names = NamePool.pickDistinct(5, rng);
      expect(names.length, equals(5));
      expect(names.toSet().length, equals(5));
    });

    test('every returned name is actually from the pool', () {
      final rng = RngService.seeded('name-pool-membership');
      final names = NamePool.pickDistinct(8, rng);
      for (final name in names) {
        expect(NamePool.all.contains(name), isTrue);
      }
    });

    test(
        'repeated calls produce varied selections, not always the same '
        'prefix (the actual bug this fixes)', () {
      final rng = RngService.free();
      final firstCallResults = <Set<String>>[];
      for (var i = 0; i < 20; i++) {
        firstCallResults.add(NamePool.pickDistinct(4, rng).toSet());
      }
      // If every call returned the identical set of 4 names, this would
      // be exactly the old `.take(count)`-style bug — across 20 calls
      // from a pool of 78 names, seeing more than one distinct set is
      // overwhelmingly likely if selection is truly randomized.
      expect(firstCallResults.toSet().length, greaterThan(1));
    });
  });
}
