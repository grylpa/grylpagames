# Tip the Scales (`tipscales`)

A weigh-house logic puzzle, in the Einstein-riddle family. The design comes from Mor's desktop game
"Scales" (`mor/einstein/` in the private repo: `plan.md`, `assumptions.md`, `project.md`, a mockup);
this is that game remade for a phone, in Godot. Category: Brain twisters. Folder and save key
`tipscales`; autoloads `TipscalesG` (`scripts/globals.gd`) and `TipscalesLevelConfig`.

## The puzzle

- Crates come in COLOR SETS (rows). A color has `crates` crates, A, B, C..., which weigh 1..`crates` kg,
  each weight once: two crates of one color never weigh the same; crates of different colors may.
- The clues are BALANCE SCALES, every one true for the hidden weights (`puzzle.gd` `T`):

| Type | Picture | Meaning |
|---|---|---|
| EQUAL | A level with B (different colors) | A = B |
| OFFSET | A level with B plus a brass weight k | A = B + k |
| SUM_EQ | A + B level with C | A + B = C |
| SUM_LIGHTER | C down, A + B up | A + B < C |
| PAIRS_EQ | A + B level with C + D | A + B = C + D |
| BETWEEN | three crates on a shelf, the middle one raised | A lies between B and C (either order) |
| HEAVIER | A down | A > B |
| SUM_HEAVIER | A + B down | A + B > C |

- Every puzzle has exactly ONE answer and is solvable by LOGIC ALONE (`puzzle.gd`): the generator picks
  the hidden weights, adds random true clues until two rule families -- the CLUE RULE (keep only the
  weights some satisfying combination of a clue's crates uses) and the COLOR RULES (a crate down to one
  weight takes it from its color; a weight only one crate of a color can still take is that crate's) --
  fix every crate, drops every clue the rest can do without, then adds the level's `spare` clues. For
  deeper puzzles it makes `tries` and keeps the one needing the most ROUNDS OF DEDUCTION (`depth_of`).
  All of this is Mor's design, ported from the specification (the Java source was not in the folder).
- `devtools/probe_tipscales_gen.gd` checks it, per level: one answer by search, solvable by logic, every
  clue true, and a blank board finished by HINTS alone with no wrong step; and times the generator.
  Measured (GDScript, desktop): 1 ms for 2x4 up to about 1.2 s for 6x6 -- so a puzzle is generated on a
  WORKER THREAD (`WorkerThreadPool`), the next one while the current one is played.

## Made for a phone (what changed from Mor's desktop version)

Mor's screen put up to 216 candidate numbers, 18 px each, in a 6x6 grid beside a scrolling panel of up
to 28 clue cards, played with left-click (place), right-click (cross out), hover (frame a clue's crates)
and Space (hold). None of that works on a phone, and an Expert puzzle took tens of minutes. So:

- **Short puzzles, more of them.** A level is `puzzles` (3) puzzles; the size grows with the level, from
  2 colors of 4 crates to 6 of 6 (`level_config.gd`), and the depth through the clue MIX (strong clues
  on the first levels, weak "tipping" ones later), the spare clues and `tries`.
- **The WORKBENCH: one crate at a time.** The board only SHOWS the crates (each with a paper tag of the
  weights it may still have, or its weight). Tapping a crate puts it on the workbench under the board,
  with its weights as big iron bell weights: TAP one to cross it out (or back), LONG-PRESS one
  (`LONG_PRESS_MS`; a gold ring fills round it, shown only once the finger has held for `RING_AFTER_MS` -- from the first moment, every plain tap flashed a quarter of it) to settle the crate on it at once.
- **The tickets follow the crate.** While a crate is selected, only the scales that name it are listed
  ("SCALES WITH RED C") -- most of the scrolling goes. Tapping a ticket FOCUSES it: its crates are framed
  on the board in their own colors (Mor's hover frames). Its check sets it aside, to the end of the list
  (Mor's order); a ticket whose crates are all settled is SETTLED and moves down by itself.
- **Crossing out is FREE** (2026-11-16; it was the Einstein game's rule, the true weight protected and a
  refusal counted as a mistake -- but every refusal TOLD the player that weight was the crate's: "a huge
  hint"). Nothing is checked as it is done. A crate down to one weight gets its BRASS PLATE unchecked and its
  weight leaves the rest of its color; a rubbed-off weight is tapped back the same way, which takes the
  plate off again. The plates are derived afresh from the slates after every move (`_recompute`). A
  MISTAKE is counted only when one SHOWS (the counter cannot be used as a probe): a crate left with NO weight
  (a red "?" on its slate: two plates in its color took its last ones), every crate plated but the scales
  NOT BALANCING (said without saying where), or Hint having to put a weight back. Considered and turned down
  by the user: a verdict the moment a crate is plated. The crates' points come when the puzzle balances.
- **The explained hint** (Mor's): FIRST, if a weight a crate really has was rubbed off, Hint puts it back
  ("Red C can still weigh 3 kg -- nothing rules that out. It was rubbed off by mistake."), a mistake as well
  as a hint. Otherwise `puzzle.next_step` finds the simplest deduction from the player's own
  board -- the color rule first, then clues naming fewer crates, the live ones before those set aside --
  applies it, frames the crates it touched (green, `_hint_rings`), focuses and scrolls to its ticket, and
  says why: "From Gold B = Red C + 2: Gold B can't be 1 or 2 kg; Red C can't be 5 or 6 kg." or "Teal D
  must be 4 kg: no other teal crate can still weigh 4."

## The screen (`scripts/level.gd`, drawn in code)

Top to bottom, laid out by `_layout()` for the 680-wide canvas (phone 1200 tall, desktop 788): the HUD
strip (score, settled : mistakes, the level in the strip -- no clock), the BOARD (column letters above;
the cell height gives way first when the rows do not fit), the WORKBENCH (idle: the puzzle's progress
and the Hint button), the MESSAGE line, the tickets' header, and the TICKETS, two to a row, scrolling by
drag with a fling (or the wheel), stopping above the app's button bar.

THE LOOK (`scripts/scales_art.gd` and four shaders), a WEIGH-HOUSE AT LAMPLIGHT. The first pass followed
Mor's screen grab (a grid of tiles beside a grid of cards, on dark boards) and was "far from amazing ...
you stayed too close to the original grab"; the second builds a place:
- THE RACK (`weighhouse.gdshader`): a back wall of warm plaster under a lamp, walnut posts either side
  of the board and a SHELF under every row of crates -- laid from the board's own geometry, passed in as
  uniforms by `_layout()` -- each lit on its front edge and shading the wall beneath.
- THE CRATES (`crate.gdshader`): pine planks under a coat of the set's paint, the grain showing through,
  rubbed back to bare wood only along the plank edges and in a scuff or two (a blotchier wear read as
  grime at this size); darker frame boards with a lit bevel; iron corner brackets with rivets; nail
  heads. On top (`draw_crate`): the letter sprayed through a stencil, and a SLATE hung on a nail with the
  weights the crate may still have CHALKED on it -- a weight crossed out is rubbed off, leaving a smudge.
  A settled crate wears a BRASS PLATE with its weight stamped in.
- THE WORKBENCH (`leather.gdshader`): green pebbled leather with a gold-tooled double rule in a walnut
  frame, set into the counter; the weights on it are CAST-IRON BELLS lit from above (brass for the
  crate's own once settled), a weight crossed out chalked through.
- THE COUNTER below (the same shader): dark oak boards with a rounded lip, and on it THE CLUE PAPERS
  (`paper.gdshader`): old ledger slips, laid paper with fibers, foxing, browned and DECKLED (torn) edges and
  a soft fold, each lying a little askew (up to 1.4 degrees). The clue is an INK ENGRAVING: a balance with
  a hatched column and stepped base, a tapered beam with a pointer, pans on three chains; the crates in the
  pans are colored ink STAMPS with the letter left in the paper's color. A paper in focus glows; one whose
  crates are all known gets a red rubber stamp, WEIGHED. BETWEEN is three stamps on a hatched shelf, the
  middle one raised and boxed, with a SWAP sign under the shelf and "either order" under the caption (a row
  of three alone read as a ruler, lightest on the left).
- The materials are shaders rendered ONCE into textures (`_bake_materials`, at twice the size, drawn
  through mipmaps), again only when the layout's sizes change: every frame only draws textures. Two
  crate variants per color, three papers.
- Six set colors -- Red, Gold, Teal, Violet, Blue, Rose -- named on every paper ("Red C"). Numbers and
  labels in Noto Serif Bold (`art/fonts/NotoSerif-Bold.ttf`, OFL), sentences in the text face. A solved
  puzzle swings every scale on its pivot and settles them ("Balanced!"), then the next puzzle comes in
  `NEXT_PUZZLE_S`.
- THE RULE IS THE PICTURE. Written-out rules are a menu SWITCH, "Show rules" (`TipscalesG.show_rules`,
  saved as the second settings value), OFF by default: the engraving says exactly the same, and without the
  text it has the whole paper, so its stamps and brass weights are larger. On, the rule is written under it
  as a ROW of the same colored crate stamps with the math between them in large type (`draw_rule`,
  `rule_tokens`: "Red C" in words took the room the signs needed); BETWEEN reads "[A] between [B] & [C]".
  The papers are a little taller when the rules are on (`_card_h`). Hints still write names in words.
- THE PAPERS MOVE, they do not jump (`_animate_cards`): each eases to its place in the list. Setting one
  aside stamps its check and dims it where it lies, with a small press (`ASIDE_HOLD_MS` 420), and only then
  does it go to the end, the others sliding up -- at once, "you can't really tell something happened".
  The check box is larger (58 on a phone, 44 on desktop).
- The papers' header ("SCALES 11 · 1 set aside") is one size for the word and the numbers, 27 on a phone.
- READABLE ON A PHONE (the user: everything under the crates was unreadable): the papers stay TWO TO A ROW
  but are TALLER on a phone (`_card_h`): larger crate stamps and brass weights, and the rule (when written
  out) in large signs. One to a row, the rule beside the
  engraving, was tried first; the user preferred the grid. The Hint button's word (29), the workbench's
  two lines and the message are larger there too. The crate letters and the
  stamps' letters have a dark outline (cream alone vanished on the gold crates); the workbench's text,
  the message line (22) and the papers' header are larger and brighter on a phone.
- MESSAGES ARE FOR NOW: a message fades after a few seconds (`MSG_*_MS`; a hint's reasoning stays 9 s) and
  the player's next good move clears it. One that stayed ("Not so fast ...") read as still true after the
  crate was settled.

## Sound

`devtools/make_tipscales_sounds.py` (synthesized, seeded): `pick` a hollow wooden knock (a crate to the
bench), `chalk` a dry scrape (a weight rubbed off or back), `settle` a brass plate tapped on over the crate's
thud, `wrong` a dull double knock, `hint` one small brass bell, `solved` the pans chiming as the scales
swing and settle, then a rising close. The ambient is `make_ambient_sounds.py` "tipscales": THE WEIGH-HOUSE
ITSELF, no tune -- the market's voices through the wall as the continuous layer (never words), and around
it a handcart on the cobbles, pigeons on the sill, the boards creaking, a scale's chains nudged, a crate
set down in another room, footsteps on the boards. Nothing melodic or rhythmic, nothing like the game's own
chalk, knocks or brass. A first version was music (slow harp arpeggios): "not really appropriate"; of a
soundscape, a piano trio, chamber music or silence, the user chose the soundscape. Started with the level,
stopped at the menu (`main.gd`).

## The tutorial (`scripts/tutorial.gd`, in `MainCfg.tutorials`)

The real game on the smallest board (2 colors of 4), its puzzles FIXED (seeded from `TUTORIAL_SEED` in
tutorial mode, so the coach always meets the same board), and the level never ends under it. Steps: the
title; a silent wait until the crates are on the shelves; what the chalk means; tap a paper (`focused`); tap
one of its glowing crates (`selected`); rub off a weight the scales rule out, and that a still-possible one
is refused (`crossed`); Hint does one step and says why (`hinted`); finish the puzzle (`solved`); what a
level is and what passes it. Hooks: `tutorial_board_rect`, `tutorial_ticket_rect`,
`tutorial_focus_crates_rect`, `tutorial_bench_rect`, `tutorial_hint_rect`. `devtools/probe_tut.gd
tipscales` drives it through (`_act_tipscales`).

## Scoring and levels

- THE LEVELS ARE RANKS in the weigh-house (`level_config.gd` "name"): 1 Porter, 2 Clerk, 3 Weigher,
  4 Bookkeeper, 5 Assayer, 6 Warden, 7 Weighmaster -- "3 · Weigher" in the menu, "Level 3: Weigher" on the
  briefing card, "3 · Weigher" in the HUD strip (its box is 200 wide: the long form ran off its edge).
- WHILE A PUZZLE IS GENERATED (seconds on a phone at level 7, when the player is faster than the worker
  thread), a card over the dimmed board says so -- "Stacking the crates..." under a small brass balance
  rocking (`_draw_waiting`); it was a line of text, easily missed.

- +1 a crate, +10 a puzzle, both when it balances, +5 more if CLEAN (at most `CLEAN_MISTAKES` (1) mistake and no
  hint); -2 a mistake, -3 a hint. Starts at 0. No session clock.
- A level passes when `pass_pct` (66) of its puzzles were solved cleanly: 2 of 3.
- Score row: `[didwin, aborted, level, mean seconds per puzzle, % clean]`; the puzzle times are recorded
  whole (`record_times(..., "puzzle")`), and mistakes, hints and puzzles solved are counted.

## Published

In the games document (`docs/the-nomizo-games.md`, Brain twisters) and on the site: the descriptions page
(built), the category shelf in `games/index.html`, the thumbnail columns in `index.html`, `thumbs.js`
`NAMES`, and `thumbnails/tipscales.png` (the chooser tile).

## Files

```
tipscales/
├── art/game_screen_200.png     (the chooser tile: devtools/make_tipscales_tile.gd)
├── docs/design.md
├── scenes/main.tscn, level.tscn
└── scripts/
    ├── globals.gd          (TipscalesG: starting level; no session clock)
    ├── level_config.gd     (TipscalesLevelConfig: sizes, clue mixes, spare clues, puzzles, pass)
    ├── main.gd             (menu, instructions, scores)
    ├── level.gd            (the screen, the rules of play, hints, the puzzle flow)
    ├── puzzle.gd           (generator, solver, depth, hint steps; pure logic, thread-safe)
    ├── scales_art.gd       (crates and slates, iron weights, the clue engravings)
    ├── tutorial.gd         (the coached tutorial)
    ├── crate.gdshader      (a crate's painted front, baked per color)
    ├── paper.gdshader      (the clue paper, baked)
    ├── leather.gdshader    (the workbench, baked)
    └── weighhouse.gdshader (the wall, the rack and its shelves, the counter)
```
