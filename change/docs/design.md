# Change — design

## Overview
Change is a **make-exact-payment** game. Each board shows a **target amount** to pay and a
**pile of overlapping coins**. The player **drags** coins from the pile into a **tray**, then
presses **Pay**; the sum of the coins in the tray is checked against the target. There is no
running total shown for the tray — the player must judge it themselves. A board **always has at
least one exact solution** (the target is generated as the sum of a subset of the coins on the
board). Modeled on Couples/Dino: top timeout bar, per-board and per-level time budgets, phase
machine, scoring and level flow.

## File structure
```
change/
├── scripts/
│   ├── globals.gd       # ChangeG autoload: game util + settings
│   ├── level_config.gd  # ChangeLevelConfig autoload: LEVELS array
│   ├── coin.gd          # a single drawn coin (Node2D, _draw); no real coin images
│   ├── level.gd         # gameplay: pile build, drag, tray, pay check, phases, scoring
│   └── main.gd          # orchestrator: menu, HUD, help, scores (mirrors couples/main.gd)
├── scenes/
│   ├── level.tscn       # CanvasLayer + level.gd (UI built in code)
│   └── main.tscn        # Main + Level + HUD + GameTick + Help
└── art/
    └── game_screen_200.png   # chooser tile: a pile of drawn coins on green felt
```
Coins are **drawn**, not images (`coin.gd`): a metallic disc (rim + face + inner disc + sheen)
with a value label. It's positioned at its **center**; the level moves it by setting `position`.

## Autoloads
- `ChangeG` — `game := GenericGameUtil.new("Change","change",0,2,0)`, settings save/load.
- `ChangeLevelConfig` — `LEVELS` + helpers (mirrors couples' config helpers).

## Coin denominations
`DENOMS = [0.01, 0.05, 0.10, 0.25, 0.50, 1.00]` (money value). Each has a **relative physical
size** `DENOM_REL` (a dime is smaller than a quarter, etc.) and a picking weight `DENOM_WEIGHT`
(fewer pennies/dollars). Color by kind: copper (1¢), silver (5/10/25/50¢), gold ($1). The
denomination is drawn **stacked** — big numeral with the unit symbol on its own line below it
(coin convention, like Euro coins): `5` over `¢`, `1` over `$`. Written amounts (the Pay target)
stay inline: `$1.35`. Actual drawn diameter = `coin_base * DENOM_REL[i]`, where `coin_base`
comes from the level's `coin_size` key.

## Level config params (per LEVELS entry)
| field | meaning |
|-------|---------|
| `id` / `name` | level id (monotonic) / display name |
| `coin_size` | `"big"` / `"med"` / `"small"` — base coin size (fraction of screen width: 0.20 / 0.155 / 0.122). Each denomination keeps its own relative size on top of this. |
| `board_time_sec` | seconds a board stays up before a non-answer = miss |
| `gap_sec` | blank pause between boards |
| `duration_sec` | level length; the level completes when it elapses |
| `num_coins` | total coins in the pile |
| `overlap` | `"none"` / `"med"` / `"max"` — how much piled coins cover each other |

## Gameplay flow
- **Pre-level popup** (`game.show_text_popup`, Storm-style): coins, board time, total time.
  Play starts when it closes (`closed` → `_on_game_popup_closed`).
- **Board build** (`_build_board`): pick a denomination per coin (weighted). Choose a **solution
  subset** (proper, non-trivial when `num_coins ≥ 3`: `2..num_coins-1` coins) and set the target
  = sum of that subset — so an exact answer always exists. Coins are created and placed.
- **Placement** (`_place_coins`): coins are dropped into the pile rect. `overlap` sets a
  min-center-distance as a fraction of summed radii — `none` ≈ 1.04 (rejection-sampled to avoid
  overlap, roomiest fallback), `med` ≈ 0.55, `max` ≈ 0.16 (heavy overlap, some coins fully
  hidden). Later coins get a higher `z_index` so they draw on top.
- **Dragging** (`_on_catcher_gui_input`): an invisible full-screen `Control` catches drags
  (coins are Node2D and take no GUI input). On press, the **topmost** coin under the point
  (highest `z_index`) is picked up and raised to the top; motion moves it (clamped to the
  play area); release drops it. **Mouse events only** (both touch↔mouse emulations are on).
- **"In the tray" clarity**: a coin counts as in the tray when its **center** is inside the tray
  rect. While dragging, such a coin shows a live **green halo** (`coin.set_in_tray`), and on
  release `_drop_coin` **snaps it fully inside** the tray (`_snap_into_tray` — clamped so the
  whole coin sits within the panel; centered on an axis if the tray is smaller than the coin).
  So there's no straddling-the-edge ambiguity.
- **Pay** (`_on_pay_pressed`): sum the values of coins whose **center is inside the tray rect**;
  correct if `abs(paid − target) < PAY_EPSILON` (0.005 — never plain `==`, avoids float error).
- **Phases** (`_process`, driven by `game.game_time`): IDLE → SHOW (pile up, timeout bar counts
  `board_time`) → FEEDBACK (shows the paid amount) → GAP → next board. Board timeout = miss.
  The feedback label has a rounded semi-transparent backdrop (`_size_feedback_to_text` shrinks
  it to hug the text, centered in the play area) so it stays readable over the coins.

## Layout (`_layout`, all platforms — no per-platform sizes)
Header → timeout bar → target amount + instruction → **pile** (top) → **tray** (bottom) → **Pay**
button → app bottom bar. The app bottom bar is anchored to the full-canvas bottom and is taller
on mobile (~70px) than `MainGlobals.footer_height` (40), so `bottom_reserve = max(20, bar_h −
footer + 10)` is subtracted; the Pay button sits just above it and the tray/pile fill the rest.
Coin base diameter is a fraction of screen width, so sizes scale with the screen; off mobile
(wider/shorter screens) all coins are scaled by an extra ×0.70 so they don't dominate.

## Scoring & progression
- Correct: `+15 + speed bonus`, `add_correct_or_mistake(1,0)`, coin sound.
- Wrong / timeout: small `-penalty` (capped at current score), `add_correct_or_mistake(0,1)`.
- **Level completes on `duration` elapsing** — `game.game_over_on_time_out = false`, so the
  clock running out fires `sig_time_over` → `_level_done(true)` (advance). Max level loops with
  no popup; otherwise a level-done popup with accuracy + mean time.
- Score row: `[didwin, wasaborted, level_id, mean_response_time_ms, pct_correct]`.

## Key pitfalls
- **Always solvable**: the target is derived FROM the coins present (sum of a subset), never
  chosen independently — do not change that or a board could become impossible.
- **Epsilon compare** for Pay: `abs(paid − target) < 0.005`, never `==` (float rounding).
- `game_over_on_time_out` stays **false**: `duration` is a per-level budget, not game-over.
- Layout is re-applied on popup close + a deferred `_layout()` in `new_game` (menu→level
  transition can run before the viewport settles — same fix as couples/dino). Coins are built
  only after the popup closes, so `_layout` never has to reposition an existing pile.
- **Drag uses mouse events only** (both mouse↔touch emulations are on); the invisible catcher
  Control keeps the drag through release (Godot mouse-focus capture) even over the Pay button.

## Tutorial

Coached tutorial in `change/scripts/tutorial.gd`; see `docs/tutorials.md` for the framework.

- **Entry**: `main.gd::_ready` consumes `MainGlobals.pending_tutorial` via `take_pending_tutorial("change")`
  and defers `start_tutorial`, which calls `game.begin_tutorial()` **before** `new_game()` (that runs
  `game.reset(true)` -> `convert_ongoing_score_to_permanent()`, which would commit the player's
  unfinished real session). `ChangeG.starting_level_id` is saved/restored by hand — it lives on the
  autoload, not on the `GenericGameUtil` instance, so the tutorial snapshot does not cover it.
- **Hooks in `level.gd`** (all no-ops outside tutorial mode): `_show_board` emits `board_shown`;
  `_drop_coin` emits `coin_in_tray` / `coin_out_of_tray`; `_resolve` emits `paid`, `paid_correct`,
  `paid_wrong`.
- **`_forced_boards`**: a normally-empty queue of fixed boards consumed one per round, taken from
  `tutorial.gd::tutorial_boards()`. The coach names an exact amount ("put 35 cents in the tray"),
  and only a fixed board can promise that amount is actually payable with the coins on screen. The
  boards live in `tutorial.gd` next to the text that names them so the two cannot drift apart.
- Board 1 is `overlap: none` so the coins are readable while the drag/tray/Pay loop is learned;
  board 2 is `overlap: max` specifically to teach that coins hide underneath each other, and the
  player **pays it unaided** — the piled board was previously only described across two frozen
  talking steps, so they were shown a heap, told to dig through it, and never given a chance to
  touch it. The tutorial now hands that board over as a real exercise.
- The probe checks both factual claims the captions make about these boards: that each stated
  target is reachable as a subset of the coins on the board, and that `overlap: max` genuinely
  buries at least one coin (otherwise "there are more coins here than you can see" is false).
- The level's intro popup is skipped in tutorial mode, and `board_time_ms` is stretched to 180 s
  because the timeout bar is being explained rather than raced.

### Tutorial: caption placement

The board fills the screen top to bottom — pile, tray, PAY — so a caption docked at the bottom sat
on 94% of the tray on the very step that says to put coins in it, and the player could neither see
the tray nor drag into it. `main.gd` passes all three rects as the runner's `keep_clear`, which
pushes the caption into the band above the pile on player-action steps. Talking steps still dock
low: the board is frozen there and nothing under the caption can be reached.

### Tutorial: the "look underneath" step

It says "drag the top ones aside", so it has to be a doing step. As a talking step the board was
frozen: the drag could not happen, and the press that began it dismissed the caption — so trying to
do what the coach asked skipped straight to the payment step. It now waits on `coin_moved`, which
`_drop_coin` fires wherever the coin ends up.

### Tutorial: paying the named amount

Three things stopped the coach's stated amount from being payable:

- Step 4 says "drag **a** coin into the tray", and whatever the player dragged was still there when
  step 6 said "put in exactly 35 cents". With the 5c in the tray, paying 25+10 came to 40c and was
  rejected — the player followed the instruction exactly and was marked wrong. Step 6's `setup`
  now calls `tutorial_clear_tray()`, and step 5 teaches dragging a coin back *out*.
- The payment steps waited on `paid`, which `_resolve` fires for a wrong payment too, so pressing
  PAY with anything in the tray advanced the coach to the next pile. They now wait on
  `paid_correct`.
- That could have hung, since a missed board is normally replaced. In `tutorial_mode` `_resolve`
  pushes the board's spec back onto `_forced_boards`, so the same pile returns and the player
  retries against the amount the caption still names.

`_tutorial_setup()` also cuts `gap_ms` (1000 -> 200) and `feedback_ms` (1200 -> 500) so "Another
pile." is not followed by a second of nothing. `_load_level` restores both.
