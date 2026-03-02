# TapLift — Manual Verification Checklist

This checklist covers the flows that **cannot** be fully automated (Live Activity,
Back Tap, Siri Shortcuts, physical device interactions).

Run through this list before every release.

---

## Prerequisites

- [ ] Physical iPhone with iOS 17+ (Live Activities require a real device)
- [ ] Back Tap configured: **Settings → Accessibility → Touch → Back Tap → Double Tap → "Start TapLift Workout"**
- [ ] TapLift installed from Xcode (debug or release)
- [ ] Workout data seeded (at least one workout day with 2+ exercises)

---

## 1. Live Activity — Start & Display

| # | Step | Expected | ✅ |
|---|------|----------|----|
| 1 | Open TapLift → navigate to Today screen | Live Activity appears on Lock Screen & Dynamic Island | |
| 2 | Verify workout day name shows | e.g. "Push" in the Live Activity header | |
| 3 | Verify exercise name shows | First exercise name (e.g. "Bench Press") | |
| 4 | Verify reps/weight display | Matches the last-used values for that exercise | |

## 2. Live Activity — Stepper Buttons

| # | Step | Expected | ✅ |
|---|------|----------|----|
| 5 | Tap **+** on reps (Lock Screen) | Reps increments by 1 | |
| 6 | Tap **−** on reps | Reps decrements by 1 (min: 1) | |
| 7 | Tap **+** on weight | Weight increments by step (2.5 kg / 5 lb) | |
| 8 | Tap **−** on weight | Weight decrements (min: 0) | |
| 9 | Tap **Done Set** / ✓ button | Set is logged; set counter updates | |

## 3. Live Activity — Exercise Navigation

| # | Step | Expected | ✅ |
|---|------|----------|----|
| 10 | Tap **Next Exercise** (→) | Switches to next exercise, loads its defaults | |
| 11 | On last exercise, tap Next | Wraps to first exercise | |
| 12 | Tap **Previous Exercise** (←) | Switches to previous exercise | |
| 13 | On first exercise, tap Previous | Wraps to last exercise | |

## 4. Back Tap → Shortcut

| # | Step | Expected | ✅ |
|---|------|----------|----|
| 14 | Lock phone, double-tap back | Live Activity starts (dialog: "Workout started: Push") | |
| 15 | With activity running, double-tap back | Dialog: "Workout updated: [exercise]" | |
| 16 | End Workout shortcut | Activity dismisses, dialog: "Workout ended" | |

## 5. Data Sync — Live Activity → App

| # | Step | Expected | ✅ |
|---|------|----------|----|
| 17 | Log 2+ sets from Live Activity buttons | | |
| 18 | Open TapLift app | Sets appear in Today view with correct reps/weight | |
| 19 | Verify "source" shows as Live Activity (if displayed) | | |
| 20 | Verify set count per exercise updates | | |

## 6. Offline Behavior

| # | Step | Expected | ✅ |
|---|------|----------|----|
| 21 | Enable Airplane Mode | | |
| 22 | Log sets from Live Activity & in-app | Sets are stored locally | |
| 23 | Disable Airplane Mode, open app | Sets sync to backend (if configured) | |
| 24 | Verify sets are marked as synced | No duplicates on next sync | |

## 7. Settings Persistence

| # | Step | Expected | ✅ |
|---|------|----------|----|
| 25 | Change weight unit to **lb** | Weight step changes to 5 lb | |
| 26 | Force-quit and relaunch app | Settings persist (lb, 5 lb step) | |
| 27 | Live Activity also uses lb/5 lb step | Weight increments by 5 | |

## 8. Edge Cases

| # | Step | Expected | ✅ |
|---|------|----------|----|
| 28 | Rest day (no workout mapped for today) | "Rest Day" shown, no Live Activity | |
| 29 | Empty exercise list | No crash; graceful "Rest Day" or empty state | |
| 30 | Kill app while Live Activity is running | Live Activity continues working | |
| 31 | Very long exercise name (30+ chars) | Text truncates gracefully in Live Activity | |
| 32 | Weight at 0, tap decrement | Weight stays at 0, no negative | |
| 33 | Reps at 99, tap increment | Reps stays at 99 | |
| 34 | Reps at 1, tap decrement | Reps stays at 1 | |

---

## Sign-off

| | |
|---|---|
| **Tester** | |
| **Date** | |
| **Build** | |
| **Device** | |
| **iOS Version** | |
| **All Passed?** | ☐ Yes ☐ No |
| **Notes** | |
