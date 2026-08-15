# Udbr — Design Document

## Overview

A breathing-awareness game. The player swipes their finger up while inhaling and down while exhaling, or uses arrow keys (UP=inhale, DOWN=exhale, no key=hold). Measures consistency of rhythm and analyses phase durations using autocorrelation + phase-folding at session end.

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
- **The tutorial is all talking steps, deliberately** — the only one in the app that is. Udbr has
  no discrete action to wait for, and the events it does emit are not trustworthy enough to
  congratulate anyone on: `_inhale_count` increments the instant the up-latch engages, which a
  single pixel of upward drag will do. Waiting on `inhaled` and then saying "that is one inhale"
  told players they had done something they had not.
- **How the input really works** (`scripts/main.gd` digitized-swipe branch + `_process_kbd`):
  touching down sets an ANCHOR; `swipe_accum` measures displacement from it, not velocity. Holding
  the finger *above* the anchor latches `is_in_digitized_swipe_up`; going more than 30px below
  flips it. The flags are recomputed **only on drag events**, so stopping leaves the last direction
  latched and the ball keeps traveling to the end of the lane. Direction is therefore *where the
  finger is relative to where it went down*, not which way it is currently moving — and
  "hold still to hold your breath" is wrong, which is what earlier versions of this tutorial said.
- If udbr's input is ever reworked (a real hold state, a sensible movement threshold), this can
  become a doing tutorial like the others: the `inhaled` / `exhaled` hooks in `level.gd` are
  already in place.
- **Guided mode is ONE ball**, moving by itself through `UdbrG.get_guided_durations()` (shown as
  e.g. "4-2-6-2 s") with the label naming each phase. It is not a second ball racing the player's,
  which is what the tutorial used to claim.
- **The input is the lesson.** It is not a swipe: the finger goes down and STAYS down, and the
  direction comes from how far it has moved since (`scripts/main.gd` digitized-swipe handling, 30px
  hysteresis); lifting ends the breath. A flick does nothing at all, which is exactly what a player
  who read the word "swipe" will try first. The steps wait on `inhaled` and `exhaled`, so the
  tutorial only moves on once the gesture has genuinely been held in each direction.
- The tutorial also says plainly that there is **no** fail state — with nothing ever correcting
  them, a player doing it entirely wrong otherwise assumes the game is broken.
- No spotlights: the swipe lane fills the screen, so highlighting it dims nothing and leaves the
  caption nowhere to sit that is not on top of it.
