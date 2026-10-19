# Play Store ASO — proposed store listing copy

This is a **review-only document**, not app code — there's nothing to build or run.
"Testing" this before deployment means: read it over, tweak the wording if anything feels
off, then paste the final text directly into Play Console → **Store presence → Main store
listing**. Store-listing text changes go live within a few hours and do **not** require a
new app release/build — unlike an actual code change, there's no APK/AAB involved.

All three fields below respect Google Play's current field limits (title 30 characters,
short description 80 characters, full description 4,000 characters) — character counts
are given so nothing silently gets truncated when pasted in.

## Why these words
Keywords are chosen from what the app actually does (Play mode, Daily Challenge, Age-Group
Tests, leaderboard/streaks, the scratch notepad, English/Hindi) rather than generic filler,
and repeated naturally a few times across the fields — Play's search indexing weighs this
text, especially the full description.

---

## Title (30 char limit)

```
Brain Mantra: Maths & IQ Quiz
```
*(29 characters)*

## Short description (80 char limit)

```
Maths & IQ reasoning quiz — daily challenges, streaks & leaderboard.
```
*(68 characters)*

## Full description (4,000 char limit)

```
Brain Mantra is a fast, fun maths and IQ reasoning quiz game that sharpens your brain a little every day.

🧠 WHAT YOU CAN DO
• Play quick maths and IQ reasoning quizzes anytime
• Take on the Daily Challenge — one fresh puzzle set that unlocks every day
• Practice with Age-Group Tests tailored to different difficulty levels
• Track your progress with streaks and climb the global Leaderboard
• Use the built-in scratch notepad for rough work on harder questions

🎯 WHY PLAYERS LIKE BRAIN MANTRA
• A genuine mix of maths problems and IQ-style logical reasoning — not just one or the other
• Short sessions that fit into a coffee break, or longer ones if you're on a roll
• Free to play, with an optional "watch an ad for a hint" if you get stuck
• Available in English and Hindi (हिंदी)

📊 REAL BRAIN TRAINING, NOT A ONE-OFF TEST
Every session adds to your score and streak, so you can see your maths and reasoning speed actually improve over time.

🔒 YOUR DATA
Sign in with Google in seconds. We only store what's needed to save your score, streak and leaderboard rank — see our Privacy Policy for full details.

Whether you're a student sharpening maths skills, preparing for a competitive or aptitude exam with IQ reasoning questions, or just someone who enjoys a quick brain-training quiz, Brain Mantra gives you a new challenge every day.

Download Brain Mantra now and start your streak today!
```
*(1,399 characters — well within the 4,000-char limit, leaving room to grow)*

---

## What's NOT changing
- App icon, feature graphic, screenshots (`store_assets/`) — untouched, no change requested.
- Package name (`com.brainmantra.app`), privacy policy URL, category — untouched.

## Verification (before pasting into Play Console)
1. Re-read the full description once for tone/accuracy as the app evolves (e.g. if a
   feature mentioned here is ever removed, update this doc first).
2. Confirm each field's character count below the limit (already checked at the
   character-count annotations above — re-check with any manual edits).
3. Paste into Play Console → Store presence → Main store listing → Save → check the
   live preview Play Console renders before publishing.
4. No app rebuild needed — this is a listing-metadata-only change.
