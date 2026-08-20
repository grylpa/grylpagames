# Pop — Game Design & Implementation Document

## Overview

**Game name:** Pop
**Folder:** `pop/`
**Singleton:** `PopG`
**Save key (short name):** `pop`
**Initial time:** 2 minutes
**Background color:** `0x3C5D3EFF` (dark green)
**Initial score:** 100, `game_over_on_zero_score = true`

Pop is a visual memory speed game. The player briefly sees an image at one location on the board, then after a delay must select the matching image from several shown at different locations.

---

## File Structure

```
pop/
├── docs/
│   └── design.md           ← this file
├── art/
├── scripts/
│   ├── globals.gd            (PopG autoload)
│   ├── main.gd
│   └── level.gd
└── scenes/
    ├── main.tscn
    └── level.tscn
```

---

## Globals (`PopG`)

| Variable | Default | Description |
|----------|---------|-------------|
| `starting_difficulty` | 1 | Initial difficulty level |

Settings saved as `[starting_difficulty]`. Board size forced to 11×11.

---

## Scoring

- `initial_score = 100`, `game_over_on_zero_score = true`
- Score changes via `game.add_score_and_time()` during gameplay
- `score_was_changed` flag in `GenericGameUtil`: scores are only saved if the score ever diverged from 100

**Last-level loop:** At max difficulty (level 8), completing the required rounds saves the score silently and immediately restarts at the same level — no popup, no difficulty increase. The `times_to_answer` rolling window (last 10) is never cleared between loops so the saved avg response time reflects a running average over recent rounds.

## Score Row Format

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

## Stats Screen

- **Scores tab**: Date | Score | Level
- **Speed tab**: grouped by level, shows avg response time and % correct
- **Chart tab**: all three metrics (Score, Avg Time, % Correct); see shared system notes in `rlmadness/docs/design.md`

---

## Main Menu

Slider entry: `Difficulty` (1–9). Bottom bar includes help, mute, scores buttons.

---

## Shared System Notes

See `rlmadness/docs/design.md` → "Shared system changes" for details on:
- Chart tab design and x-axis toggle
- `score_was_changed` save gate
- Monotonic mode, % Correct column

## Tutorial

`pop/scripts/tutorial.gd` (7 steps), entry `pop/scripts/main.gd::start_tutorial()`, level 1.

Glimpse is Lineup played at the edge of vision, and the difference IS the lesson: in Lineup the
shape to remember always appears in the same place, so you can stare at it. Here it flashes at any
point around the rim, and `_dispatch_new_agent` then places the candidates more than four tiles
away. The mistake is watching one spot.

Specific to this game:

- **The candidate step carries no frame.** The rect enclosing candidates scattered around the rim
  measured 433x433px — most of the screen. A frame that size names nothing and leaves the caption
  nowhere to sit that is not on top of it, which the harness caught as "caption covers its own
  spotlight". The words carry that step instead, and the lineup is not in `keep_clear` either.
- **`tutorial_frame_radius()` accounts for the camera zoom** (`tile_size * zoom * 0.75`), because
  this game calls `create_camera()`; the board tile size is not the on-screen tile size.
- **No freeze work is needed** — timeouts run on `game.game_time`.
- `_tutorial_board` guards level completion, not `tutorial_mode`.
- Events: `model_shown`, `candidate_shown`, `lineup_shown`, `answered_right`, `answered_wrong`.
