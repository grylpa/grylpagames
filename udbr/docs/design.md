# Udbr — Design Document

## Overview

A breathing-awareness game. The player swipes their finger up while inhaling and down while exhaling, or uses arrow keys (UP=inhale, DOWN=exhale, no key=hold). Measures consistency of rhythm and analyses phase durations using autocorrelation + phase-folding at session end.


### The one that actually stopped the swipes

Symptom: after playing another game the breathing game behaves as though "up" is held down for
ever. It is not the swipe code at all -- `Input.is_action_pressed("up")` really is stuck true.

`MainGlobals.sim_action()` fires an `InputEventAction` with `pressed = true` and nothing in the
project ever sent the matching release (the only `pressed = false` in the codebase was a commented
out line in `help.gd`). An action press LATCHES: `Input.is_action_pressed()` keeps reporting it
until released. So one flick steering a capsule "up" in pneumo left "up" held for the rest of the
session, and the breathing games are the only ones that poll `Input.is_action_pressed("up")` every
frame -- everything else consumes directions as `event.is_action_pressed(...)` inside `_input`, a
one-shot that does not care. Play pneumo, change game, and the ball rises on its own.

`sim_action()` now queues the action and `MainGlobals._process()` sends the release on the next
frame. Measured, with and without:

| | `_input` gets the press | `is_action_just_pressed` | `is_action_pressed` after 5 frames |
|---|---|---|---|
| before | yes | yes | **still true** |
| after | yes | yes | false |

Both ways of consuming an action still work; only the latch is gone. Real keyboard holds are
untouched, because a real key sends a real release.

### A lost touch used to kill the swipe for good

`MainGlobals.is_in_digitized_swipe_up` / `_dn` are *latched*: `_update_digitized_swipe()` holds the
last direction while the finger is still, because a finger held motionless sends no drag events and
holding still is meaningful here. The breathing games then **poll** those flags every frame
(`udbr/scripts/level.gd:448`, and the same in river, crack and mother).

That makes them the only games that can get stuck. A touch can be taken away without ever sending
its release -- an Android system gesture, the notification shade, the recents switcher. When that
happens `MainGlobals.swipe_active` stays true, the finger stays claimed in `_dsw_index`, and the
latched direction is never cleared, so the game behaves as though a finger were held down forever.
Every other drag game escapes this because its gesture is one-shot: gorilla fires `sim_action` at
release, wolves and storm emit `sig_path_drawn` at release, and a lost release costs them one
gesture rather than all of them.

**The swipe handling is index-agnostic.** `scripts/main.gd` keeps one sample stream per touch
index, `_dsw_streams = {index: [[time_ms, y], ...]}`, and the direction each frame comes from
whichever stream has moved most inside `DSW_WINDOW_MS`. Any number of fingers may be down: a finger
held still contributes a displacement of zero so it cannot fight the one doing the work, and a
finger that joins part way through does not reset the direction the first one set (only the first
finger down starts from neutral).

That is also the cure for the bug that used to lock these games out. There was a single owning
index, and when a release went missing the OS still believed that finger was down, so it never
handed out its index again -- every later touch arrived as index 1, 2, ... and the owner check
rejected all of them, the drags *and* the release that would have cleared the claim. The game then
sat reading the phantom's latched direction until the app restarted. With no owner there is nothing
to be a phantom of: a stale stream simply ages out of the window and stops contributing.

Note what does **not** work as a safety net: cross-checking `Input.is_action_pressed("touch")`.
That state is built from the same events, so a lost release leaves it stuck pressed too, and the
check compares a signal against itself.

Two further resets, deliberately overlapping:

- **Any finger coming up ends the gesture and clears every stream.** Simple and total. The price is
  that lifting a stray second finger drops a hold in progress; the next drag starts it again.
- **`GenericGameUtil.reset()` calls `MainGlobals.reset_swipe_state()`**, so every level start drops
  whatever survived. `reset()` sets `playing = false`, so it only runs at a boundary and never
  interrupts a real gesture. A backstop, not a fix: it bounds how long anything can live.

## File Structure

```
udbr/
├── scripts/
│   ├── globals.gd      — UdbrG autoload; owns GenericGameUtil instance
│   ├── main.gd         — Orchestrator; menus, signals, score metadata
│   ├── level.gd        — Session logic, swipe/reversal detection, FFT analysis
│   ├── swipe_area.gd   — Custom drawing: progress bar, guide arrows, finger indicator
│   └── graph.gd        — Y-position-vs-time chart with per-segment polylines
├── scenes/
│   ├── main.tscn
│   └── level.tscn
└── docs/
    └── design.md
```

## Modes

### Active (free-form) Mode
Player-driven. Two input methods:
- **Touch/drag**: swipe up=inhale, down=exhale. Reversals detected via `_REVERSAL_THRESHOLD_PX`.
- **Keyboard**: UP arrow=inhale (position moves toward top), DOWN=exhale (moves toward bottom), no key=hold (position stays). Smooth velocity (`lerpf` factor 8). Speed computed from guided-duration presets so a full inhale press brings position from bottom to top in exactly `d[0]` seconds. Position recorded to `_current_segment` every 100ms.

`_kbd_used` flag tracks whether keyboard was used. Keyboard trace is finalized in `_on_session_complete()`.

### Guided Mode
Reference ball animates the target breathing pattern. Player follows visually (no scoring from player position).

## Trace Recording

Every input sample is stored in `_current_segment` as `Vector2(time_ms, y_norm)`, where `y_norm = screen_y / swipe_area_height` (0=top, 1=bottom). On finger lift or session end, `_current_segment` is appended to `_trace_segments`.

## End-of-Session Analysis: `_analyze_trace()`

Replaces real-time phase tracking for phase-duration display. Algorithm:

1. **Flatten** all segments into a sorted point list.
2. **Resample** to 500ms uniform grid (linear interpolation).
3. **Autocorrelation** of zero-mean signal over lags [3s..60s] to find breathing period. Returns `valid=false` if peak correlation < 0.15.
4. **Phase-fold** all samples onto N=60 bins modulo detected period; apply 3-tap circular smoothing.
5. **Classify bins**:
   - ≤ 20% from wmin → hold_top (inhale hold)
   - ≥ 80% from wmin → hold_bot (exhale hold)
   - Decreasing → inhale (moving toward top)
   - Increasing → exhale (moving toward bottom)
6. Return `{valid, period_ms, inhale_ms, hold_top_ms, exhale_ms, hold_bot_ms}`.

## Statistics (touch mode)

Reversal-based, computed in `_compute_stats()`:

| Metric | Description |
|--------|-------------|
| `_mean_ms` | Mean reversal interval (after 1.75× median outlier removal) |
| `_stddev_ms` | Stddev of clean intervals |
| `_bpm` | 60000 / mean_ms |
| `_missed_cycles` | Outlier intervals (likely paused/missed breaths) |

## Consistency Score

`max(0, 100 − round(cv_pct))` where cv_pct = stddev/mean × 100.

Keyboard mode: score is 0 (no reversal-based metric).

## Buttons

Results panel shows **Again** (left) and **Done** (right) in an HBox. Panel has `offset_bottom = -110` (mobile) or `-80` (desktop) to clear the bottom action bar. Active mode Again/Done and guided mode Again/Done are separate constructs.

## Settings

`UdbrG.save_settings([duration_min])`:
- `duration_min` (int, default 1): session length 1–15 minutes.

## Tutorial

Coached tutorial in `udbr/scripts/tutorial.gd`; see `docs/tutorials.md` for the framework.

- **Entry**: as for the other games. `UdbrG.guided_mode` is saved, forced **off** for the tutorial,
  and restored afterwards: a rhythm to keep up with, on top of an input the player has never used,
  is one thing too many.
- **Hooks in `level.gd`** (no-ops outside tutorial mode): the first input emits `breathing_started`;
  the inhale/exhale counters emit `inhaled` / `exhaled`.
- **The tutorial text is taken from the game's own "I" instructions screen**
  (`udbr/scripts/main.gd::set_instructions`), which is accurate. Three earlier versions were wrong
  because they described a model derived from `scripts/main.gd` instead. The mistake: reading the
  hysteresis block (`scripts/main.gd:311-321`) but **not** `_process_vertical_steps` (`:381`),
  which does `swipe_accum.y -= sign(swipe_accum.y) * 50`. That makes `swipe_accum` a **rolling**
  displacement wrapping every 50 px, not the absolute distance from where the finger landed — so
  the "anchor" model (direction decided by where the finger *is* relative to touch-down) does not
  exist. With the wrap, continuing to slide upward keeps the up-latch engaged, which is precisely
  what the instructions say: *swipe UP while inhaling*. **If the tutorial and the instructions
  screen ever disagree, the instructions screen is right.**
- **The tutorial waits on `reached_top` / `reached_bottom`, not `inhaled` / `exhaled`.** The
  inhale/exhale counters increment on the direction LATCH, which engages within a frame or two of
  the first few pixels of drag. A step waiting on those finished before the ball had visibly moved,
  and the next (talking) step then froze the screen — measured at 24 of 25 frames paused during a
  swipe, versus 0 in normal play. From the player's side that is indistinguishable from "the ball
  does not move at all with my swipe". The new hooks fire when the ball actually reaches the end of
  the lane, i.e. a completed breath, so the gesture the tutorial asks for is the gesture it waits
  for.
- **The tutorial forces `selected_mode = 0` (Active), not `guided_mode = false`.** `guided_mode`
  is a getter-only computed property (`return selected_mode != 0`), so assigning to it did nothing
  and the tutorial ran in whatever Mode the menu was left on. It also raises `duration_min` to at
  least 5, because the default 1-minute session is short enough for the results panel to appear
  over the coach mid-lesson. Both live on `UdbrG`, outside the `GenericGameUtil` snapshot, so both
  are saved and restored by hand in `start_tutorial` / `_on_tutorial_done`.
- **Holding does NOT require keeping the finger down** — confirmed against the running game. The
  finger only needs to be on the screen while actually breathing in or out; during a hold you can
  lift it off. That matches the code: releasing clears both direction flags
  (`scripts/main.gd:206-209`) and the ball stops dead, which is what a hold should look like in the
  trace, whereas keeping the finger down leaves the last direction latched and the ball drifting
  until it clamps. **The "I" instructions screen still says "Keep touching while holding your
  breath", which contradicts this** — left alone, as it is the author's copy to decide on.
- **The caption is a narrow right-hand column** (`runner.caption_side = "right"`, set in
  `main.gd::start_tutorial`). The lane is vertical and centered and the ball travels its full
  height, so the default full-width caption docked at the bottom covers the one thing the player is
  meant to watch. The column is 32% of screen width against a 180 px (mobile) centered lane, and
  the probe asserts on every step that the caption rect does not intersect the lane rect.
- Because the column is narrow, **the captions are deliberately short and imperative** — one
  instruction per step, no paragraphs.
- **The input is the lesson.** It is not a swipe: the finger goes down and STAYS down, and the
  direction comes from how far it has moved since (`scripts/main.gd` digitized-swipe handling, 30px
  hysteresis); lifting ends the breath. A flick does nothing at all, which is exactly what a player
  who read the word "swipe" will try first. The steps wait on `inhaled` and `exhaled`, so the
  tutorial only moves on once the gesture has genuinely been held in each direction.
- The tutorial also says plainly that there is **no** fail state — with nothing ever correcting
  them, a player doing it entirely wrong otherwise assumes the game is broken.
- No spotlights: the swipe lane fills the screen, so highlighting it dims nothing and leaves the
  caption nowhere to sit that is not on top of it.

### Tutorial: reaching the end of a session

The tutorial forces `duration_min = 30`, so a slow player can actually reach the end of a session
while the coach is still running. `_on_level_session_done` now returns early in `tutorial_mode`:
it writes `learned_*` and `has_user_session`, which the "User" mode preset is built from, and those
are in-memory globals that a later legitimate save would persist — so a tutorial would quietly
become the player's own breathing pattern.
