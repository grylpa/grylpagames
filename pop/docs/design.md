# Glimpse (folder `pop`) — Game Design & Implementation Document

## Overview

**Game name:** Glimpse (folder and save key are still `pop`)
**Folder:** `pop/`
**Singleton:** `PopG`
**Save key (short name):** `pop`
**Initial time:** 2 minutes
**Background:** `StudyBackdrop.GLIMPSE` — see "The background" below. (It was `0x3C5D3EFF`,
dark green, when the ground was grass.)
**Initial score:** 100, `game_over_on_zero_score = true`

Glimpse is a visual memory speed game. The player briefly sees one shape at a position around the
edge of the screen, then after a delay must pick the matching shape from several that appear at other
edge positions. It is Lineup (`ooo`) played at the edge of vision, and that difference drives most of
the decisions below — see "There is no board".

---

## File Structure

```
pop/
├── docs/
│   └── design.md           ← this file
├── art/                      (nothing of its own: the box is res://art/box.png, shared with
│                              Lineup and Witness)
├── scripts/
│   ├── globals.gd            (PopG autoload)
│   ├── main.gd
│   ├── level.gd
│   ├── agent.gd
│   ├── level_config.gd
│   └── tutorial.gd
└── scenes/
    ├── main.tscn
    ├── level.tscn            the Level layer and nothing else — no ground, no board
    └── agent.tscn
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

## There is no board

A shape flashes at the edge of vision and you say which one it was. Nothing walks, nothing is
delivered, nothing is blocked — so there is nothing for a board to do, and this game no longer has
one.

What `create_board()` builds is only the RING of places a shape can appear: every other cell along
the four edges of the 11x11 grid, collected into `agent_start_positions` / `agent_start_directions`.
The `board` array itself survives as bookkeeping — one `OneCell` per grid square, holding whichever
`agent` and `box` is currently there — and nothing is drawn for a cell that has neither.

It used to build a maze: road pipes threaded between the shape positions (`add_pipe`, `pipe.tscn`,
four pipe PNGs) and every remaining cell floored with a walled grass tile (`add_empty`,
`empty_space.tscn`). None of it meant anything, and all of it sat directly under the thing the
player was straining to see. `pipe.gd`, `empty_space.gd`, both scenes, the four pipe PNGs and
`empty_corner.png` are gone, and so is the level scene's grass `TextureRect` — `level.tscn` is now
the `Level` CanvasLayer and nothing else.

### The box

A shape stands on one box: `res://art/box.png`, a plain `Sprite2D` created in code by
`_add_box_at()`. The image is shared with Lineup (`ooo`) and Witness (`ddooo`), which draw the same
56x56 plate under their candidate positions. All three carried a byte-identical private copy until
they were compared.
Lineup (`ooo`) is the near relative here and does it differently on purpose — Lineup frames every
candidate position for the whole round, so the player can see where the answers will be before they
arrive. Glimpse must not: it is played at the EDGE of vision, and a box sitting on an empty position
is a marker for a question that has not been asked yet, or one that is already over.

So the box's life is exactly the shape's life:

| | |
|---|---|
| created | `add_agent_at()`, **before** `add_child(agent)` — so the box is the older sibling and draws under the shape even without the `z_index` |
| `z_index` | 1: above the backdrop, below the shape's 10 (`agent.gd` sets that in its own `_ready`) |
| never | an `Area2D`. A tappable box would swallow the tap meant for the shape standing on it |
| destroyed | `on_agent_need_to_remove_agent()`, which every removal path funnels through — timeout, right answer and wrong answer alike |
| swept | at the top of `create_board()`, **before** `board.clear()`: a box is reached through its cell, so sweeping afterwards finds nothing and orphans every box on screen |

`probe_lawn.gd` drives the dispatch and removal directly and asserts the count matches the number of
shapes at each step — 1, then 3, then 0 — plus the box's position, `z_index`, untappability, and
that no cell or road pipe is built at all any more.

---

## The background

This game has no world in it — a shape flashes and you answer — so there is no ground to draw. What
sits behind the board is `scripts/study_backdrop.gd`, shared with Witness (`ddooo`), Pinpoint
(`didi`) and Lineup (`ooo`), the other three games with nothing standing on anything. It used to
show a lawn, for no reason at all.

```gdscript
StudyBackdrop.fit(self, get_node_or_null("TextureRect") as CanvasItem, game,
    StudyBackdrop.GLIMPSE, 31)
```

`_fit_ground_to_board()` is called at the end of `_ready()` and at the start of `create_board()`.
`fit()` attaches a control as the Level layer's first child so it draws behind everything, sizes it
to the board's extent plus a four-tile margin merged with the full canvas, and populates it —
rebuilding only when that rect actually changed. There is no `TextureRect` left for it to hide; the
`tiled_ground` argument is `get_node_or_null("TextureRect")` and comes back null, which `fit()`
allows.

**It is deliberately featureless, and that is a gameplay constraint, not a shortcut.** Glimpse is
Lineup played at the EDGE of vision: anything with structure out there competes with the very thing
the player is straining to catch. So there is no vignette, no gradient with a direction to it, no
pattern and no motion. The surface is a deep base (`StudyBackdrop.GLIMPSE`, a low-chroma plum), a
radially symmetric lift toward the centre at 5% alpha, and a fine untiled dust of specks in two
tones at 4-9% alpha — enough that the screen reads as a matte surface rather than as a missing
asset, and far too little to compete with a coloured shape.

`probe_lawn.gd` checks this game with the other three: backdrop present and first in its layer,
populated before any shape appears, covering the board's extent and the canvas, and the centre lift
both small and direction-free.

## What this game measures

Session records are the v6 named-dictionary format (see `scripts/generic_game_util.gd`
and `scripts/session_stats.gd`). Metrics reset centrally in `reset(from_scratch)`.

Response times are handed to the shared session record as a whole distribution, not just a mean: `game.record_times()` in `main.gd::get_game_score()` stores spread, median, within-session slope and lapse count beside the mean. The spread is the point — it moves before the mean does.
