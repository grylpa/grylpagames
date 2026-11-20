# Couples — design

## Overview
Couples is a **spot-the-pair** game. Each board is an **NC × NR grid** of dino cards.
Exactly **one image appears twice**; every other cell is a unique image. The player finds
the matching pair and **taps both cards**. Modeled on the Dino game — same dino pictures,
old-print card frames (`set_photo`), dino background (`bk1.jpg`), phase machine, scoring and level flow.

## File structure
```
couples/
├── scripts/
│   ├── globals.gd       # CouplesG autoload: game util + own dino-image loader (res://art/dinos)
│   ├── level_config.gd  # CouplesLevelConfig autoload: LEVELS array
│   ├── level.gd         # gameplay: grid build, selection, phases, scoring
│   └── main.gd          # orchestrator: menu, HUD, help, scores (mirrors dino/main.gd)
├── scenes/
│   ├── level.tscn       # CanvasLayer + level.gd (UI built in code)
│   └── main.tscn        # Main + Level + HUD + GameTick + Help
└── art/
    └── game_screen_200.png   # chooser tile: 3x3 mosaic of dino images
```
Couples uses the **shared** `res://shared/scripts/card.gd` as an old print (`set_photo(true)`; the white zigzag until 2026-11-18) in **FILL fit**: every card frame has a single uniform aspect
(`CARD_ASPECT = 566/374`, the max dino image height / max width) and the image is stretched to
fill it. The dino JPGs vary in aspect (~1.47–1.59), so ASPECT fit gave visibly different card
heights; FILL makes a tidy uniform grid with the whole image shown and no crop (the tiny
stretch is identical on both copies of the duplicate, so it's invisible for matching). It has
its own dino-image loader in `CouplesG` (no cross-*game* refs; the shared card is framework
code, not another game). Images
come from `CouplesG.dino_texture(idx)`, loaded from the **shared** `res://art/dinos` set
(dino1..N). Background is always the shared `res://art/dinos/bk1.jpg`. THE COUPLE NEVER SHARE A FRAME (the user): every card's wear is its own random draw, and the two copies' scorches are
put on opposite edges (`burn_side`), so the frames give nothing away.

## Autoloads
- `CouplesG` — `game := GenericGameUtil.new("Couples","couples",0,2,0)`, dino image accessors
  (`num_dinos`, `dino_texture`), settings save/load.
- `CouplesLevelConfig` — `LEVELS` + helpers (mirrors dino's config helpers).

## Level config params (per LEVELS entry)
| field | meaning |
|-------|---------|
| `id` / `name` | level id (monotonic) / display name |
| `nc` / `nr` | grid columns / rows |
| `show_time_sec` | seconds a board stays up before a non-answer = miss |
| `gap_sec` | blank pause between boards |
| `duration_sec` | level length; the level completes when it elapses |

## Gameplay flow
- **Pre-level popup** (`game.show_game_popup`, the shared briefing card — see "The level intro" below; facts only since 2026-11-12, "Find the two matching cards" is the instructions screen's): level, grid size, board time,
  total time. Play starts when it closes (`closed` → `_on_game_popup_closed`).
- **Board build** (`_build_board`): pick `NC*NR-1` distinct dino images; one of them is the
  duplicate (`target_img`). Its two cells are placed by a **coin flip**: half the time
  non-adjacent (Chebyshev distance ≥ 2, not 8-neighbors; falls back to any two distinct cells
  when impossible, e.g. 2×2), the other half any two distinct cells (so the pair is sometimes
  adjacent). Always requiring distance ≥ 2 had odd effects — e.g. the center of a 3×3
  (a neighbor of every cell) could never be part of the couple.
- **Layout is derived from available space, all platforms** (`_layout` + `_position_cards`):
  the grid area runs from below the instruction (`_grid_top`) down to just above the app
  bottom button bar. That bar is anchored to the full-canvas bottom and, on mobile, is taller
  (~70px) than the footer reserve (`MainGlobals.footer_height`, 40px), so `_layout` subtracts
  `bottom_reserve = max(20, bar_h − footer + 10)` (bar_h 70 mobile / 44 desktop) — otherwise the
  bottom row runs under the bar. There are **no mobile/desktop-specific card sizes**; card_w is
  solved from the area: for each axis `n*size + (n-1)*(E*size+min_gap) + 2*(E/2*size+min_edge) ≤
  avail` with **E = 0.12** the enlarge allowance (a selected/matched card scales to 1.12, i.e.
  grows 0.06 per side). So inter-card gaps are the *minimum* that still lets two adjacent
  enlarged cards clear (horizontal **and** vertical), and outer margins reserve the edge cards'
  enlargement. `card_w = min(width-fit, height-fit)`; the block is centered so leftover space
  becomes extra margin. The level-config `nc/nr` drive the grid; card size is whatever fits.
- **Phases** (`_process`, driven by `game.game_time`): IDLE → SHOW (grid up, timeout bar
  counts down `show_time`) → FEEDBACK → GAP → next board.
- **Selection**: tap a card to select it (pops up via scale + z-index); tap it again to
  deselect; tap a **different** card to commit the pair. Match → correct, else → wrong. On
  resolve the correct pair is tinted green so the player sees the answer. Timeout = miss.
- Hit-testing is done in `level._input` against each card's stored screen `rect` (the reused
  dino card has no input of its own).

## Scoring & progression
- Correct: `+15 + speed bonus`, `add_correct_or_mistake(1,0)`, "correct" sound.
- Wrong / timeout: small `-penalty` (capped at current score), `add_correct_or_mistake(0,1)`,
  "wrong" sound.
- Per-level stats reset every level (HUD hits/misses, accuracy, mean solve time).
- **Level completes on `duration` elapsing** — `game.game_over_on_time_out = false`, so the
  clock running out fires `sig_time_over` → `_level_done(true)` (advance). Monotonic level
  counter, level-done popup with accuracy + mean time; max level loops with no popup.
- Score row: `[didwin, wasaborted, level_id, mean_response_time_ms, pct_correct]`.

## Key pitfalls
- `game_over_on_time_out` stays **false**: `duration` is a per-level budget, not a game-over.
  `_on_time_over`/`_level_done` guard on `game.level_is_done` (the HUD keeps firing
  `sig_time_over` each second once the clock hits 0).
- Layout is re-applied on popup close + a deferred `_layout()` in `new_game` (first-level
  menu→level transition can run before the viewport settles — same fix as dino).
- String formats built by concatenation need parentheses: `("…%s" + …) % [args]` — `%` binds
  tighter than `+`.
- **Card taps handle only `InputEventMouseButton`.** The project has BOTH mouse↔touch
  emulations on (`emulate_touch_from_mouse=true`, `emulate_mouse_from_touch` default true),
  so every tap fires a mouse event AND a touch event. Handling both would select then
  immediately deselect the card (net nothing). Mouse-button-only covers mouse and touch
  (same reason weris cards only handle mouse). Each card has a transparent `Control` hit-area
  (`gui_input`) rather than manual hit-testing in `_input`.

## Tutorial

`couples/scripts/tutorial.gd` (9 steps), entry `couples/scripts/main.gd::start_tutorial()`,
level 1 (2x2). See `docs/tutorials.md` for the step schema.

What a first-timer gets wrong:

- **They read it as a memory game** — turn cards over and remember. It is not: every card is face
  up the whole time, exactly one picture appears twice, and everything else appears once. The
  first caption says that before a board is even dealt.
- **Tapping is two-stage.** The first tap picks a card up, the second commits the pair; a second
  tap on the *same* card puts it back down rather than confirming it. A player who taps once and
  sees the card grow does not necessarily know a second tap is expected.
- **The bar is a deadline.** Running out scores like a wrong pair.

Specific to this game:

- **Every caption reads the board rather than assuming it.** `tutorial_twin_rect()` finds the
  matching card *from the one the player picked up*, and `tutorial_selection_is_pair()` says
  whether that pick was part of the answer at all — so the coach reacts to a wrong first tap
  instead of talking past it, and the closing caption reads `tutorial_last_was_right()` rather
  than assuming success.
- **The board deadline is held for the whole tutorial** (`tutorial_no_deadline`). Level 1 gives
  only 6s per board, and the doing steps run unpaused — a first-timer being told to find the
  matching pair can easily take longer, and losing the board to a timeout mid-explanation teaches
  nothing. The bar stays on screen, held full and green, so the step that points at it still has
  something to point at. Verified: dithering 12s (twice the deadline) loses no board, while a real
  round still times out normally.
- **No freeze work was needed.** `_can_play()` requires `not game.paused()`, but the real
  protection is that the board deadline is measured in `game.game_time`, which excludes paused
  time. Removing the `paused()` term from `_can_play()` does *not* break anything, because every
  phase comparison in `_process` reads that same frozen clock.
- `new_game()` skips the "Grid 2 x 2 / Board time…" intro popup in
  tutorial_mode, and `_level_done()` returns early so `duration_sec` running out mid-lesson cannot
  drop a level-completed popup on the coach.
- **A dismiss-tap cannot reach the cards.** The cards' hit areas are Controls with `gui_input`,
  and one physical tap is two events: dismissing the "Picked up" caption with a tap that happened
  to sit over a card used to register as choosing that card. Fixed in the shared runner — the
  overlay stays at MOUSE_FILTER_STOP through `STEP_SETTLE_MS` after a step change.
- **The "picked up" step is descriptive only.** The board is frozen while a caption is up, so an
  instruction there cannot be obeyed — the player's tap just dismisses the step. Anything to DO
  lives on the following action step.
- Events reported to the coach: `board_shown`, `card_selected`, `card_deselected`, `answered`,
  `answered_right`, `answered_wrong` — all `game.tutorial_notify`, no-ops outside tutorial mode.
- Points for the coach, all in screen coordinates: `tutorial_grid_rect`, `tutorial_selected_rect`,
  `tutorial_twin_rect`, `tutorial_pair_rect`, `tutorial_bar_rect`.

## The level intro

The briefing is the shared card (`GenericGameUtil.show_game_popup` -> `scripts/result_card.gd`),
the same one every other game uses, on its BRIEFING tone (cool header, "Start" on the button). It
replaced `show_text_popup` / `PopupText`, a fixed-size yellow panel that sized itself to its text
and so needed every line hand-wrapped with `\n`.

Two things follow from that and both matter when editing the text:

- **Prose is written as sentences.** The card wraps it. Hand-broken lines now come out as separate
  centered fragments.
- **A fact is written `Label: value`** and is set as a table row, label left and value right, with
  a hairline between adjacent facts. So the facts are grouped together, not scattered between the
  prose lines, or they end up as separate one-row tables.

Play still starts when the card closes, now via `MainGlobals.sig_game_popup_closed` (connected
once, guarded with `is_connected`) instead of the popup instance's own `closed` signal.

## What this game measures

Session records are the v6 named-dictionary format (see `scripts/generic_game_util.gd`
and `scripts/session_stats.gd`). Metrics reset centrally in `reset(from_scratch)`.

Response times are handed to the shared session record as a whole distribution, not just a mean: `game.record_times()` in `main.gd::get_game_score()` stores spread, median, within-session slope and lapse count beside the mean. The spread is the point — it moves before the mean does.

## Sounds

An ambient (`couples_ambient.ogg`, `devtools/make_ambient_sounds.py`: playful pizzicato and a music-box tune; it was a slow pad of drifting chords, heard as one irritating tone) plays while the board is up (`main.gd` `show_level`, -6 dB) and stops at the menu (`show_main_menu`). The game had no ambient before.

Made for this game by `devtools/make_answer_sounds.py` (synthesized, seeded; one timbre per family of
games): a bell chime for a right pair, a soft low bell note for a wrong one. They replaced an arcade coin and a swoosh shared by nearly every game in the app.

## The adaptive pace (2026-11-15)

The level's time limit (`show_time_sec`, the time to find the pair) is only where a player STARTS. Three right answers in a row shorten it by
`PACE_DOWN` (x0.85); any miss -- a wrong answer or a timeout -- lengthens it by `PACE_UP` (x1.20); it stays
between `PACE_MIN` (0.45) and `PACE_MAX` (1.5) times the level's value, and starts afresh with every level.
Not in the tutorial. So the game speeds up as the player gets better, instead of running everyone at one
fixed pace -- the engagement audit found this game "moves on by itself and never adapts". The same
staircase as Pinpoint's flash (`_adapt_pace` in `level.gd`, its own copy).

Because the staircase settles a player near 80% right wherever the time limit is what holds them back,
every level's `pass_pct` is AT MOST 75: a bar at 80% or more would fail a player for playing exactly where
the game puts them.

## The main menu's poster

`scripts/menu_world.gd` (`main.gd` `menu_backdrop()`), REAL 3-D on the shared `scripts/menu_poster3d.gd`: A NATURALIST'S
WORKTABLE AT NIGHT, seen across it (2026-11-20; the top-down scatter of 2026-11-18 was "boring" and ran under the menu,
and the card table in a parlor that followed -- green baize, chips, a card box, a decanter -- suggested gambling: the
user's rule, for every game, is to stay as far from anything that remotely suggests gambling as possible). A long oak
table of planks (`_planks`: boards each with its own tone, straight fibres drifting slowly, growth rings, knots, dark
seams -- on a PlaneMesh of its own, as a box spreads its texture over six faces) under a lamp, its edge rounded; at its
edges an ammonite (`_ammonite`: the whorls a logarithmic spiral crossed by ribs), two fossil brushes, a brass magnifier
and a field notebook with a pencil; beyond it the study -- a paneled wall under deep green plaster, a bookcase of old
volumes in worn leather with gilt bands, a fossil skull on a plinth and a globe in its meridian on the shelves, brass
sconces. On the table the game's own dino
cards (the shared card as old prints) in a 4 x 4 GRID, each lying flat in the table's perspective (`_card_xform`: an
affine map taken from the 3-D camera at its center); among them THREE COUPLES (`PAIRS`), found one after another
(2026-11-18, the user: more couples, and hardly a moment with none picked out): every `ROUND` (4.2 s) a pool of
light SEARCHES -- it glides (`SEARCH_GLIDE` 0.45 s) and rests (`SEARCH_REST` 0.3 s) on a card it glances at
(`GLANCE`), then on the couple's first, which lights, then on its second, which lights -- and the two rise and stand up
toward you side by side for most of the round, and lie back down as the next search begins. The light falls ON the
cards: the one under it is brightened (`_card_light`, through its modulate), and a found card keeps a soft gold halo
round its edge (`_halo`). (2026-11-20: the search hopped card to card in 0.1 s and its light lay under the cards, hidden
by them -- the user: "a brief flash ... too brief and minimal to understand".) A couple's two prints
are scorched on opposite sides here too. Baked (`menu_table.webp`, `menu_table_d.webp`); the cards load on threads. In the game the two copies' prints
never share a frame: each card's wear is its own random draw and their scorches go on opposite edges (`burn_side`).
Made up, never the board.

## Audio (2026-11-19)

the MENU has its own loop (`art/sounds/couples_menu_ambient.ogg`, `devtools/make_ambient_sounds.py` `couples_menu`): the game's music with the poster's world in front -- a clock ticking, cards turned; the GAME loop carries its world too, gentler (`GAME_WORLDS`): a clock ticking softly; new action sounds (`devtools/make_game_sounds.py`): `flip` on a tapped card.
