# MathBlitz — The Journey So Far (End-to-End Log)

A plain-language walkthrough of everything done on this project, in order, and why. Pairs with [`01-project-file-guide.md`](./01-project-file-guide.md), which explains what each individual file is.

---

## The big idea

MathBlitz is a math + reasoning quiz game (Flutter, so one codebase → Android + iPhone + web). The rule we're building under, set out in `ARCHITECTURE.md`: **build in layers, and don't start the next layer until the current one is proven correct by automated tests.** So far we've completed exactly one layer — the data blueprints — and nothing is playable yet. That's expected, not a shortfall.

---

## Stage 1 — Deciding what the game actually is

Before writing any code, we nailed down the gameplay concept:

1. **Math Test mode** — random questions, easy → hard, 4 multiple-choice options. Right answer → a balloon-burst animation; wrong answer → a red cross.
2. **Reasoning Test mode** — a second, separate category of questions, starting with:
   - **Family-tree relationship questions** (e.g. "if A is B's father and B is C's son, how is A related to C?"), scaling in difficulty from direct relations → in-laws → multi-generation chains.
   - **Shape-identification questions** (e.g. "which shape has 5 sides?").
   - Deliberately left open to add more reasoning question types later (seating arrangements, patterns, etc.) without having to redesign anything.

This mattered because it changed the data blueprint: a `Puzzle` needed a way to say "which of these two big categories am I" *before* we wrote any code, so nothing has to be rebuilt later.

## Stage 2 — Planning Phase 0

We used Claude's "plan mode" to work out, before touching any files:
- What tools were missing on this machine (Flutter/Dart weren't installed at all).
- How the `Puzzle` blueprint needed to change to support both math and reasoning questions (added a `category` field).
- Which free tools/plugins were worth adding (a Flutter VS Code setup, and a documentation-lookup tool called Context7) versus which weren't worth the hassle (e.g. Figma's free tier is too limited to be useful here).
- Confirmed with you: install Flutter automatically (rather than you doing it by hand), build the project directly in this folder (not a nested subfolder), and support Android + iPhone + web from the start.

## Stage 3 — Installing the toolchain

This computer had no Flutter and no Dart installed. We:
- Downloaded Flutter (Google's toolkit) to `C:\src\flutter`.
- Registered it so it's available from any terminal going forward.
- Confirmed it works (`flutter doctor` — some optional pieces like Android Studio and Visual Studio C++ are still missing, but those are only needed much later, for actually installing the app on a real device; they don't block anything we're doing now).
- Installed two VS Code add-ons that give proper Dart/Flutter editing support (syntax highlighting, autocomplete, inline test running).

We also discovered a plan assumption was wrong: there's no official "Flutter" package in Windows's app installer (`winget`) — only a separate "Dart SDK" package — so we used Flutter's own recommended method (downloading it via `git`, the same tool that manages this project's save-history) instead.

## Stage 4 — Creating the project

Ran Flutter's official "new project" generator, which:
- Set up everything needed to eventually package the app for Android, iPhone, and web (see the file guide for what all of that is).
- Came with a demo "counter" app pre-installed (a button that counts up) to prove the generator worked — we deleted that immediately, since the build rules say no real screens until the logic underneath is tested.
- We double-checked the generator's own demo actually ran and passed its own test *before* deleting it, so we know the toolchain genuinely works end to end.

Then we reshaped the generated project to match the plan's intended folder layout — creating empty, reserved folders for code that doesn't exist yet (see the file guide, section 2).

## Stage 5 — Building the three data blueprints (the actual work of "Phase 0")

This is the heart of what got built. Three files, each describing the *shape* of one kind of data — no game logic, just structure:

1. **`Puzzle`** — one quiz question (question text, up to 4 options, the correct answer, difficulty, time limit, and now also which category/type it is).
2. **`GameSession`** — one round of play (score, lives, combo, every question asked + whether each was answered correctly).
3. **`PlayerStats`** — your saved profile across sessions (high score, streak, coins, best score per difficulty).

For each one, we also wrote a matching **test file** — code that automatically checks the blueprint for bugs by converting sample data to the text format used for saving, converting it back, and confirming nothing was lost or corrupted along the way (including subtle things like a "true/false" answer not accidentally turning into text). We ran these 24 checks and Dart's built-in style-checker (`flutter analyze`), and all of it came back clean.

**Why this order, and why so much testing before anything visual exists?** Because if the underlying data shape has a bug, every single feature built on top of it (question generation, scoring, screens, animations) inherits that bug. Getting this layer provably right first means everything after it can be trusted.

## Stage 6 — Saving the work

- Wrote the build plan (`ARCHITECTURE.md`) to disk for the first time (it had only existed as text pasted into the conversation before this), updated with the math/reasoning category decision baked in.
- Saved the project's history to Git in five separate checkpoints ("commits"), one per logical step, each with a description of what changed and why.
- Connected the project to your GitHub account (`github.com/amankumar96/Maths_test`) and uploaded (pushed) all five checkpoints there — so the work now exists both on this computer and safely backed up in the cloud, with full history of how it was built.

## Stage 7 — Explaining everything (this document + the file guide)

You asked for a plain-language walkthrough of what exists and why, and to have it saved locally for your own reference rather than only living in the chat — hence this `Documents/` folder, which is intentionally **not** uploaded to GitHub (added to `.gitignore`) since it's your personal notes, not part of the shipped app.

---

## Where things stand right now

| | |
|---|---|
| ✅ Done | Phase 0 — all 3 data blueprints, 24 automated checks passing, code style clean |
| ✅ Saved | 5 commits pushed to GitHub `main` branch |
| ⏳ Not started | Everything with actual game logic or visuals — question generation, scoring rules, screens, animations |
| ▶️ Next | Phase 1, Step 1.1: `rng_service.dart` — a controlled, testable way to generate random numbers, which every later question-generator will depend on |

## Glossary (plain-English translations of terms used above)

- **Blueprint / model** — a description of what a piece of data looks like (its fields), with no behavior attached.
- **Round-trip test** — converting data to a saved format and back, then checking nothing changed.
- **Toolchain** — the collection of installed software needed to build the app (Flutter, Dart, editor add-ons).
- **Commit** — one saved snapshot of the project's files, with a description of what changed.
- **Push** — uploading your saved snapshots to GitHub (the cloud backup/collaboration service).
- **Boilerplate** — standard, repetitive setup code that a generator writes for you, which you rarely if ever hand-edit.
- **Phase / gate** — the build plan is split into phases; a "gate" is a checkpoint (usually "all tests pass") that must be cleared before the next phase starts.
