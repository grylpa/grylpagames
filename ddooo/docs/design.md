# DDOOO — Game Design & Implementation Document

## Overview

**Game name:** DDOOO
**Folder:** `ddooo/`
**Singleton:** `DdoooG` (autoload)
**Level defs singleton:** `DdoooLevelConfig` (autoload)
**Save key (short name):** `ddooo`
**Initial time:** 2 minutes
**Background color:** `0x3C5D3EFF` (dark green)

DDOOO is a dual-decision memory game. Every round the player must correctly identify a briefly flashed **center shape** AND recall the **direction** of a peripheral dot that flashed simultaneously. Both must be correct to count as a pass toward level advancement.

---

## File Structure

```
ddooo/
├── docs/
│   └── design.md           ← this file
├── art/
│   ├── grass.png
│   ├── grass_dark.png
│   ├── pipe.png
│   ├── empty_corner.png
│   ├── shape-circle.png
│   ├── shape-circle-4.png
│   ├── shape-circle-swirl.png
│   ├── shape-circle-w-2-dots.png
│   ├── shape-circle-w-3-dots.png
│   ├── shape-circle-w-4-dots.png
│   └── shape-circle-w-5-dots.png
├── scripts/
│   ├── globals.gd
│   ├── level_config.gd
│   ├── main.gd
│   ├── level.gd
│   ├── agent.gd
│   ├── pipe.gd
│   └── half_color.gdshader
└── scenes/
    ├── main.tscn
    ├── level.tscn
    ├── agent.tscn
    └── pipe.tscn
```

---

## Registration

### `project.godot` autoloads
```
DdoooG="*res://ddooo/scripts/globals.gd"
DdoooLevelConfig="*res://ddooo/scripts/level_config.gd"
```

### `scripts/config.gd`
```gdscript
["ddooo", "DDOOO", "Find the center shape AND remember the direction of the peripheral flash"],
```

---

## Scene Structure

### `scenes/main.tscn`
Root node `Main` (Node, `main.gd`). Children:
- `Level` — instance of `level.tscn` (CanvasLayer)
- `HUD` — instance of `res://scenes/generic_game_hud.tscn`
- `GameTick` — Timer, wait=0.05s, autostart
- `Help` — instance of `res://scenes/help.tscn`, hidden
- `PeriQLayer` — CanvasLayer, layer=5
  - `PeriQLabel` — Label (unique_name_in_owner), hidden by default.
    Visible during the direction-question phase, toggled via `sig_periph_active`.

### `scenes/level.tscn`
Root node `Level` (CanvasLayer, `level.gd`). One `TextureRect` for the grass background. All agents, pipes, and direction buttons are instantiated dynamically.

---

## Gameplay Design

### Board
7×7 grid. `game.forced_board_size = Vector2i(7,7)`. Camera zoomed via `create_camera(min(6.0, 1/get_board_part_of_width()))` anchored at board center.

### Round Structure

Each round has three phases:

**Phase 1 — Model flash**
A shape (the "model") appears at board center `(3,3)` for `center_ms`. Simultaneously, a peripheral dot is scheduled to flash 150 ms later.

**Phase 2 — Peripheral flash**
A small scaled agent (scale *= 0.55, single-color) appears at a random distance of 0.8–1.0 lerp from board center toward one of 8 edge positions. It auto-hides after `periph_ms`. The direction index (0–7) is saved as `periph_dir_idx`.

Direction positions (board coords, 7×7 grid):
| Index | Direction | Board pos |
|-------|-----------|-----------|
| 0 | Up | (3,0) |
| 1 | Down | (3,6) |
| 2 | Left | (0,3) |
| 3 | Right | (6,3) |
| 4 | Top-left | (0,0) |
| 5 | Top-right | (6,0) |
| 6 | Bottom-left | (0,6) |
| 7 | Bottom-right | (6,6) |

**Phase 3 — Alternatives + direction buttons**
After the model disappears, `num_alts` alternative shapes appear on row 3. One is the correct match (same color + shape), others are distractors.

Pipe positions by `num_alts`:
- 2 alts: (2,3) and (4,3)
- 3 alts: (1,3), (3,3), and (5,3) — spacing 2 tiles to prevent overlap

When the player taps an alternative, all alternatives are cleared. If the model answer was correct (`pending_main_correct = true`), direction buttons appear for the periph question:
- 8 small Area2D nodes (yellow circle dots), each placed at `center.lerp(edge_pos, 0.7)`
- Tap target: CircleShape2D radius = tile_size × 0.5
- Visual: Polygon2D yellow circle, radius = tile_size × 0.35

If the player answers the main question wrong, `pending_main_correct = false`; direction buttons still appear so the round finishes cleanly.

### Round Completion Rule

A round counts as a **pass** (`num_corrects_in_level_so_far++`) only when:
1. The player tapped the **correct** center alternative
2. **AND** tapped the **correct** direction button

`pending_main_correct` tracks whether the main answer was correct. Scoring:
- Both correct → level counter increments; +score per correct answer
- Either wrong → no level progress; −score per wrong

### Color and Shape Rules for Alternatives

Controlled per level by `same_color_alts`:

- **`same_color_alts: false`** (levels 1–4): wrong alternatives get a **different** color from the model; the correct alternative matches both color and shape of the model. The player can use color to narrow choices.

- **`same_color_alts: true`** (levels 5–8): **all** alternatives (correct and wrong) share the **same colors** as the model. The only distinguishing cue is shape. Wrong alternatives are guaranteed a different shape from the model via `set_rand_texture(model_texture_idx)` which cycles the sequential texture counter past the model's index.

---

## Level Definitions (`DdoooLevelConfig`)

Defined in `ddooo/scripts/level_config.gd`, autoloaded as `DdoooLevelConfig`.

| id | center_ms | periph_ms | num_alts | two_colors | same_color_alts | rounds |
|----|-----------|-----------|----------|------------|-----------------|--------|
| 1 | 700 | 200 | 2 | false | false | 5 |
| 2 | 600 | 150 | 2 | false | false | 6 |
| 3 | 500 | 150 | 2 | false | true | 6 |
| 4 | 400 | 100 | 2 | false | true | 8 |
| 5 | 300 | 100 | 2 | true | true | 8 |
| 6 | 250 | 50 | 2 | true | true | 10 |
| 7 | 200 | 30 | 3 | true | true | 10 |
| 8 | 150 | 20 | 3 | true | true | 999 |

- `center_ms`: how long the model shape is visible before auto-hiding
- `periph_ms`: how long the peripheral dot is visible
- `num_alts`: number of shape alternatives displayed
- `two_colors`: whether the center item may display two colors (split shader)
- `same_color_alts`: all alternatives share model's colors; player must identify by shape
- `rounds`: correct rounds (both tasks) needed to advance

**Last-level loop (level 8):** When the player completes 999 passes at level 8, the score is saved silently and the level restarts at difficulty 8 — no popup, no difficulty increase. The `times_to_answer` rolling window (last 10) persists across loops so each saved score reflects a running average over recent rounds.

Helper functions: `get_level(id)`, `level_names()`, `id_to_index(id)`, `level_header(id)` → `"L1: Ctr 700ms / Per 200ms"`.

---

## Sound Effects

- Dispatch (model appears): `res://art/sounds/kenney/Audio/impactBell_heavy_003.ogg`
- Delivery (main or periph correct): `res://art/sounds/FreeSFX/GameSFX/PickUp/Retro PickUp Coin 07.ogg`
- Swoosh (wrong answer — main miss, periph wrong, model timed-out-as-correct): `res://art/sounds/swoosh.mp3`
- Ambient ocean: `res://art/sounds/ocean-waves-1.mp3` (looping background)

---

## Scoring

- Main correct (speed-weighted): `+max(1, 10 - elapsed_ms/200)` score, `+15s` time
- Main wrong: `−1` score, `−5s` time; `game.add_correct_or_mistake(0, 1)`
- Periph correct: `+5` score, `+10s` time
- Periph wrong/timeout: `−1` score, `−5s` time
- `game.game_over_on_zero_score = true`

### Score row format

| Index | Field |
|-------|-------|
| 0 | unixtime |
| 1 | score |
| 2 | time_left_sec |
| 3 | times_run |
| 4 | didwin |
| 5 | wasaborted |
| 6 | last_level (POS_SCORE_DIFFICULTY = 6) |
| 7 | mean_response_time_ms (POS_SCORE_MEAN_TIME_MS = 7) |
| 8 | pct_correct (POS_SCORE_PCT_CORRECT = 8) |

`pct_correct = int(100 * game.corrects / (game.corrects + game.mistakes))` across the full session.

### Scores display

- **Scores tab**: columns Date | Score | Level (shows level number, e.g. "3")
- **Speed tab**: columns Date | Avg Time | % Correct; entries grouped by level with section headers (`level_header(id)` string)
- **Chart tab**: line+dot chart via `scripts/chart_control.gd` (Godot `_draw()` API). Three metrics via segmented pill control (amber = active) below the chart. X-axis: `#` (index, default) or `D` (date) toggled by `D/#` switch; persisted per game. Empty chart shows stub grid + "No data yet". Tab bar mirrors the bottom pill bar: dark panel `Color(0.14,0.14,0.17)` with top-rounded outer corners `r=14`, active tab amber `r=12`, inactive transparent; 38px side margins. Tab preference persisted in `MainGlobals.progress_tab_by_game`.
- **score_was_changed** (`GenericGameUtil`): scores are only saved to disk if `score != initial_score` was ever true during the session. Prevents spurious saves at the initial score value.
- `show_scores_level_as_name = false` → level column uses default font size (no shrink)

---

## Level Popup

At the start of each level (including after level completion), a popup shows:
```
Level N
Center visible: X ms
Periphery flash: Y ms
```
Game begins only when the player dismisses the popup (`sig_game_popup_closed` → `_on_game_popup_closed` → sets `game.level_is_ready = true`).

---

## Main Menu

- **Starting level** dropdown (option id=1): lets player choose which level to begin on.
- Populated via `DdoooLevelConfig.level_names()`.
- Persisted via `DdoooG.starting_difficulty` in settings.

---

## Visual Feedback

**Color flash overlay** (`_flash_at`): semi-transparent `ColorRect` (alpha 0.55), green/red, fades over 0.35s.

**Floating score popup** (`_show_score_popup`): label drifts upward and fades over 0.65s.

---

## Key Signals

| Signal | Direction | Purpose |
|--------|-----------|---------|
| `Level.sig_periph_active(bool)` | level → main | show/hide PeriQLabel |
| `Level.sig_level_is_done(bool)` | level → main | new level or game over |
| `Level.started_playing` | level → main | restart HUD timer |
| `game.sig_game_is_done` | GenericGameUtil → main | game over |
| `game.sig_level_is_done` | GenericGameUtil → main | save ongoing score |

## Tutorial

`ddooo/scripts/tutorial.gd` (12 steps), entry `ddooo/scripts/main.gd::start_tutorial()`, level 1.

One event, two questions — and the second one is the thing a first-timer never sees coming. While
they are looking at the center shape, a dot flashes at the edge 150ms later and is gone in under a
second. Nothing warns them, and then they are asked which way it was. So the coach **names the
second question while the flash is still on screen**, and says which direction it was, so the first
round is winnable rather than a demonstration of failure.

Specific to this game:

- **`tutorial_periph_dir_name()` puts the direction in words** ("top-left"), so a caption can say
  it instead of leaving the player to interpret an index.
- **No freeze work is needed.** Every timeout here — the agents', the peripheral flash, and the
  direction question's limit in `_process` — is measured in `game.game_time`, which excludes paused
  time. The harness checks both the agent count and the flash's survival across a caption.
- **The direction step is descriptive; the ask is on the step after it.** A talking step freezes
  the board, so an instruction there cannot be obeyed and the attempt just dismisses the caption.
- **Both answers must be given correctly.** The steps wait on `shape_right` and `dir_right`, not on
  "an answer happened" — waiting on the latter let a player finish the tutorial without ever
  getting either question right. But a wrong answer must not strand them either: a wrong shape
  still lets the round play out, and a wrong dot ends the direction question and clears every
  button. So both captions are **reactive** and walk the player through the fresh round that
  follows, and the freeze follows the BOARD STATE rather than the step — held while there is
  something to answer, released whenever the board is empty, or the next round could never arrive.
- `_tutorial_board` guards level completion, not `tutorial_mode`.
- Events: `model_shown`, `periph_flashed`, `alts_shown`, `shape_right`, `shape_wrong`,
  `dirs_shown`, `dir_right`, `dir_wrong`.
- Points for the coach: `tutorial_model_pos`, `tutorial_periph_pos`, `tutorial_candidates_rect`,
  `tutorial_correct_dir_pos`.
