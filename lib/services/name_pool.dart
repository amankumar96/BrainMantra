import 'rng_service.dart';
import 'rng_utils.dart';

/// Shared first-name pools used by every generator that needs random
/// human names in a question — family tree, seating arrangement, ranking,
/// and ratio's money-sharing sub-type. One shared, large pool (rather than
/// each generator keeping its own small list) is what keeps names from
/// visibly repeating across questions; a generator drawing only 2-8 names
/// per question from ~78 total makes repeats statistically rare.
abstract final class NamePool {
  // Sized generously against the largest tree family_tree_generator.dart
  // ever builds (tier 4 tops out around 20-30 people), so name collisions
  // within one tree stay rare even before that generator's own retry/
  // numbered-fallback logic kicks in.
  static const List<String> male = [
    'Aarav', 'Vihaan', 'Arjun', 'Reyansh', 'Krishna', 'Ishaan', 'Rohan',
    'Aditya', 'Kabir', 'Vivaan', 'Ayaan', 'Dhruv', 'Karan', 'Rahul', 'Sameer',
    'Nikhil', 'Amit', 'Raj', 'Vikram', 'Suresh', 'Mohan', 'Ravi', 'Anil',
    'Sanjay', 'Deepak', 'Ajay', 'Vijay', 'Manoj', 'Rakesh', 'Ashok', 'Gopal',
    'Harish', 'Naveen', 'Prakash', 'Ramesh', 'Sunil', 'Tarun', 'Uday',
    'Varun', 'Yash',
  ];

  static const List<String> female = [
    'Aanya', 'Diya', 'Isha', 'Kavya', 'Meera', 'Nisha', 'Pooja', 'Riya',
    'Sana', 'Tara', 'Uma', 'Vidya', 'Anita', 'Kavita', 'Sita', 'Priya',
    'Neha', 'Divya', 'Geeta', 'Radha', 'Lata', 'Maya', 'Nita', 'Pallavi',
    'Renu', 'Shanti', 'Usha', 'Veena', 'Anjali', 'Bhavna', 'Chitra', 'Deepa',
    'Esha', 'Falguni', 'Gauri', 'Hema', 'Indira', 'Jaya', 'Komal', 'Leela',
  ];

  /// Every name, male and female combined — for generators that don't
  /// track/care about sex (seating arrangement, ranking, ratio).
  static final List<String> all = [...male, ...female];

  /// Picks [count] distinct names at random from [all], already shuffled
  /// — the single call a generator needs for "give me N different random
  /// names for this question." A fresh shuffle every call (not a cached
  /// shared list) is what actually fixes the "always the same names"
  /// bug: the old `_namePool.take(count)` pattern always took the same
  /// fixed prefix of a small list, only shuffling *order*, never *which*
  /// names were chosen.
  static List<String> pickDistinct(int count, RngService rng) {
    final pool = List.of(all);
    shuffleList(pool, rng);
    return pool.take(count).toList();
  }
}
