# Mosaic (folder `mosaic`) — design

A picture is shown for a countdown, then cut into square pieces and shuffled. The player drags the
pieces back to where they were, from memory. A **round** ends when the picture is whole again, or
when the round's time runs out. **The same picture comes back for every one of the level's rounds**
-- shown again, reshuffled, rebuilt -- whether the round before was rebuilt or not, so what is
measured is **how much faster the player gets at the exact same picture**: memory, and how fast a new
memory is learned.

## Files

```
mosaic/
├── scripts/
│   ├── globals.gd        MosaicG autoload: starting level, failed rounds per level (saved)
│   ├── level_config.gd   MosaicLevelConfig: the level table (see below)
│   ├── picture.gd        MosaicPicture: the pictures, and the rule that no two pieces look alike
│   ├── main.gd           orchestrator: menu, HUD, instructions, score row
│   └── level.gd          the board, the phases, drag to swap, tap to rotate, the round flow
├── scenes/  main.tscn (Level, HUD, GameTick, Help), level.tscn (a CanvasLayer; all UI built in code)
└── art/game_screen_200.png   the chooser tile
```

## Levels -- `level_config.gd`

One level is one picture. Every field is per level:

| key | meaning |
|---|---|
| `cols`, `rows` | the grid the picture is cut into (square pieces) |
| `picture` | **a list** of kinds -- `scenery`, `poster`, `quilt`, `dino` (below); each play of the level picks one at random, so a dino level is not limited to the finite set of cards. **An empty list means every kind** (on a rotation level, every kind that can be rotated: all but dino) |
| `study_sec` | **the countdown**: how long the whole picture is shown before the shuffle -- in the first round, and again after a round that ran out of time |
| `restudy_sec` | the **shorter** countdown before a round that follows a rebuilt one: the picture is known, so the look is a reminder, not a study |
| `round_sec` | one round's time limit |
| `rounds` | how many rounds the level plays, all on the same picture |
| `pass_pct` | the level is passed when the **last round is rebuilt and** at least this percent of all its rounds were |
| `rotation` | pieces are also rotated when shuffled, and a tap rotates one a quarter turn |

**"scenery", not "landscape"**: the picture takes the board's shape, often taller than wide, and the
word "landscape" promised a wide one.

**Rotation is the table's choice**, and the table uses it only on pictures with full image content
(scenery, poster), where how the picture continues tells you which way up a piece goes. Quilts are
pure memory with no leading clues, so the table gives them **small boards** (3 x 3, 3 x 4) and **no
rotation** -- but the code does not forbid it (a 2 x 2 quilt with rotation, say). The one thing the
code does refuse is rotating a **dino card**: it keeps its whole picture, so its pieces are not square
and a quarter turn would not fit back in the cell. On a rotation level a list leaves dino out
whenever it has anything else; a list of dino cards only plays without rotation.

| level | picture | grid | rotation | first look / later look / round / rounds / pass |
|---|---|---|---|---|
| 1 | scenery | 3 x 3 | | 8 s / 4 s / 45 s / 4 / 50% |
| 2 | scenery or dino | 3 x 4 | | 10 s / 5 s / 60 s / 4 / 50% |
| 3 | poster | 4 x 4 | | 12 s / 6 s / 75 s / 4 / 60% |
| 4 | scenery | 4 x 4 | yes | 12 s / 6 s / 80 s / 4 / 60% |
| 5 | quilt | 3 x 3 | | 10 s / 5 s / 60 s / 4 / 60% |
| 6 | dino, scenery or poster | 4 x 5 | | 14 s / 7 s / 90 s / 4 / 60% |
| 7 | poster | 5 x 5 | yes | 16 s / 8 s / 110 s / 5 / 70% |
| 8 | quilt | 3 x 4 | | 12 s / 6 s / 75 s / 5 / 70% |
| 9 | scenery | 5 x 5 | yes | 18 s / 9 s / 120 s / 5 / 70% |

## The pictures -- `picture.gd`

Made on the CPU -- spans drawn with `Image.fill_rect`, the sky computed at a quarter of the resolution
and scaled up -- so a headless probe makes the same pictures the game does. `PIECE_PX` (128) is the
drawing resolution of one piece; pieces are shown with linear filtering at up to about 190 px.

The four kinds are a **difficulty dial for how much of the score is memory**. A continuous picture can
be rebuilt by matching edges, like a jigsaw, without remembering anything:

- **scenery** -- sky (a gradient lit round the sun), clouds, two ranges of hills, fields, trees and
  houses. Coherent, memorable; edges help a lot.
- **poster** -- a diagonal-gradient ground and a few large flat shapes (discs, rings, bands,
  triangles, half discs) with a scatter of dots. Fewer edge cues.
- **quilt** -- every piece its own swatch (stripes, dots, checks, rings, chevrons, a big dot) in its
  own colour, nothing crossing an edge. Pure memory of where each piece was.
- **dino** -- one of the shared dino cards, **whole, never cropped**: scaled to the board's width, its
  height following the card's own proportions (rounded to whole rows), so the board takes the card's
  shape and its pieces are a little taller than wide. Finite, so it shares its levels with other kinds.

**No two pieces may look alike.** Two plain-sky squares are interchangeable, so a correct answer could
look wrong. `make()` draws, compares every pair of pieces at 6 x 6 px (mean channel difference under
`SAME_BELOW` is "the same") and draws again until they all differ. On a level with rotation it also
compares each piece with itself turned -- its right way up must be knowable -- using the most-changed
quarter of the piece (`TURN_SAME_BELOW`), since one dot in a corner is enough for a person and hardly
moves an average. Three things make that pass:

- a soft **light falloff** across the whole picture (`_light`): a big flat shape can cover whole
  pieces in one colour, identical and the same whichever way up, and this gives each a lighter and a
  darker side (scenery and poster);
- **`busy`** drawing on rotation levels: more, smaller shapes and denser dots on a poster; more
  clouds, a flock of birds, more trees and houses on a scenery picture;
- a **darker shaded corner** on every quilt swatch, at a random corner;
- **flowers in the fields** of a scenery picture on a rotation level.

Measured on the table's rotation levels (20 pictures each, within 40 tries): scenery 4 x 4 20 of
20 (mean 1.6 tries), poster 5 x 5 20 of 20 (4.2), scenery 5 x 5 19 of 20 (12.6). `margin()` says
how far a picture clears the rule (1 or more passes). If a kind still fails after `TRIES`: **without
rotation it falls back to a quilt**, which always passes -- the rule matters more than the kind;
**with rotation** a quilt is not allowed, so the attempt that came closest stands.

## A round -- `level.gd`

Phases: `STUDY` -> `SHUFFLE` -> `PLAY` -> `SOLVED` or `TIMEUP` -> `ROUND_CARD` -> `REVEAL` -> `STUDY`
... and after the last round, `DONE`.

- **The level intro** gives the rounds, the pieces, the picture kind picked, each round's time, whether
  pieces are rotated and the share of rounds needed to pass.
- **STUDY**: the whole picture, the countdown in the caption ("Remember the picture · 6") and in the
  bar. The number is not on the picture: it would cover part of what is being remembered. Its length
  is `study_sec` in the first round and after a round that ran out, `restudy_sec` after a rebuilt one
  (`study_now_ms()`, read live from the level's values).
- **SHUFFLE -- not shown as movement.** Pieces sliding to their new places would be a trail to follow
  back. Every piece flips over where it stands (a staggered wave), the board is briefly all backs,
  every piece takes its new place and turn, and every piece flips up again (staggered). Only a few
  pieces are left where they belong (at most one in eight); with rotation at least half are rotated.
- **PLAY**: every piece wears an outline until the picture is whole again. The round's time is the
  bar.
- **SOLVED** ("Whole again!") or **TIMEUP** ("Time's up" -- counted in `failed_rounds` and in
  `MosaicG.fails_by_level` across sessions, saved in the settings), for a second.
- **ROUND_CARD**: a short card between rounds -- the result, the time (if rebuilt) and the rounds left. Closing it starts the next round. Not after the last round: the level card
  covers it. (In a tutorial there is no card; the next round follows directly.)
- **REVEAL**: every piece flips back home and upright, and the countdown starts the next round -- the
  same picture, whether the round before was rebuilt or not.
- **DONE**: the level card lists every round's time (or "time ran out"; one row each up to six rounds,
  past that five to a row, "Rounds 6-10 (sec): 22, 18, -, 15, 12", since the card does not scroll), the last rebuild against the
  first ("35% faster"), the rounds rebuilt, "Total level moves" (all its rounds) and rotations. Only this play: the
  all-time count of failed rounds is recorded (`failed_rounds_level_total`), not shown. **Passed** (`passed()`) when the last round was rebuilt and at least `pass_pct` of the
  rounds were.

### Input -- drag to swap, tap to rotate

Mouse button and mouse motion only: touch is emulated as mouse, and taking both would see every touch
twice. A press on a piece and a move beyond `TAP_SLOP` lifts it (bigger, on top) and it follows the
pointer; on release, **the piece's middle** -- not the finger, which covers it on a phone -- picks the
cell, and the piece there goes to where the lifted one came from. A release with no drag is a **tap**:
on a level with rotation it rotates the piece a quarter turn, otherwise nothing.

## What is recorded

The score row (`score_columns`): `didwin, aborted, level, last_round_ms, first_try_pct, rounds_played,
moves, failed_rounds`.

- `last_round_ms` -- the **last round's** time, **only when that round was rebuilt** (0 when it ran
  out). It is the Speed tab ("Last round") and its chart; a 0 is skipped there.
- `solve_ms` -- the same time, in the metrics, and **only present when there is one**: the Summary row
  reads every record that has the key, and a 0 would count as the fastest rebuild ever
- `first_try_pct` -- the share of pieces in place when the first round ended (100 if it was rebuilt)
- `rounds_played`, `failed_rounds`, `moves` (swaps)
- metrics: `round_times_ms` and `round_solved` (every round, in order -- the learning curve on one
  picture), `first_solve_ms`, `faster_pct` (the last rebuilt round against the first rebuilt one, in
  percent; 0 with fewer than two rebuilt rounds), `solved_rounds`, the rebuilt rounds' times as a
  `round_*` block, `turns`, `rounds_allowed`, and `failed_rounds_level_total`
- task signature: grid, picture kind, rotation, both countdowns, round time and rounds

**The stats screens.** Speed lists each session's last-round time, one level at a time (picked from
the level bar above the table, which every game's per-level table now has), in seconds (the scores
screen switches an ms column to seconds once every time in it is 3 s or more). Charts has "Last
round" (the same, one line per level, by session) and Mosaic's own view, **"Rounds"**
(`GameInstrument._round_curves`): one line per level, x = round 1, 2, 3 ..., y = the mean time to
rebuild that round over every session at that level, rebuilt rounds only -- a round that ran out has
no rebuild time, and its limit would draw a time nobody took. It is read from the session records,
not from trials.

The Summary shows Time to rebuild the picture (last round), How much faster by the last round, Pieces
right in the first round, and Rounds that ran out of time (`GameInstrument.SUMMARY_ROWS`,
`StatsOverview.METRICS`). Points: what was left of each rebuilt round, plus 20 for rebuilding it at
all.

`devtools/probe_mosaic.gd` checks the picture rule for every full-picture kind on grids up to 5 x 5
with and without rotation and for quilts on small boards without, that a quilt level plays without
rotation whatever the table says and that the table gives quilts small boards; that after a rebuilt
round the same picture comes back whole with the shorter countdown, and after a failed one with the
full countdown; that every round is played and recorded, the round card's contents, and the pass
rule; a whole level (countdown, shuffle, outlines, solving by swaps and by rotations), a round that
runs out (counted, the picture shown again whole), and the real input (a drag swaps, a tap rotates only
with rotation). `devtools/seed_demo.gd` seeds Mosaic's history as the game saves it.

## The chooser tile

`art/game_screen_200.png` (200 x 200) is **drawn** (`devtools/make_thumbs.py`, `mosaic()`) from one of
the game's own pictures (`devtools/thumb_src/mosaic_source.png`, made by `picture.gd`): the picture
filling the whole tile, edge to edge -- no board border, no gaps -- cut 3 x 3 with the outline every
piece wears while shuffled, two pieces swapped, and one lifted off its place as if being dragged.

## Not yet

No coached tutorial (`MainCfg.tutorials`); the instructions screen explains it.
