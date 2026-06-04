# Typit (typit) — Design Document

## Overview

A mobile-first typing trainer that uses a fully custom on-screen keyboard. Every keypress is recorded with its exact touch position, enabling detailed analysis of accuracy, speed, and systematic finger positioning errors.

## File Structure

```
typit/
├── art/
│   └── game_screen_200.png         — thumbnail
├── docs/
│   └── design.md                   — this file
├── scenes/
│   ├── main.tscn                   — Node with Main script, Level, Help
│   └── level.tscn                  — CanvasLayer with TypeCanvas, SessionOverlay, ResultsPanel
└── scripts/
    ├── globals.gd                  — autoload TypitG; owns GenericGameUtil "typit"
    ├── main.gd                     — menu flow, settings, transitions
    ├── level.gd                    — all game logic, keyboard, drawing, analysis
    └── typit_canvas.gd             — thin Control that delegates _draw → level._do_draw()
```

## Autoload & Registration

- `project.godot`: `TypitG="*res://typit/scripts/globals.gd"`
- `scripts/config.gd`: `["typit", "Typit", "...", "Reflexes"]`

## Gameplay

1. Session starts with a shuffled sequence of typing passages.
2. Player taps keys on the custom on-screen keyboard character by character.
3. **Correct keypress** → character turns green, cursor advances, score += level.
4. **Wrong keypress** → mistake recorded, pressed key flashes red, cursor still advances (no blocking).
5. **Backspace** → cursor retreats one position, last correctness entry removed.
6. When a passage is fully typed, next passage loads automatically.
7. Session ends when the timer reaches 0 OR the player presses **Done** (on keyboard).
8. The "Done" button is explicit — no auto-end on passage completion — because the player may want to backspace.

## Settings (globals.gd)

| Field | Default | Description |
|---|---|---|
| `selected_level` | 1 | 1=62px keys (easy) … 5=28px keys (hard) |
| `duration_min` | 1 | Session duration in minutes |
| `show_instructions` | true | Show instructions on first launch |

Settings saved via `game.save_settings([level, duration_min, show_instructions])`.

## Levels

Higher level = smaller keys = harder hit-testing.

| Level | key_w | key_h |
|---|---|---|
| 1 | 62 | 58 |
| 2 | 52 | 48 |
| 3 | 44 | 40 |
| 4 | 36 | 32 |
| 5 | 28 | 24 |

## Keyboard Layout

### Alpha layer (default)

```
Q W E R T Y U I O P        (row 0, no stagger)
 A S D F G H J K L         (row 1, +0.5 key stagger right)
  ⬆ Z X C V B N M ⌫        (row 2, shift + 7 letters + backspace)
  [123]  [   space   ] [Done]  (row 3)
```

Row stagger matches standard QWERTY: row 1 is +0.5 key-units right of row 0; row 2 starts from screen edge with shift key.

### Number/symbol layer (toggled by [123])

```
1 2 3 4 5 6 7 8 9 0
- / : ; ( ) $ & @ "
[#+=] . , ? ! '  [⌫]
[ABC]  [   space   ] [Done]
```

### Key data structure (Dictionary)

Each key is a Dictionary with these fields — designed to be changed per level or language:

```gdscript
{
  "label":       String,   # display text (e.g. "A", "⌫", "Done")
  "action":      String,   # character inserted or keyword ("backspace", "done", "num_toggle", " ")
  "key_type":    String,   # "char" | "space" | "backspace" | "done" | "num_toggle" | "alpha_toggle" | "shift"
  "cx":          float,    # center x in screen coords
  "cy":          float,    # center y in screen coords
  "w":           float,    # visual width
  "h":           float,    # visual height
  "hit_w":       float,    # hit-test width (= w + gap for seamless tiling)
  "hit_h":       float,    # hit-test height (= h + gap)
  "color":       Color,    # key background
  "label_color": Color,    # label text color
  "font_size":   int,      # label font size (scales with key_h)
}
```

To add a language: build an alternative keyboard array using the same structure and toggle via a language flag in globals.gd.

## Measurements

All recorded per session:

### a. Mistakes per character
`_mistakes: int` — incremented every time the player taps a key that doesn't match the expected character at the current position. Backspaces are counted separately in `_backspaces`.

### b. Distance from expected key center (capsule metric)
For each keypress, the expected character's key is looked up. A horizontal spine runs from `(cx - w/2 + kh/2, cy)` to `(cx + w/2 - kh/2, cy)` — i.e., it starts and ends at a distance of `kh/2` from each horizontal edge. For square or narrow keys the spine collapses to a point. The **capsule distance** is the Euclidean distance from the touch point to the nearest point on this spine. This rewards touching anywhere within the key's vertical band equally.

Raw `(dx, dy)` offsets from key center are also stored in `_key_hits` for bias analysis.

Measured for every keypress (correct or wrong) — always relative to the EXPECTED key, not the one actually pressed.

### c. RMS of distances
`rms = sqrt(mean(capsule_dist²))` over all keypresses after outlier filtering.

Heat map color: `t = capsule_dist / (kh/2)`, clamped [0,1] → green (t=0, on spine) to red (t≥1, outside key boundary).

### d. Speed
`speed_cpm = correct_chars / (effective_time_minutes)` where `effective_time_ms = sum of non-outlier inter-key intervals`.

### e. Actual position (x,y) per key
`_key_hits: Dictionary` maps each expected character to `Array[Vector2]` of (dx, dy) offsets. This is the raw data for the heat map.

## Outlier Detection (`_filter_outliers`)

Uses IQR method:
- Sort values
- Compute Q1, Q3, IQR = Q3 − Q1
- Remove values > Q3 + 3×IQR

Applied to:
- Inter-key times (to remove pauses/distractions from speed calculation)
- Per-keypress distances (to remove accidental far taps from RMS)

The factor 3.0 (`OUTLIER_IQR_FACTOR`) and minimum key interval 40ms (`MIN_INTER_KEY_MS`) are easy to tune.

## Systematic Bias Analysis (`_compute_key_bias`)

For each expected key with ≥ 3 samples:
- Compute `mean_dx = mean of all dx` and `mean_dy = mean of all dy`
- If `|mean_dx| > BIAS_THRESHOLD × key_w/2` → flag "left" or "right"
- If `|mean_dy| > BIAS_THRESHOLD × key_h/2` → flag "up" or "down"

`BIAS_THRESHOLD = 0.22` (22% of half key width). Easy to change.

Results shown in analysis screen as: `[A] tends left (-12, 3)px, n=7`.

To change the bias logic (e.g. use median instead of mean, or add more sophisticated clustering), replace only the `_compute_key_bias()` function in `level.gd`.

## Heat Map

Displayed in the post-session analysis panel as a scaled keyboard.

Each key is colored:
- **No data**: dark gray
- **Green** (avg_dist ≈ 0): tapped accurately near center
- **Red** (avg_dist ≥ key_diagonal/2): tapped far from expected center
- Color: `Color(0.15 + 0.85*t, 0.80 - 0.75*t, 0.15)` where `t ∈ [0,1]`

Hit count shown in small text inside each key.

## Over-Session Graphs

Read from `game.read_scores()`. Filter by current level. Extract speed_cpm (index 8, ×0.1) and RMS (index 9, ×0.1). Plot as polyline graphs in the results panel.

## Score Array Format

`[unixtime, score, time_left_sec, times_run, level, correct_chars, total_keypresses, mistakes, speed_cpm_x10, rms_x10]`

Indices 0–3 are standard GenericGameUtil fields. Indices 4–9 are typit-specific extra data.

## Signals

| Signal | Emitted by | Handled by |
|---|---|---|
| `sig_session_done` | level.gd `_finish_session()` | main.gd: converts ongoing score to permanent |
| `sig_show_main_menu` | level.gd Done/Menu button | main.gd: shows main menu |

## Touch Input Notes

- Uses `InputEventScreenTouch` (mobile) and `InputEventMouseButton` left click (desktop).
- Touch position is in viewport (680×748) space — matches CanvasLayer coordinates directly.
- Hit areas (`hit_w = key_w + gap`, `hit_h = key_h + gap`) tile seamlessly so every tap in the keyboard area hits exactly one key.
- The keyboard area starts at `_kb_top_y() = screen_h - 4*key_h - 3*gap - 6px` from the top.

## Language Extensibility

To add a new language keyboard:
1. Add a language flag (e.g. `selected_lang: int`) to `globals.gd`.
2. Create `_build_{lang}_keyboard() -> Array` in `level.gd` following the same key dict structure.
3. In `new_game()`, select the appropriate build function based on the flag.
4. The measurement, hit-test, heat map, and bias code are language-agnostic.

## Pitfalls & Notes

- **No `:=`** anywhere — always use explicit `var x: Type = value`.
- `_key_hits` is keyed by the **expected** character, not the pressed character. This is intentional: the heat map shows accuracy relative to target, not where users think they're pressing.
- The text display uses per-character `draw_string()` calls for color coding — avoid very long passages (>200 chars) to keep frame time reasonable.
- `_finish_session()` guards against double-call with `_session_complete` flag.
- Score is only saved if `_correct_chars > 0` (prevents empty sessions from polluting stats).
