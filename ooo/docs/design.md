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

## Passing a level

Finishing a level's rounds is not the same as passing it. `Level.level_is_done()` measures the accuracy of
the level just played — `game.session_pct_correct()` over that level's own `corrects`/`mistakes` —
against a bar that rises with the level:

```
need = mini(60 + 5 * (level - 1), 80)
```

Below it the SAME level comes round again; at or above it, the next one. The gate's result is
`game.need_to_increase_level`, which `new_game()` feeds to `increase_difficulty(game.need_to_increase_level)`.

Before this, `need_to_increase_level` was set to `true` unconditionally — finishing the rounds WAS
passing, so a player could get every single answer wrong and still be moved up, which made the
accuracy on the summary card decorative.

The bar is stated to the player as "at least NN%", so the test is `>=`. The last level
(`max_difficulty`) is exempt: there is nothing to be promoted to, so it ends as it always did.

## "complete!" only when it was

This game can now END a level without PASSING it, so `show_level_done_popup` is called with the
gate result as its `passed` argument. The card reads "Level N complete!" with a check badge on the
success color, or **"Level N not passed"** with no badge on the warning color — a tick over "you
need at least NN% accuracy" is the card congratulating the player for failing.

The card also says what happens next in words, because a percentage on its own does not tell the
player the one thing they want to know:

- passed → `Level passed — on to level N.`
- failed → `You need at least NN% accuracy to pass to the next level.`

`MainGlobals.global_level_is_done()` is given the same result, so the level-done fanfare no longer
plays over a level that was not passed.

## A replay starts clean

Failing the gate brings the same level round again, and that has to be a fresh attempt.
`new_game()` clears `game.corrects`, `game.mistakes` and `times_to_answer` on **every** level start, not
just `if from_scratch`.

The counters matter twice over. The visible half is the HUD still showing the failed attempt's
tally. The half that decides the game is that the GATE reads them — a replay which inherited the
misses that failed the level could not pass it even played perfectly. `times_to_answer` was never cleared at all — a rolling window of the last 10 answers that spanned levels — so the card's "Average time" row and the saved score row described a mixture of the level just played and the one before it.

`score` deliberately does NOT reset here — it accumulates across a session, and only
`game.reset(true)` clears it.

The HUD repaint is already covered: `main.gd`'s `new_game()` calls `hud.update_all()` immediately
after `$Level.new_game()`. (polkadots is the game where that was missing, which is why the shared
note about repainting next to the clearing exists.)

## A failed level earns nothing

`_score_at_level_start` is stamped at the top of `new_game()` — after the rollback, so consecutive
failures all measure from the same point — and a level that misses the gate goes back to it.
Otherwise the gate is a scoring exploit: the score is cumulative across a session, so every failed
attempt banked its points and the retry cost nothing — fail forever, earn forever.

**When** it happens is split on purpose:

- The score ROW is written the moment the level ends (`main.gd` saves on `game.sig_level_is_done`),
  so the kept value is swapped in just for that emit and swapped straight back. Without it, failing
  the same level repeatedly would farm the score list. This is why the gate is computed at the TOP
  of `Level.level_is_done()`, before anything is emitted.
- The VISIBLE score keeps showing what the player played with while the summary card is up:
  watching the number drop out from under a summary you are still reading is alarming. The visible
  rollback lands in `new_game()`, behind `_rollback_score_on_next_level`, when Continue is pressed.

Only the failed level's points go back; everything earned in levels already passed is untouched.

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

## The background

This game has no world in it — a shape flashes and you answer — so there is no ground to draw. What
sits behind the board is `scripts/study_backdrop.gd`, shared with Witness (`ddooo`), Pinpoint (`didi`) and Glimpse (`pop`), the other three games
with nothing standing on anything. It used to show a lawn, for no reason at all.

```gdscript
StudyBackdrop.fit(self, get_node_or_null("TextureRect") as CanvasItem, game,
    StudyBackdrop.LINEUP, 32)
```

`_fit_ground_to_board()` is called at the end of `_ready()` and at the start of `create_board()`. `fit()` hides the tiled
`TextureRect` it replaces, attaches a control as the Level layer's first child so it draws behind
the board, sizes it to the board plus a four-tile margin merged with the full canvas, and populates
it — rebuilding only when that rect actually changed.

**It is deliberately featureless, and that is a gameplay constraint, not a shortcut.** The whole game is whether you can pick the shape you just saw out of a row of distractors, so
anything on the background is competing with the thing being measured.
So there is no vignette, no gradient with a direction to it, no pattern and no motion. The surface
is a deep base (`StudyBackdrop.LINEUP`, a low-chroma teal-green), a radially symmetric lift toward
the centre at 5% alpha, and a fine untiled dust of specks in two tones at 4-9% alpha — enough that
the screen reads as a matte surface rather than as a missing asset, and far too little to compete
with a coloured shape.

`probe_lawn.gd` checks this game with the other three: backdrop present and first in its layer,
populated before any board is built, covering board and canvas, the tiled ground retired only once
it has something in it, and the centre lift both small and direction-free.
