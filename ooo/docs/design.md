# OOO — Game Design & Implementation Document

## Overview

**Game name:** OOO
**Folder:** `ooo/`
**Singleton:** `OooG`
**Save key (short name):** `ooo`
**Initial time:** 2 minutes
**Background color:** `0x3C5D3EFF` (dark green)
**Initial score:** 100, `game_over_on_zero_score = true`

OOO is a visual memory speed game. The player briefly sees one image, then after a short delay must pick the matching image from a set of distractors as quickly as possible.

---

## File Structure

```
ooo/
├── docs/
│   └── design.md           ← this file
├── art/
├── scripts/
│   ├── globals.gd            (OooG autoload)
│   ├── main.gd
│   └── level.gd
└── scenes/
    ├── main.tscn
    └── level.tscn
```

---

## Globals (`OooG`)

| Variable | Default | Description |
|----------|---------|-------------|
| `starting_difficulty` | 1 | Initial difficulty level |

Settings saved as `[starting_difficulty]`.

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

`ooo/scripts/tutorial.gd` (8 steps), entry `ooo/scripts/main.gd::start_tutorial()`, level 1.

What a first-timer gets wrong:

- **They do not realize the first shape is the question.** It appears alone for about a second and
  vanishes; someone still working out what they are looking at has already missed it, and the
  lineup that follows means nothing.
- **They look for the wrong kind of match.** At level 1 every candidate is the same SHAPE and only
  the color differs; later levels invert that. So "the one you saw" has to be taken literally on
  both axes.
- **They take their time.** Score starts at 100 and only falls; a fast correct pick is worth more.

Specific to this game:

- **No freeze work is needed.** Agent timeouts are measured in `game.game_time` (see `agent.gd`),
  which excludes paused time, so a caption holds the model and later the lineup on screen. Verified
  rather than assumed — the harness has a freeze check that would catch a regression.
- The "tap the match" caption is **reactive**: a wrong pick clears the board and starts a fresh
  round, which is baffling in silence.
- `_tutorial_board` guards level completion, not `tutorial_mode`.
- Events: `model_shown`, `candidate_shown`, `lineup_shown`, `answered_right`, `answered_wrong`.
- Points for the coach: `tutorial_model_pos`, `tutorial_lineup_rect`, `tutorial_correct_pos`.
