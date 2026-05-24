# RL Madness — Game Design

Train rapid dual-modality decision-making.

## Screen Layout

- Top bar: corrects / mistakes counter + timer (10 minutes)
- Below HUD: "Average time: X ms" label (font size 26), updates after each correct answer, resets each level
- Two boxes side by side, each with a rule label above it (fixed 2-line height, bottom-aligned; labels fade out after `rounds_before_hide` rounds using `modulate.a`, not `hide()`)
- Each round: two items appear inside ONE randomly-chosen box; the other box stays empty
- One item belongs to the left modality, one to the right modality
- Only the item whose modality matches the **active box** is judged; the other is a visual distractor
- Items appear diagonally in the active box, anchored to opposite quadrants; non-stroop items align toward center, stroop items use full container width so single-line text never escapes the box
- All item labels and rule headers use Open Sans SemiBold (weight 600) via `SystemFont`, bypassing the project's custom QuantifierNbp font
- `RlmadnressG.use_uppercase` (default `true`) uppercases all item text and rule labels via `_u(text)`
- Bottom: **Wrong** and **Correct** buttons (also mapped to ← / → keyboard keys); pressing either darkens the button via `modulate`; ✓/✗ feedback label between buttons

## Core Mechanic

Each round:
1. Randomly pick `active_box` = LEFT or RIGHT
2. Generate `relevant_item` for that box's modality (50% chance satisfies rule, 50% doesn't → determines ground_truth)
3. Generate `distractor_item` for the OTHER modality (random correct/wrong, not judged)
4. Show both items diagonally in the active box, other box stays empty; `clip_contents = true` on both containers
5. Player presses Correct or Wrong (or ← / →)
6. Compare to ground_truth → score/feedback → next round

After `rounds_before_hide` rounds, the rule labels fade out and the player must remember both rules.

## Level Definitions (`level_defs.gd` — autoload `RlmLevelDefs`)

Each level has: id, name, left modality key, right modality key, rounds_before_hide, num_rounds.

| ID | Name | Left | Right | Hide after | Rounds |
|----|------|------|-------|------------|--------|
| 1 | Green  | digit    | square      | 6 | 10 |
| 2 | Blue   | even_odd | vowel       | 5 | 12 |
| 3 | Red    | prime    | convex      | 4 | 12 |
| 4 | Cyan   | stroop   | color_shape | 3 | 15 |
| 5 | Orange | lines    | even_odd    | 2 | 15 |

## Modality Keys

| Key | Label | Notes |
|-----|-------|-------|
| `digit` | "Is it a digit?" | Single digits 0–9 vs letters |
| `square` | "Is it a square?" | ■ vs ●▲★◆ |
| `even_odd` | "Is it even?" or "Is it odd?" | Randomly chosen per level; gen inverts ok flag for odd |
| `vowel` | "Is it a vowel?" | AEIOU vs consonants |
| `prime` | "Is it prime?" | Primes ≤ 23 only |
| `convex` | "Is it convex?" | ■●▲◆⬡ vs ★✦✿ |
| `stroop` | "Color = text color?" | Word + color; font size 38; full-width anchor; outer_corner meta |
| `color_shape` | "Shape is blue or red?" | Shape shown in various colors |
| `lines` | "Letter is only straight lines?" | A E F H I K L M N T V W X Y Z |

## Level Order and Progression

**No fixed difficulty progression.** Levels play in a defined order (`LEVEL_PROGRESSION_ORDER = [1,2,1,2,3,4,5,3,4,5]`) that can repeat.

- Player selects a starting level by name in the main menu (dropdown).
- `globals.gd` manages `level_queue`. On new game, queue is initialized from `LEVEL_PROGRESSION_ORDER` starting at `starting_level_id`.
- After completing a level: if accuracy < 70%, that level is inserted back into the queue after the next scheduled level.
- Queue refills from `LEVEL_PROGRESSION_ORDER` when exhausted. Game ends only when the 10-minute timer runs out.

## Sound Effects

- Correct answer: `res://art/sounds/FreeSFX/GameSFX/PickUp/Retro PickUp Coin 07.ogg`
- Wrong answer: `res://art/sounds/swoosh.mp3`

---

## Scoring

- **Correct answer**: +10 base + speed bonus (up to +20 for very fast responses)
- **Wrong answer**: −3 (floored at 0 total score)
- Response time is only recorded for **correct** answers; `times_to_answer` resets each level (capped at last 20)
- Scores table columns: Date | Score | Level name | Avg Time
- Speed table (progress view) columns: Date | Avg Time | % Correct; grouped by level name

## Score row layout (saved array)

| Index | Field |
|-------|-------|
| 0 | unixtime |
| 1 | score |
| 2 | time_left_sec |
| 3 | times_run |
| 4 | didwin |
| 5 | wasaborted |
| 6 | current_level_id (POS_SCORE_LEVEL_ID) |
| 7 | mean_response_time_ms (POS_SCORE_MEAN_TIME_MS) |
| 8 | pct_correct (POS_SCORE_PCT_CORRECT) |

## Shared system changes (scores_list.gd / generic_game_util.gd)

- **Monotonic mode (scores table)**: iterates stored scores oldest→newest; includes a row only when its score exceeds all previously included scores; result displayed newest/highest on top.
- **Monotonic mode (speed table)**: same logic but criteria is avg time < previous best (smaller = better).
- **Font size in scores table**: reduced font (size 22) applied to date + level columns only for games that set `game.show_scores_level_as_name = true` in their `_ready()`. This flag is set by rlmadness (level names like "Green", "Blue") but not by games with numeric level columns (e.g. ddooo). All rows in the same list use the same font size regardless of individual name length.
- **% Correct column**: added to speed table when `progress_pct_pos >= 0`.
- **Default label text**: `grid_date_label.tscn` has a placeholder text "123" in its Label node. `scores_list.gd` explicitly clears the level label (`level_label.text = ""`) for rows where no level/pct text is provided, preventing the placeholder from showing.
- **Chart tab**: third tab in the stats screen (visible for all games). Custom line+dot chart via `scripts/chart_control.gd` using Godot's `_draw()` API. Three metrics via a segmented pill control (amber = active) below the chart. X-axis: `#` (game index, default) or `D` (date), toggled by a `D/#` switch (dark capsule, orange dot) to the right of the pills; mode persisted per game in `MainGlobals.chart_x_mode_by_game`. Empty chart shows a stub grid with "No data yet" and metric-appropriate Y range. Tab bar matches the bottom pill bar in style (dark panel `Color(0.14,0.14,0.17)` with top-rounded outer corners `r=14`, active tab amber fill `r=12`, inactive transparent; 38px side margins). Tab preference ("scores"/"speed"/"chart") persisted in `MainGlobals.progress_tab_by_game`; backward-compatible with old bool values.
- **score_was_changed flag** (`GenericGameUtil`): both `save_ongoing_score` and `save_score` are skipped when `score == initial_score` throughout the session. Set to `true` by `add_score_and_time` when `score != initial_score`; reset to `false` by `reset(from_scratch=true)`.

## Files

```
rlmadness/
├── docs/design.md
├── scripts/
│   ├── globals.gd      (RlmadnressG autoload; 10-min timer; level queue; use_uppercase flag)
│   ├── level_defs.gd   (RlmLevelDefs autoload; LEVELS const, LEVEL_PROGRESSION_ORDER, helper funcs)
│   ├── main.gd         (orchestrator, corrects/mistakes HUD, dropdown starting level)
│   └── level.gd        (modality building, round loop, diagonal placement, scoring)
└── scenes/
    ├── main.tscn
    └── level.tscn
```
