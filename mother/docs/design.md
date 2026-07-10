# Mother Snake — Design Document

## Overview

A breathing game where the player (child snake) follows the mother snake's movement. The mother traces a smootherstep-eased path determined by the breathing pattern: up during inhale, flat during hold, down during exhale, flat. The child snake grows longer over time. Score is based on how closely the player's breathing rhythm matched the target pattern, measured via autocorrelation + phase-folding at session end.

## File Structure

```
mother/
├── docs/design.md
├── scenes/
│   ├── main.tscn      — Node root with Level child
│   └── level.tscn     — CanvasLayer with MotherCanvas + overlays
└── scripts/
    ├── globals.gd      — MotherG autoload; presets, PATTERN_RING_THRESHOLD, GenericGameUtil
    ├── main.gd         — orchestrator; main menu wiring; score saving
    ├── level.gd        — game logic + _do_draw()
    └── mother_canvas.gd — thin Control whose _draw() calls level._do_draw(self)
```

## Layout

- **Single background**: dark, unified (no split).
- **Mother y range**: `M_TOP_FRAC=30%` to `M_BOT_FRAC=56%` (center ~43%, just above screen mid). Child starts 60px below `_m_bot_y` at session start.
- **Both heads at `HEAD_X_FRAC=0.82`**.
- Child color: always `Color(0.30, 0.25, 0.90, 0.92)` (blue).

## Mother Path

`_phase_y_at(t_ms, top_y, bot_y)` uses smootherstep easing (`x³(x(6x-15)+10)` — C2 continuity, no sharp corners at hold transitions):

```
if t < inhale_ms:  return lerp(bot_y, top_y, smootherstep(t/inhale_ms))
if t < hold_top:   return top_y
if t < exhale_ms:  return lerp(top_y, bot_y, smootherstep(t/exhale_ms))
return bot_y
```

## Child Input

- **Touch**: drag vertically — position follows finger within `[_c_top_y, _c_bot_y]`.
- **Keyboard**: smooth velocity (`lerpf` factor 8). UP held → lerps toward inhale speed, DOWN held → exhale speed, no key → velocity lerps to 0 (hold). This gives curved path shape matching mother's smootherstep.
- Body drawn from history ring buffer (16ms intervals, 3000 slots ≈ 48s max body).

## Trace Recording

`_current_trace` stores `Vector2(elapsed_ms, y_norm)` samples every 200ms (y_norm = (child_y - c_top_y) / c_range). Finalized into `_trace_segments` on session end.

## End-of-Session Analysis: `_compute_phase_durations(keys)`

Keyboard is polled every 50ms during the session. Each sample appended to `_key_poll`:
- `1` = UP pressed (inhale)
- `2` = DOWN pressed (exhale)
- `0` = neither (hold)

`_compute_phase_durations(keys: Array) -> Array` receives the full poll array and returns `[inhale_ms, hold_top_ms, exhale_ms, hold_bot_ms]` as average phase durations in ms. The stub returns `[0, 0, 0, 0]` — user fills the implementation.

## Scoring

Pattern accuracy score from FFT analysis vs. preset target:

```
err = mean of |measured - target| / target for each of 4 phases
score = max(0, round((1 - min(err, 1)) * 100))
```

Saved via `game.add_score_and_time(score, 0, true)` then `game.save_score(get_session_score())`.

**Score array** (saved): `[unixtime, score, time_left, times_run, didwin, wasaborted, duration_min, session_ps, rt_ms]`
- Index 8 = `rt_ms`: average reaction time in ms (trimmed mean of center 80th percentile). 0 if no data or active mode.

Results display shows measured vs. target for each phase and average reaction time (ms).

## Reaction Time

`calc_reaction_time(mother_commands, child_actions)` — both arrays are 50ms-slot polls (0=hold, 1=inhale, 2=exhale).

For each phase transition in mother_commands:
- Look back 4 slots (200ms): if child made the same transition already → record 0 (early reaction)
- Look ahead 40 slots (2s): find first slot where child makes the same transition → record delay in slots
- If neither found: skip (missed transition, not counted)

Returns trimmed mean of center 80th percentile of recorded values × 50ms, rounded to int.

**Stats display**: reaction time appears in the Scores table "React Time" column, the Speed tab, and the Chart tab as a second metric ("React Time", lower is better).


## Scroll Speed

`screen_w / (1.5 * cycle_ms)` — ~1.5 breathing cycles visible at once.

## Settings

Index 0: `duration_min` (1–30, default 1)
Index 1: `selected_preset` (index into `GUIDED_PRESETS`)

Presets (seconds): `[4,1,4,1]`, `[6,1,6,1]`, `[4,4,4,4]`, `[2,1,2,1]`.

## Key Pitfalls

- `_analyze_trace()` needs at least ~2 complete breathing cycles to detect the period (autocorrelation threshold 0.15). Short sessions or no movement return `valid=false`.
- Mother path uses smootherstep, not smoothstep — ensures C2 continuity (no velocity jump at hold boundaries).
- History ring buffer has a 4-slot warm-up: body is not drawn until 4 slots are populated.
- The child body (and the active-mode mother body) is sampled at times snapped to a fixed grid (`t_base = floor(elapsed/dt_step)*dt_step`, `dt_step = step/scroll_px_per_ms`), not at fixed screen-x. Sampling at fixed screen-x makes sharp trail vertices (up→down with no hold) alias and jitter as they scroll, because the peak drifts between sample points each frame. Snapping the sample times keeps each vertex's neighboring samples constant frame-to-frame, so the trail scrolls smoothly. The guided mother path avoids this differently — it inserts exact vertices at the known phase-transition times (`_extra_xs`).
