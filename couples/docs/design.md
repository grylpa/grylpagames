# Couples — design

## Overview
Couples is a **spot-the-pair** game. Each board is an **NC × NR grid** of dino cards.
Exactly **one image appears twice**; every other cell is a unique image. The player finds
the matching pair and **taps both cards**. Modeled on the Dino game — same dino pictures,
white zigzag card frame, dino background (`bk1.jpg`), phase machine, scoring and level flow.

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
Couples uses the **shared** `res://shared/scripts/card.gd` (zig NinePatch frame + image, thin
frame by default) in **FILL fit**: every card frame has a single uniform aspect
(`CARD_ASPECT = 566/374`, the max dino image height / max width) and the image is stretched to
fill it. The dino JPGs vary in aspect (~1.47–1.59), so ASPECT fit gave visibly different card
heights; FILL makes a tidy uniform grid with the whole image shown and no crop (the tiny
stretch is identical on both copies of the duplicate, so it's invisible for matching). It has
its own dino-image loader in `CouplesG` (no cross-*game* refs; the shared card is framework
code, not another game). Images
come from `CouplesG.dino_texture(idx)`, loaded from the **shared** `res://art/dinos` set
(dino1..N). Background is always the shared `res://art/dinos/bk1.jpg`. The zig frame texture
`res://art/zig1.png` is shared art too.

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
- **Pre-level popup** (`game.show_text_popup`, Storm-style): level, grid size, board time,
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
