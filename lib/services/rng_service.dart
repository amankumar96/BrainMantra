import 'dart:convert' show utf8;
import 'dart:math';

/// A source of randomness every puzzle generator depends on.
///
/// Two flavors are available:
/// - [RngService.free] — genuinely unpredictable, for normal play.
/// - [RngService.seeded] — looks random but is 100% reproducible from a
///   text seed (e.g. a date string like "2026-09-05"), so a Daily
///   Challenge can hand every player the identical puzzle sequence.
abstract class RngService {
  /// Real randomness, sourced from the OS. Falls back to a weaker (but
  /// still unpredictable-in-practice) source if the platform doesn't
  /// support a cryptographic RNG.
  factory RngService.free() = _FreeRngService;

  /// Deterministic randomness derived entirely from [seed]. Calling this
  /// with the same seed string — today, tomorrow, on any device, on any
  /// platform (Android/iOS/web) — always produces the exact same sequence
  /// of [nextInt]/[nextBool] results.
  factory RngService.seeded(String seed) = _SeededRngService;

  /// A random integer in the *inclusive* range [min, max] (both ends can
  /// be produced). Deliberately inclusive on both ends — unlike
  /// dart:math's `Random.nextInt`, which is exclusive on the upper bound —
  /// because every caller in this codebase wants "pick a number from X to
  /// Y" to mean literally X through Y.
  int nextInt(int min, int max);

  /// A random true/false value, each with roughly 50% probability.
  bool nextBool();
}

/// [RngService.free] implementation: just forwards to dart:math's own RNG.
class _FreeRngService implements RngService {
  final Random _random;

  _FreeRngService() : _random = _createRandom();

  // Random.secure() throws UnsupportedError on platforms without a secure
  // entropy source available; fall back to the plain (still fine for a
  // game, just not cryptographic-grade) Random() in that case.
  static Random _createRandom() {
    try {
      return Random.secure();
    } on UnsupportedError {
      return Random();
    }
  }

  @override
  int nextInt(int min, int max) {
    assert(max >= min, 'nextInt: max ($max) must be >= min ($min)');
    return min + _random.nextInt(max - min + 1);
  }

  @override
  bool nextBool() => _random.nextBool();
}

/// [RngService.seeded] implementation: a small, fast, well-known PRNG
/// (Mulberry32) started from a hash of [seed]. Every method here is
/// written to behave identically on the Dart VM (Android/iOS, real 64-bit
/// ints) and on web (JS doubles, only exact up to 2^53) — see [_imul32].
class _SeededRngService implements RngService {
  /// Current 32-bit generator state, always kept in the range
  /// [0, 2^32) (i.e. treated as an unsigned 32-bit integer).
  int _state;

  _SeededRngService(String seed) : _state = _fnv1a32(seed);

  @override
  int nextInt(int min, int max) {
    assert(max >= min, 'nextInt: max ($max) must be >= min ($min)');
    final range = max - min + 1;
    // Small modulo bias exists here (not every output is exactly equally
    // likely when `range` doesn't evenly divide 2^32), which is completely
    // fine for a game — this is not cryptographic randomness.
    return min + (_next32() % range);
  }

  @override
  bool nextBool() => (_next32() & 1) == 0;

  /// One step of the Mulberry32 algorithm: advances [_state] and returns a
  /// fresh pseudo-random 32-bit unsigned integer. Every arithmetic op is
  /// explicitly masked to 32 bits (`& 0xFFFFFFFF`) or routed through
  /// [_imul32] so the exact same sequence comes out on native (VM ints)
  /// and web (JS doubles) — the algorithm reference is Tommy Ettinger's
  /// public-domain Mulberry32.
  int _next32() {
    _state = (_state + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _state;
    t = _imul32(t ^ (t >>> 15), t | 1) & 0xFFFFFFFF;
    t = (t ^ ((t + _imul32(t ^ (t >>> 7), t | 61)) & 0xFFFFFFFF)) &
        0xFFFFFFFF;
    return (t ^ (t >>> 14)) & 0xFFFFFFFF;
  }
}

/// Hashes [seed] into a 32-bit starting state using FNV-1a.
///
/// Deliberately *not* `seed.hashCode`: Dart does not guarantee
/// `Object.hashCode` stays the same across Dart SDK versions, isolates, or
/// compile targets (VM vs. JS vs. Wasm) — using it here would risk a
/// future SDK upgrade silently changing every Daily Challenge's puzzle
/// sequence. FNV-1a is a fixed, simple algorithm with no such risk.
int _fnv1a32(String seed) {
  var hash = 0x811C9DC5; // FNV offset basis
  for (final byte in utf8.encode(seed)) {
    hash ^= byte;
    hash = _imul32(hash, 0x01000193); // FNV prime
  }
  return hash & 0xFFFFFFFF;
}

/// Computes `(a * b) mod 2^32`, treating [a] and [b] as unsigned 32-bit
/// integers — the web-safe equivalent of JavaScript's `Math.imul`.
///
/// Why this exists: a naive `(a * b) & 0xFFFFFFFF` is only safe on
/// platforms with real 64-bit integers (the Dart VM). Compiled to
/// JavaScript for web, Dart's `int` becomes a double with only 53 bits of
/// exact precision — multiplying two 32-bit numbers directly can overflow
/// that and silently produce a *different* result than on native. Splitting
/// each operand into 16-bit halves keeps every intermediate value well
/// under 2^53, so the result is bit-for-bit identical on every platform.
int _imul32(int a, int b) {
  final aLo = a & 0xFFFF;
  final aHi = (a >>> 16) & 0xFFFF;
  final bLo = b & 0xFFFF;
  final bHi = (b >>> 16) & 0xFFFF;
  final low = aLo * bLo;
  final cross = aHi * bLo + aLo * bHi;
  return (low + (cross << 16)) & 0xFFFFFFFF;
}
