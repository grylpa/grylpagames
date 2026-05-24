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
