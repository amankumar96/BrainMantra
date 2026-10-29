import { mathFactForDay } from "../mathFacts";

describe("mathFactForDay", () => {
  it("returns the same fact for two different times on the same UTC day", () => {
    const morning = new Date("2026-03-01T01:00:00Z");
    const night = new Date("2026-03-01T23:59:00Z");
    expect(mathFactForDay(morning)).toBe(mathFactForDay(night));
  });

  it("can return a different fact on a different day", () => {
    const day1 = new Date("2026-01-01T12:00:00Z");
    const day2 = new Date("2026-01-02T12:00:00Z");
    // Not guaranteed to differ for every pair of days (list could repeat
    // sooner for short lists), but day 1 vs day 2 of the year must differ
    // since the list has more than 2 entries.
    expect(mathFactForDay(day1)).not.toBe(mathFactForDay(day2));
  });

  it("wraps around the list length without throwing, past day 365", () => {
    const lateInLeapYear = new Date("2028-12-31T12:00:00Z");
    expect(() => mathFactForDay(lateInLeapYear)).not.toThrow();
    expect(typeof mathFactForDay(lateInLeapYear)).toBe("string");
  });

  it("is deterministic for the same input", () => {
    const date = new Date("2026-06-15T12:00:00Z");
    expect(mathFactForDay(date)).toBe(mathFactForDay(date));
  });
});
