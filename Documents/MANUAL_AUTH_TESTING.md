# Brain Mantra — Manual Login & Sign-Up Testing Guide

A step-by-step script for manually testing every account-creation and sign-in path
by hand on a real device/emulator. No code changes needed to follow this — it's a
checklist, not a code doc. ✅ = pass, ❌ = fail (note what actually happened).

Covers: `lib/screens/sign_up_screen.dart`, `lib/screens/login_screen.dart`,
`lib/services/auth_service.dart`, and how `lib/main.dart`'s auth gate reacts to
each outcome.

---

## 0. Before you start

- **"Confirm email" is ON** for this Supabase project — an email/password sign-up
  does **not** log you in immediately. It sends a confirmation link, and the
  account can't log in until that link is clicked. Google sign-in never goes
  through this step.
- **The app never navigates to Home itself** on a successful login/sign-in —
  `main.dart`'s root auth-gate listens to Supabase's session state and swaps the
  whole screen to `HomeScreen` automatically the instant a session becomes
  active. If you're stuck on the login/sign-up screen after what looked like a
  successful action, that's a real bug worth flagging, not expected behavior.
- **Reusable test emails**: since each email can only sign up once, use either:
  - **Gmail "+" aliases** — `youraddress+test1@gmail.com`,
    `youraddress+test2@gmail.com`, etc. all deliver to your one real inbox, and
    Supabase treats each as a distinct account.
  - A throwaway inbox service (e.g. [Mailinator](https://www.mailinator.com/),
    [Mailsac](https://mailsac.com/)) if you'd rather not use your own address at
    all.
- **To reuse the same email address**, delete the account first (in-app: Home →
  scroll to the red **Delete Account** box, or directly in the Supabase
  dashboard's Authentication → Users list) — Supabase won't let you sign up
  twice with the same address.
- Have the Supabase dashboard open in a browser tab (**Authentication → Users**)
  if you want to cross-check what actually landed server-side at each step.

---

## 1. Email sign-up — happy path

Screen: **Create Account** (`SignUpScreen`).

1. From the Login screen, tap **"Don't have an account? Sign up"**.
2. Fill in:
   - **Display name**: anything non-empty, e.g. `Test Player`.
   - **Email**: a fresh test address (see §0).
   - **Password**: at least 6 characters, e.g. `test1234`.
3. Tap **"Sign Up with Email"**.
4. ✅ Expect: the screen switches to a **"Check your email"** state — a mail
   icon, "We've sent a confirmation link to `<email>`. Click it, then log in
   below.", and a **"Back to Log In"** button. You are *not* taken to Home.
5. Open that inbox, find the Supabase confirmation email, and **click the link**
   inside it.
6. ✅ Expect: the link opens and confirms the account server-side (you may land
   on a plain Supabase confirmation page in the browser — that's expected, it's
   not part of this app).
7. Back in the app, tap **"Back to Log In"** (or relaunch the app).
8. Log in with that same email + password (§2 below).
9. ✅ Expect: successful login, app swaps straight to Home.
10. In the Supabase dashboard's **Authentication → Users**, confirm the new user
    now shows a non-empty **"Last Sign In"** and that its email is marked
    confirmed.

---

## 2. Email login — happy path

Screen: **Brain Mantra** login (`LoginScreen`), the "or log in with email"
section.

1. Enter the email + password of an **already-confirmed** account (e.g. the one
   from §1).
2. Tap **"Log In with Email"**.
3. ✅ Expect: a brief loading spinner on the button, then the app swaps straight
   to Home — no separate "success" screen, no manual navigation needed.

---

## 3. Email sign-up — validation & error cases

All on the **Create Account** screen, without submitting a real request unless
noted.

| # | Steps | Expected result |
|---|---|---|
| 3.1 | Leave **Display name** empty, fill the rest, tap Sign Up | Inline error "Enter a display name"; nothing submitted |
| 3.2 | Enter an email with no `@` (e.g. `notanemail`), tap Sign Up | Inline error "Enter a valid email" |
| 3.3 | Enter a password under 6 characters (e.g. `abc12`), tap Sign Up | Inline error "At least 6 characters" |
| 3.4 | Fill in a **valid** form, submit, then immediately try signing up **again with the exact same email** (before confirming it) | A red error message appears above the form (Supabase's own "already registered"-style message) — the screen stays on the form, doesn't silently succeed |
| 3.5 | Sign up with an email that's already a **confirmed** account | Same as 3.4 — a clear error, not a silent no-op |
| 3.6 | While the request is in flight (tap Sign Up once), confirm the button shows a small spinner and can't be tapped again | Button is disabled/shows spinner during submission |

---

## 4. Email login — validation & error cases

All on the **Brain Mantra** login screen's email section.

| # | Steps | Expected result |
|---|---|---|
| 4.1 | Leave email empty (or no `@`), tap Log In with Email | Inline error "Enter a valid email" |
| 4.2 | Leave password empty, tap Log In with Email | Inline error "Enter your password" |
| 4.3 | Correct email, **wrong password**, submit | A red error message with Supabase's invalid-credentials text; stays on the login screen |
| 4.4 | Sign up a **new** email/password (§1 steps 1–4) but **do not** click the confirmation link, then immediately try to log in with that same email/password | A friendly message: *"Almost there — click the confirmation link we emailed you before logging in."* — not Supabase's raw technical error text |
| 4.5 | Log in with an email that was **never signed up at all** | A red error message (Supabase's "invalid credentials" — this project deliberately doesn't reveal whether the email exists, for basic account-enumeration hygiene) |

---

## 5. Google sign-in

Available as the **first, most prominent button** ("Continue with Google") on
both the Login and Sign Up screens — functionally identical either way, since
Google sign-in never distinguishes "new" vs "returning" the way email does.

1. Tap **"Continue with Google"** on either screen.
2. ✅ Expect: the native Google account picker/Credential Manager sheet opens
   (not a browser redirect on Android/iOS).
3. Pick a Google account (or add one if none is signed in on the device).
4. ✅ Expect: back in the app, it swaps straight to Home — **no email
   confirmation step**, regardless of whether this is the first time this
   Google account has ever been used with the app.
5. **First-time Google sign-in specifically**: in the Supabase dashboard, check
   that a `profiles` row was created for this user with a sensible
   **display name** (Google's own account name/email prefix — see
   `AuthService.ensureProfileExists`'s fallback chain), not a raw user ID.
6. **Returning Google sign-in**: sign out (Home's logout icon, top-right) and
   sign back in with the same Google account — should reach Home immediately
   again, with your existing score/streak intact (not reset).
7. **Cancel path**: tap "Continue with Google", then dismiss the account picker
   without choosing anything. ✅ Expect: you're returned to the login/sign-up
   screen, no crash, no stuck loading spinner.

---

## 6. Interaction with account deletion (regression check)

This app had a real bug where a deleted-then-recreated account showed stale
data — worth specifically re-testing after any auth-related change.

1. Sign in (Google or email) to an account that has **played at least one
   session** (so it has a non-zero score/streak).
2. Delete it: Home → scroll to **Delete Account** → confirm.
3. ✅ Expect: you land back on the Login screen after deletion completes.
4. Sign back in (or sign up again, if it was an email account) using the
   **exact same identity** (same Google account, or the same email address).
5. ✅ Expect on Home:
   - Marks badge shows **0** (not the old account's leftover score).
   - Streak shows **0**.
   - Greeting shows the freshly-created display name, not the old one.
6. Start a Play session — ✅ expect tier 1 questions only (score < 50), not
   tier 3+.

If any of these show stale data from the deleted account, that's a real
regression — see `AuthService.deleteAccount()`'s doc comment for the local
cache-clearing this relies on.

---

## 7. Session persistence

1. Log in successfully (any method).
2. Fully close the app (swipe it away from recent apps, not just background it).
3. Reopen the app.
4. ✅ Expect: it goes **straight to Home**, no login screen shown — Supabase
   persists the session locally, so this should hold until an explicit sign-out.
5. Sign out (Home's logout icon).
6. Reopen the app (or just observe immediately).
7. ✅ Expect: back on the Login screen, and it **stays** there on subsequent
   relaunches until signing in again.

---

## Result log

| Section | Date tested | Result | Notes |
|---|---|---|---|
| 1. Email sign-up happy path | | | |
| 2. Email login happy path | | | |
| 3. Sign-up validation/errors | | | |
| 4. Login validation/errors | | | |
| 5. Google sign-in | | | |
| 6. Delete + re-create regression | | | |
| 7. Session persistence | | | |
