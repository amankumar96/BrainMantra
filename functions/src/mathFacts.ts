/**
 * Hand-ported copy of Flutter's `_mathFacts`/`mathFactForDay` in
 * lib/services/notification_service.dart. KEEP THESE TWO LISTS IN SYNC —
 * there is no single-sourcing between the Dart app and this Cloud
 * Functions runtime; if one is edited, update the other to match.
 */
const MATH_FACTS: readonly string[] = [
  "Pythagoras led a secret society that banned eating beans.",
  "Euler kept producing major math work after going completely blind.",
  "Zero as a number wasn't widely used in Europe until the 1200s.",
  'The "=" sign was invented because its creator was tired of writing "is equal to" by hand.',
  "Ramanujan taught himself advanced mathematics from a single old textbook.",
  "Fibonacci's famous sequence first appeared in a problem about rabbit breeding.",
  'Archimedes reportedly ran through the streets shouting "Eureka!" after a bathtub discovery.',
  "As a schoolboy, Gauss summed 1 to 100 in seconds by pairing up numbers.",
  'The word "algebra" comes from Arabic "al-jabr", meaning "reunion of broken parts".',
  "Newton and Leibniz each invented calculus independently, sparking a bitter rivalry.",
  "Ada Lovelace wrote the first published computer algorithm — in the 1840s.",
  "Pi has trillions of calculated digits, but about 39 are enough for any real-world measurement.",
  "The Babylonians used a base-60 number system — why an hour has 60 minutes.",
  "Alan Turing helped crack wartime codes and laid the groundwork for computer science.",
  'A "googol" (1 followed by 100 zeros) got its name from a mathematician\'s 9-year-old nephew.',
];

/**
 * A deterministic "fact of the day" pick — same calendar date always picks
 * the same entry, with no stored index/state needed. Mirrors Dart's
 * `mathFactForDay` exactly (day-of-year modulo list length), including the
 * same harmless cross-year collision when day-of-year wraps past the
 * list's length.
 */
export function mathFactForDay(now: Date): string {
  const startOfYear = Date.UTC(now.getUTCFullYear(), 0, 1);
  const dayOfYear = Math.floor(
    (Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()) -
      startOfYear) /
      86400000,
  );
  return MATH_FACTS[dayOfYear % MATH_FACTS.length];
}
