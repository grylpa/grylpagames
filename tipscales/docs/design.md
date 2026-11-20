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
  weights it may still have, or its weight). Tapping a crate puts it on the workbench under the board
  -- and the crate itself grows a little (`LIFT_SCALE` 1.10, eased in and back out, drawn over its
  neighbors; `_animate_lift`) --
  with its weights as big iron bell weights (the crate itself shown only as its letter on a weight in its
color -- a picture of the crate and its name in words were too much): TAP one to cross it out (or back), LONG-PRESS one
  (`LONG_PRESS_MS`; a gold ring fills round it, shown only once the finger has held for `RING_AFTER_MS` -- from the first moment, every plain tap flashed a quarter of it) to settle the crate on it at once.
- **The papers that name the crate are MARKED.** While a crate is on the workbench, every paper naming it
  has its browned EDGE in the workbench leather's green instead (`RELEVANT`, its hue raised to
  read on the dark counter; the papers are baked twice, `paper.gdshader` `edge_col`, `_tex_paper_rel`) --
  frames drawn round it, thin or thick, were tried and did not look good (the user); the crate's stamp inside is not marked (the user); the rest are left as they are -- NOT dimmed,
  since dimmed is what a paper set aside looks like and the two read the same (the user). Nothing is
  reordered, and if none of the marked papers is in view the first is scrolled to ("SCALES 12 · 4
  RELEVANT"). They used to be the only papers LISTED: the list jumping away and back was confusing (the user). Tapping a ticket FOCUSES it: its crates are framed
  on the board in their own colors (Mor's hover frames). Its brass button sets it aside, to the end of the list
  (Mor's order); a ticket whose crates are all settled is SETTLED and moves down by itself.
- **Crossing out is FREE** (2026-11-16; it was the Einstein game's rule, the true weight protected and a
  refusal counted as a mistake -- but every refusal TOLD the player that weight was the crate's: "a huge
  hint"). Nothing is checked as it is done. A crate down to one weight gets its BRASS PLATE unchecked and its
  weight leaves the rest of its color; a rubbed-off weight is tapped back the same way, which takes the
  plate off again. The plates are derived afresh from the slates after every move (`_recompute`). A
  MISTAKE is counted only when one SHOWS (the counter cannot be used as a probe): a crate left with NO weight
  (a red "?" on its slate: two plates in its color took its last ones), every crate plated but the scales
  NOT BALANCING (said without saying where), or Hint having to point out a weight rubbed off wrongly. Considered and turned down
  by the user: a verdict the moment a crate is plated. The crates' points come when the puzzle balances.
- **The explained hint** (Mor's) SHOWS a step, it does not make it (2026-11-17, the user: pressing Hint
  over and over solved a puzzle at a profit). FIRST, if a weight a crate really has was rubbed off, Hint
  points it out ("Red C can still weigh 3 kg -- nothing rules that out. It was rubbed off by mistake: tap it
  back."), a mistake as well as a hint. Otherwise `puzzle.next_step` finds the simplest deduction from the
  player's own board -- the color rule first, then clues naming fewer crates, the live ones before those set
  aside -- frames the crates it is about (green, `_hint_rings`, 4 s), focuses and scrolls to its ticket, and
  says why: "Hint: from Gold B = Red C + 2, Gold B can't be 1 or 2 kg; Red C can't be 5 or 6 kg." or "Hint:
  Teal D must be 4 kg -- no other teal crate can still weigh 4." The player makes the move.
  A LEVEL HAS `HINTS_PER_LEVEL` (3), shown on the button ("Hint · 2", grey at 0: "No hints left on this
  level."), each -5. A hint this puzzle has already given is shown again FREE (`_hints_given`), and a
  pointed-out mistake is counted once. The tutorial's hints are unlimited and free. The briefing card lists
  "Hints: 3".

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
- THE WORKBENCH (`leather.gdshader`): green pebbled leather with a gold-tooled double rule, laid on
  the counter -- NO walnut frame round it any more, and the crates start right under the top strip (`top`
  50, just under the strip's counters, `head` 6, bench 94 / 64 tall) with only 6 of rack over the top row (it was 30) and the rack clear
  of the strip: both were room the crates needed, most on the big boards (the user:
  "a lot of wasted space above the crates"); the weights on it are CAST-IRON BELLS lit from above (brass for the
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
  aside pushes its button in and dims it where it lies, with a small press (`ASIDE_HOLD_MS` 420), and only then
  does it go to the end, the others sliding up -- at once, "you can't really tell something happened".
  The set-aside control is a round BRASS PUSH-BUTTON in the corner (`scales_art.gd` `_aside_button`, the
  crates' plate brass; it was a plain inked square box): up, a domed button with a double chevron DOWN ("to
  the bottom"); set aside, pushed in (sunk, but full brass -- NOT dimmed with
  its paper, since it still works), a double chevron UP ("back up"). Not a check (it reads as
  "correct", and nothing is checked there) nor an arrow onto a line (the download sign) -- the user. Its touch area is 58 on a phone, 44 on desktop.
- The papers' header ("SCALES 11 · 1 SET ASIDE") is one size, one case (capitals) and one color (the word's gold) for the words and the numbers, 27 on a phone.
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

**One highlight at a time** (2026-11-17, the user): a picked crate marks the papers naming it, and a tapped
paper marks its crates, but never both at once. Picking a crate lets a focused paper go; tapping a paper puts a
picked crate down (`_on_view_input`, `_tap_ticket`). Both used to stay up together, so the board's highlight
frames contradicted each other.

## The tutorial (`scripts/tutorial.gd`, in `MainCfg.tutorials`)

The real game on the smallest board (2 colors of 4), its puzzles FIXED (seeded from `TUTORIAL_SEED` in
tutorial mode, so the coach always meets the same board), and the level never ends under it. Steps: the
title; a silent wait until the crates are on the shelves; what the chalk means; tap a paper (`focused`); tap
one of its glowing crates (`selected`); rub off a weight the scales rule out, and that a still-possible one
is refused (`crossed`); Hint shows one step and says why, and the player makes it (`hinted`; the step puts the workbench away first,
`tutorial_close_bench`, since the Hint button shows only without a crate on it); finish the puzzle (`solved`); what a
level is and what passes it. Hooks: `tutorial_board_rect`, `tutorial_ticket_rect`,
`tutorial_focus_crates_rect`, `tutorial_bench_rect`, `tutorial_hint_rect`. `devtools/probe_tut.gd
tipscales` drives it through (`_act_tipscales`).

## The main menu's poster

**Options on show (2026-11-19):** the menu shows this game's extra option beside the level row, with no settings cog (`main_menu.show_all_options(true)` in `main.gd`); the scene MOVES up to clear them -- the level list covered the weights under the right pan on a desktop. The COUNTER the balance stands on is just above the panel (`_counter_y`: 18 / 10 above it, was 70 / 34 -- an empty band the user asked to use), so the balance is taller.

The shared menu (`main_menu.gd`, "THE POSTER") gives the screen to `scripts/menu_world.gd` (`main.gd`
`menu_backdrop()`), with only a slim panel at the foot: "Tip the Scales" in cast brass at the top, the pitch
between two short rules, and THE BALANCE -- a big brass weigh-house scale on the counter (plinth, column,
a dial whose needle stands up from the beam, pans on chains), two crates on one pan and a crate and a "2"
weight on the other, rocking as if a crate had just been set down (drawn HEAVY -- a broad plinth, a thick column and
beam, big alternating chain links, each part edged in dark (`EDGE`): thinner, it was lost on a phone against
the engravings and the paneling): a damped swing to one side, then to the
other (`_beam_angle`, 7 s; each swing starts exactly where the last came to rest -- it jumped at first).
Behind it THE WALL, in three layers under the balance (`_draw_wall_layer`; the papered wall and the
dressing drawn once, the view every frame): olive-striped wallpaper with a small gilt motif, aged toward
the corners, a picture rail, an oak chair rail and raised wainscot panels; a tall arched window centered
behind the balance -- a moulded casing with a keystone, a deep reveal, a fanlight and small panes, faint
reflections on the glass, a sill -- looking out on a night sky over a town's roofline (a spire, a few lit
windows), soft clouds drifting across a moon with a halo, a lit limb and its seas; velvet curtains in lit and
shaded folds under a scalloped pelmet on a brass rod with finials, held back by gold cords with tassels;
two engravings (a steelyard, a pair of scales: hatched sky, horizon, the subject in ink) in moulded gilt
frames with a cream mat, hung a touch askew by a cord on two screw eyes from hooks on the picture rail,
casting shadows. The house's brass standard weights stand on the counter, largest to smallest. (Earlier:
the game's rack of crates behind it -- "we don't do that"; then a plain window and flat curtains, a
moonlight slab across the glass, flat frames -- "strange and plain", the user.) Made up, never the board.

## Scoring and levels

- THE LEVELS ARE RANKS in the weigh-house (`level_config.gd` "name"): 1 Porter, 2 Clerk, 3 Weigher,
  4 Bookkeeper, 5 Assayer, 6 Warden, 7 Weighmaster -- "3 · Weigher" in the menu, "Level 3: Weigher" on the
  briefing card, "3 · Weigher" in the HUD strip (its box is 200 wide: the long form ran off its edge).
- WHILE A PUZZLE IS GENERATED (seconds on a phone at level 7, when the player is faster than the worker
  thread), a card over the dimmed board says so -- "Stacking the crates..." under a small brass balance
  rocking (`_draw_waiting`); it was a line of text, easily missed.

- +1 a crate, +10 a puzzle, both when it balances, +5 more if CLEAN (at most `CLEAN_MISTAKES` (1) mistake and no
  hint); -2 a mistake, -5 a hint (3 a level, and they do not make the move). Starts at 0. No session clock.
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
    ├── menu_world.gd       (the main menu's poster: the name in brass, a rocking balance)
    ├── level.gd            (the screen, the rules of play, hints, the puzzle flow)
    ├── puzzle.gd           (generator, solver, depth, hint steps; pure logic, thread-safe)
    ├── scales_art.gd       (crates and slates, iron weights, the clue engravings)
    ├── tutorial.gd         (the coached tutorial)
    ├── crate.gdshader      (a crate's painted front, baked per color)
    ├── paper.gdshader      (the clue paper, baked)
    ├── leather.gdshader    (the workbench, baked)
    └── weighhouse.gdshader (the wall, the rack and its shelves, the counter)
```

## Audio (2026-11-19)

the MENU has its own loop (`art/sounds/tipscales_menu_ambient.ogg`, `devtools/make_ambient_sounds.py` `tipscales_menu`): the game's music with the poster's world in front -- the beam creaking, weights, the clock.

## Menu poster frame rate (2026-11-19)

To hold 60 fps on a mid-range phone (see CLAUDE.md, "Menu frame rate"): the weighhouse backdrop shader (no TIME) is rendered once (a DrawnOnce with `inner_material`); the papered wall and the window dressing with the pictures are drawn once; the foreground is three layers -- the standard weights (once), the balance (live, `_cv = _fg`), the name (once). Only the view through the window and the balance are drawn every frame.
The balance's shadow, plinth, column and dial face are drawn once with the weights (`_draw_balance(full, true)` in `_fg_back`); only the needle, beam and cap are live (`_balance_live`).
The pans are drawn once each AT REST (`_pan_draw`: a DrawnOnce per pan in a holder Control the size of the screen -- a zero-sized holder never shows -- with its chains, crates and weight) and carried each frame to where the beam's ends hang (`_place_pans()` from `_process`, `_pan_rest` / `_pan_hang` set in `_layout`, `_balance_geom(full)` -> pivot, half length, hang). They are redrawn on a layout change and when the crate bake completes. Up close they are a hair softer than drawn live.
