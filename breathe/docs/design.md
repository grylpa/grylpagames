# Breathe — Game Design & Implementation Document

## Overview

**Game name:** Breathe  
**Folder:** `breathe/`  
**Singleton:** `BreatheG`  
**Save key (short name):** `breathe`  
**Category:** Mindfulness  
**Background:** Dark navy `Color(0.07, 0.1, 0.18, 1.0)`  
**Initial score:** 0, no game-over condition  

Breathe is a meditation/mindfulness tracking tool. The player sets a session duration (1–15 minutes) and taps anywhere on screen once per breath — at a consistent point in the cycle (e.g. end of each exhale). A large breathing circle animates in sync with the player's detected rhythm. When the timer expires the screen shows statistical analysis of consistency and a tap timeline chart.

There are no levels, no scoring in the game-over sense. The **Consistency score** (0–100) is saved to the leaderboard: `max(0, 100 - round(stddev_ms / 10))`. Higher is better (100 = perfect consistency).

---

## File Structure

```
breathe/
├── docs/
│   └── design.md           ← this file
├── art/                    (empty — uses shared sounds only)
├── scripts/
│   ├── globals.gd          (BreatheG autoload)
│   ├── main.gd             (game orchestrator)
│   ├── level.gd            (session recording + results logic; CanvasLayer)
│   ├── tap_area.gd         (Control subclass: draws breathing circle + ring feedback)
│   └── graph.gd            (Control subclass: draws tap timeline chart in results)
└── scenes/
    ├── main.tscn
    └── level.tscn
```

---

## Registration

### `project.godot` autoloads
```
BreatheG="*res://breathe/scripts/globals.gd"
```

### `scripts/config.gd`
```gdscript
["breathe", "Breathe", "Track your breathing rhythm and consistency", "Mindfulness"],
```
And `"Mindfulness"` added to `CATEGORY_ORDER`.

---

## Scene Structure

### `scenes/main.tscn`
Root `Main` (Node, `main.gd`). Children:
- `Level` — instance of `level.tscn` (CanvasLayer)
- `Help` — instance of `res://scenes/help.tscn`, hidden

No `GameTick` timer — session timing is managed by `_process` delta accumulation in `level.gd`. No HUD — timer and breath count are custom labels within `level.tscn`.

### `scenes/level.tscn`
Root `Level` (CanvasLayer, `level.gd`). Children:
- `Background` (ColorRect) — full screen, dark navy, mouse ignored
- `TapArea` (Control, `tap_area.gd`) — full screen, captures all taps; draws breathing circle and ring feedback
- `SessionOverlay` (Control, mouse ignored) — floating labels shown during recording:
  - `TimerLabel` — countdown (64px, top-center)
  - `BreathCountLabel` — tap count (38px, cyan, below timer)
  - `BreathsWordLabel` — "breaths" context text (18px, dimmer)
  - `HintLabel` — "Tap once per breath" (bottom-center, 20px)
- `ResultsPanel` (PanelContainer, initially hidden) — shown after session ends:
  - `Margin/VBox/TitleLabel` — "Session Complete"
  - `Margin/VBox/MetricsLabel` — multi-line stats text
  - `Margin/VBox/Graph` (Control, `graph.gd`) — tap timeline chart, expands to fill space
  - `Margin/VBox/[HBox with Again + DoneButton]` — added dynamically in `_ready()`

---

## Globals (`BreatheG`)

| Variable | Default | Description |
|----------|---------|-------------|
| `duration_min` | 5 | Session duration in minutes (1–15) |

Settings saved as `[duration_min]`.

The `game` GenericGameUtil is initialised with `(16, 0, 0)` — 16 hours — so its built-in timer never expires. Session timing is managed entirely within `level.gd`.

---

## Gameplay Flow

1. Player opens game → main menu shows with Duration slider
2. Player adjusts duration (1–15 min) and presses Start
3. Session begins — countdown shows remaining time, breath count shows 0; breathing circle is static (no animation yet)
4. Player taps anywhere on screen once per breath; each tap:
   - Records timestamp (`_elapsed_ms` at tap time)
   - Triggers expanding ring animation centred on the circle
   - Increments displayed breath count
   - First tap sets `game.score_was_changed = true`
   - From tap 4 onwards: rhythm animation activates; amplitude ramps from 1/3 to full over taps 4–8
5. When elapsed time ≥ duration: session ends automatically
   - `_compute_stats()` runs analysis
   - `game.score = _consistency_score()` — saved to leaderboard
   - Results panel shown; `sig_session_done` emitted → `main.gd` saves score
6. Player presses Done or Again → main menu or new session

**Pausing:** `game.paused()` blocks `_process`, so the elapsed timer naturally pauses whenever any overlay is visible or the app loses focus.

**Abort (back without completing):** `_on_level_show_main_menu` clears ongoing score without saving.

---

## Breathing Circle Animation

Driven by rhythm detected from taps. State lives in `level.gd`; `tap_area.gd` reads it via `get_tap_draw_state()` and draws each frame.

### Rhythm Detection (`_update_rhythm`)

Called on every tap (from tap 1, effective from tap 4). Takes all inter-tap intervals, sorts them, keeps the middle 60% (trimmed mean) to ignore outliers and missed taps.

```
count = all intervals = tap_count - 1
keep  = clamp(round(count * 0.6), 3, count)
skip  = (count - keep) / 2
_rhythm_interval_ms = mean(intervals[skip .. skip+keep])
```

A smoothly lerped `_display_rhythm_ms` (lerp rate 0.5/s) tracks the target; at animation start (tap 4) it snaps directly to avoid a slow first cycle.

### Animation Start

Activates on the 4th tap. Phase resets to 0 (= tap moment). `_display_rhythm_ms` snaps (not lerps) to the current estimate.

### Breath Cycle (`_compute_breath_value`)

Phase `p` ∈ [0, 1) where 0 = tap moment = start of hold-at-min:

| Segment | Range | Value |
|---------|-------|-------|
| Hold min | [0, p1] | 0 |
| Inhale | [p1, p2] | smoothstep 0→1 |
| Hold max | [p2, p3] | 1 |
| Exhale | [p3, 1] | smoothstep 1→0 |

`hold_frac = clamp(500ms / period, 0.04, 0.16)`  
`half_frac = (1 - hold_frac * 2) / 2`  
`p1 = hold_frac`, `p2 = p1 + half_frac`, `p3 = p2 + hold_frac`

### Circle Rendering (`tap_area.gd`)

```
r_min = 220 (mobile) or 150 (desktop)   # never changes
full_amp = 20 (mobile) or 12 (desktop)
amp = full_amp * _display_amp_factor     # lerped toward _amplitude_factor
r = r_min + amp * breath_value           # min fixed, max grows with amplitude
```

### Amplitude Ramp

`_amplitude_factor` is the target; `_display_amp_factor` lerps toward it at `delta * 1.5`.  
At tap n ≥ 4: `_amplitude_factor = min(1.0, 1/3 + (2/3) * (n-4) / 4)` → reaches 1.0 at tap 8.

### Progress Bar

Thin bar along the top edge: tracks `_elapsed_ms / _duration_ms`.

### Ring Feedback

On each tap: expanding ring centred on the breathing circle (not tap position). Age 0→1 over ~0.56s (`_ring_age += delta * 1.8`). Outer radius expands 50→220px (mobile) or 30→130px (desktop).

### Mobile Contrast

On mobile the foreground elements are drawn with markedly higher alpha and thicker strokes than desktop (the desktop values are tuned faint for a calm look but wash out on a bright phone screen). This affects the breathing circle fill/arcs (`tap_area.gd`), the tap ripple, the progress bar, the overlay labels (color overrides in `level.gd`'s `mobile_b` block), and the results graph grid/labels/tap lines (`graph.gd`). Desktop values are unchanged — all boosts are gated on `MainGlobals.is_mobile()`.

---

## Analysis Algorithm

All analysis is done in `_compute_stats()` after the session ends.

### Inter-tap intervals
`intervals[i] = tap_times[i+1] - tap_times[i]` for `i = 0..n-2`  
Minimum 2 taps required for any analysis.

### Outlier removal
Outlier threshold = median × 1.75. The clean set is used for mean/stddev. If fewer than 2 clean intervals remain, the raw set is used instead.

### Metrics
| Metric | Formula |
|--------|---------|
| Mean interval | `sum(clean_intervals) / count` |
| Stddev (σ) | `sqrt(mean((x - mean)²))` — population stddev |
| BPM | `60000 / mean_ms` |
| Missed breaths | `max(0, round(duration_ms / mean_ms) - tap_count)` |
| Consistency | `max(0, 100 - round(stddev_ms / 10))` |

---

## Tap Timeline Chart (`graph.gd`)

Shows all taps as vertical lines (a "comb" chart):
- X axis: time 0 → session duration
- Y axis: 0 (bottom) to 1.05 (top) — tap lines reach y=1 (fully visible within border)
- Each tap = a vertical line from bottom to the y=1 level
- Time grid lines at every 10s (or 20s/30s for longer sessions); never at t=0
- Border drawn last so it covers line edges
- X-axis label "time" below tick labels

Colors: `tap_col = Color(0.5, 0.9, 1.0, 0.85)`, `BORDER_COLOR = Color(1.0, 0.898, 0.0078)` (yellow).

---

## Score Row Format

`save_score()` prepends `[unixtime, score, time_left_sec, times_run]` to the passed array.

| Index | Field |
|-------|-------|
| 0 | Unix timestamp |
| 1 | Consistency score 0–100 (higher = better) |
| 2 | 0 (not meaningful) |
| 3 | session count |
| 4 | didwin (always true for completed sessions) |
| 5 | wasaborted (false for completed) |
| 6 | session duration in minutes |
| 7 | mean interval in ms |
| 8 | breaths per minute (float) |
| 9 | number of taps |
| 10 | estimated missed breaths |

---

## Stats Screen

- **Main score column:** consistency 0–100 (higher = better)
- **Extra columns via `scores_callback`:** Duration (min), BPM, Mean interval (s)

---

## Visual Design

| Element | Color | Notes |
|---------|-------|-------|
| Background | `Color(0.07, 0.1, 0.18)` | Deep dark navy |
| Timer | `Color(0.88, 0.93, 1.0)` | Near-white blue |
| Breath count | `Color(0.45, 0.85, 0.95)` | Cyan |
| Hint text | `Color(0.55, 0.65, 0.78, 0.55)` | Dimmed blue-gray |
| Progress bar fill | `Color(0.4, 0.82, 0.92, 0.28)` | Cyan, semi-transparent |
| Breathing circle fill | `Color(0.3, 0.7, 0.85, ~0.04–0.08)` | Very faint blue |
| Breathing circle arc | `Color(0.4, 0.82, 0.92, ~0.10–0.22)` | Cyan, animated alpha |
| Ring animation | `Color(0.45, 0.85, 0.95)` | Cyan, fades out |
| Graph tap lines | `Color(0.5, 0.9, 1.0, 0.85)` | Cyan |
| Graph border | `Color(1.0, 0.898, 0.0078)` | Yellow |

---

## Sound Effects

None — the session is silent by design.

---

## Main Menu

One slider entry:
1. **Duration (min)** (1–15) — session length in minutes
