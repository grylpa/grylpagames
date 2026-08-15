# Dino — design

## Overview
Dino is a **continuous recognition-memory** game. One image card appears at a time.
The player decides whether they have **already seen that card earlier in the current
round** (swipe RIGHT / "Seen" button) or whether it is **new this round** (swipe LEFT /
"New" button). A card left unanswered past its time limit counts as a miss. Each level
runs for a fixed duration and then completes, advancing to the next level.

The cards are photographs drawn from one or more image folders (`dinos`, `people`).
Every card has a zigzag ("non-definitive") border — **white for dinos, yellow for
people** — exactly like the weris card border.

## File structure
```
dino/
├── scripts/
│   ├── globals.gd       # DinoG autoload: image-source loading, settings, GenericGameUtil
│   ├── level_config.gd  # DinoLevelConfig autoload: per-level params (LEVELS array)
│   ├── card.gd          # code-built card: zig NinePatch border + image (no .tscn)
│   ├── level.gd         # gameplay: pool, sequence, phases, swipe/buttons, scoring
│   └── main.gd          # orchestrator: menu, HUD, help, score/progress wiring
├── scenes/
│   ├── level.tscn       # CanvasLayer + level.gd (all UI built in code)
│   └── main.tscn        # Main + Level + HUD + GameTick + Help
└── art/
    └── game_screen_200.png   # chooser tile (REQUIRED; see "Pending")
```
Backgrounds are **shared** assets: `res://art/dinos/bk1.jpg` (used only when a level's
source includes `dinos`) and `res://art/grass.png` (the weris background, used otherwise).
Card border texture is the shared `res://art/zig1.png`.

## Autoloads
- `DinoG` (`dino/scripts/globals.gd`) — owns `game := GenericGameUtil.new("Dino","dino",0,2,0)`,
  loads image folders (export-safe: dinos probed as `dino1..N` via `ResourceLoader.exists`,
  people from an explicit shared name list — DirAccess can't enumerate res:// images in
  exports), per-folder default border colors, background selection, settings save/load.
- `DinoLevelConfig` (`dino/scripts/level_config.gd`) — `LEVELS` array + helpers.

## Level config params (per LEVELS entry)
| field | meaning |
|-------|---------|
| `name` | compact label ("5 DP") for the HUD, scores table and chart legend — all three are narrow |
| `menu_name` | descriptive name for the level **dropdown** only, where there is room (" 5 Dinos+faces"). Ordered by difficulty so choosing a starting level does not mean decoding "6 D". Space-padded so the ids line up in the dropdown's mono font; `menu_names()` falls back to `name` |
| `card_size` | "small" \| "med" \| "big" — on-screen card size |
| `card_time_sec` | seconds a card is shown before a non-answer = miss |
| `gap_sec` | blank pause between cards |
| `start_cards` | working-set size at round start (the difficulty lever) |
| `new_after` | a new image is unlocked each time a card has been shown this many times (default 2 → ~50/50 new/seen) |
| `duration_sec` | level length; the level completes when it elapses |
| `source` | folder(s): `"dinos"`, `"people"`, or a comma list `"dinos,people"` |
| `border_colors` | optional; one Color per folder (same length). Omitted → per-folder default (dinos=white, people=yellow) |

**Multi-folder selection:** when `source` lists more than one folder, each new distinct
card first picks a **folder with equal probability**, then a random unused image within
that folder. Each card carries its own border color (its folder's). Background = dino bg
if any folder is `dinos`, else grass.

## Gameplay flow
- **Pre-level popup** (`game.show_text_popup`, the Storm-style centered "tap anywhere to
  start" panel), built by `_intro_text()`. It opens with **what you are about to be shown**
  (`Cards: Dinos and faces` — `_folders_phrase()` says "faces", not the folder name "people"),
  then the rule in full, the swipe directions, and the duration. Play + countdown start when it
  closes (its `closed` signal → `_on_game_popup_closed`). `show_text_popup` is a reusable
  `GenericGameUtil` wrapper over `MainGlobals.generic_text_popup()` (`PopupText`); it sizes to its
  text, so format with short `\n` lines (no auto-wrap).
  **Card time is deliberately not listed**: it is a timeout, not something to plan around, and the
  per-card bar under the header shows it far better than a number in a panel already dismissed.
- **The HUD shows `Level 5`, just the number.** It used to show `"Level " + name` — i.e.
  `Level 5 DP` — which leaked the scores-table shorthand onto the play screen where it read as a
  code, and what it encoded (which folders the cards come from) is already visible in the cards.
- **Adaptive card set** (rate-resistant; replaces a fixed pool): the working set starts at
  `start_cards` and grows by one image for every card that has been shown `new_after` times
  ("seen twice → add a card"). New images are drawn from the folder(s) (`_folder_avail`,
  equal folder probability), repeats prefer below-threshold cards (to drive unlocks),
  ~50/50 interleave, immediate duplicates avoided. Because new images keep flowing from the
  folder, the mix never collapses to all-"seen" and self-paces to the player's speed; the
  only cap is the number of images the folder(s) hold (`_folder_avail` empties). Verified by
  simulation: ~47–48% "seen" across 15/30/60-card rounds, balanced even in the last 10 cards.
  Correctness = `(player said "seen") == was_seen`.
- **Phases** (`_process`, driven by `game.game_time`): IDLE → SHOW (card up, awaiting
  answer, with `card_time` timeout) → FEEDBACK (brief "Correct/Wrong/Too slow") → GAP →
  next card.
- **Answering**: swipe (press/release horizontal delta ≥ 60px and > vertical; right=seen,
  left=new) or the on-screen **New/Seen** buttons (left=New, right=Seen, matching swipe
  directions). A tap doesn't reach the swipe threshold, so button taps pass through.
- **Timeout bar**: a per-image bar (`_bar_track`/`_bar_fill`) sits just under the header,
  above the level number, and depletes (green→red) over `card_time` during SHOW; hidden in
  FEEDBACK/GAP/IDLE. The HUD level-number label is moved down (main.gd sets its offsets to
  y≈92-132) so the bar fits between the header and it.

## Main menu

The level row's caption is **"Level"**, not "Starting level". The caption's minimum width is
subtracted from the dropdown's, and at "Starting level" the dropdown got only 282 px of a 600 px
row — 13 characters in the mono face the shared menu uses for numbered lists. "Level" leaves
**465 px**, enough for the widest `menu_name` (432 px) at the full theme font size.
`main_menu._fit_option_font` shrinks the mono size only if a list still would not fit.

## Bottom bar
Dino calls `MainGlobals.update_bottom_bar([...], Color.YELLOW, true)` — the 3rd arg is the
new **reversed theme** flag. The bar itself stays fully transparent; the flag flips the
individual buttons to a dark theme (near-black content over a darker translucent button
background) so they stay readable over dino's light background. It's passed on every
`update_bottom_bar` call (default `false`), so it auto-resets to normal for other games and
on the game chooser. Implemented in `scripts/bottom_option_buttons.gd` (`reversed_theme`,
`_apply_button_bg`, `_REV_*` colors).

## Backgrounds
- **Always** `res://art/dinos/bk1.jpg` (`STRETCH_KEEP_ASPECT_COVERED`), for every source
  including people-only levels (`DinoG.background_for` ignores the folders). The `_load_level`
  code still picks `STRETCH_TILE` for a grass background, but grass is no longer selected.

## Scoring & progression
- Correct: `+10 + speed bonus`, `add_correct_or_mistake(1,0)`, "correct" sound.
- Wrong / timeout: small `-penalty` (capped at current score), `add_correct_or_mistake(0,1)`,
  "wrong" sound.
- Per-level stats reset every level (HUD hits/misses, accuracy, mean response time).
- **Level completes on `duration` elapsing** — `game.game_over_on_time_out = false`, so the
  per-level clock running out fires `sig_time_over` → `_level_done(true)` (advance) rather
  than ending the game. Monotonic level counter (`need_to_increase_level`), level-done popup
  with accuracy + mean time (ptbits pattern); the max level loops with no popup.
- Score row: `[didwin, wasaborted, level_id, mean_response_time_ms, pct_correct]`
  (`POS_SCORE_LEVEL_ID=6`, `MEAN_TIME=7`, `PCT=8`); scores screen shows level name.

## Key pitfalls
- `game_over_on_time_out` must stay **false**: the duration is a per-level budget, not a
  game-over. `_on_time_over` / `_level_done` guard on `game.level_is_done` because the HUD
  keeps firing `sig_time_over` each second once the clock is at 0.
- Card is a `Node2D` added to the CanvasLayer; all its visual children have
  `mouse_filter = IGNORE` so they never eat a swipe. Swipe input is handled in `level._input`.
- **Card sizing is done in actual pixels** (`card.gd` sets the NinePatch/TextureRect sizes
  directly, Node2D scale stays 1). Do NOT size the card via `Node2D.scale` of a bare Control:
  a Control under a Node2D gets its size reset to the viewport (680) on tree-entry, so the
  scale then blows it up far past the screen. Anchors are pinned top-left as insurance.
- **Full image, no crop**: the frame is sized to each image's own aspect ratio
  (`card.setup` reads `tex.get_size()`), and the image uses `STRETCH_SCALE` — so the whole
  image fills the frame with no cropping. `level._show_next_card` fits the card into the
  available area using that aspect and the level's size fraction (small/med/big = 0.56/0.78/0.98
  of the largest fittable card, so they differ clearly). Frame = 8px zig nine-patch.
- Image sources must be probed with `ResourceLoader.exists` (export-safe), never DirAccess.
- **No ghost answers across rounds**: a swipe must BEGIN during the current card, so press
  state (`_pressing`/`_press_index`) is reset in `_show_next_card`, `new_game`, and
  `stop_level`; `_register_answer` also ignores an input answer in the first 150 ms of SHOW.
  `main._on_level_show_main_menu` calls `$Level.stop_level()` so a half-shown card/answer
  never leaks into the next round.

## Tutorial

Dino is the first game with a coached tutorial (`dino/scripts/tutorial.gd`). See
`docs/tutorials.md` for the framework; what is specific to Dino:

- **Entry**: the chooser's "How to play" picker sets `MainGlobals.pending_tutorial`, and
  `main.gd::_ready` consumes it via `take_pending_tutorial("dino")` and defers `start_tutorial`.
- `start_tutorial` calls `game.begin_tutorial()` **before** `new_game()`. `new_game()` runs
  `game.reset(true)` → `convert_ongoing_score_to_permanent()`, which would otherwise commit and
  upload whatever unfinished real session the player had going.
- `DinoG.starting_level_id` lives on the autoload, not on the `GenericGameUtil` instance, so it is
  **not** covered by the tutorial snapshot. `start_tutorial` saves it into `_tutorial_saved_level`
  and `_on_tutorial_done` puts it back — without that, taking a tutorial silently rewrites the
  player's chosen starting level to 1.
- **Hooks in `level.gd`** (all no-ops outside tutorial mode): `_show_next_card` emits
  `card_shown` plus `card_shown_new` / `card_shown_seen`; `_register_answer` emits `answered`
  plus `answered_correct` / `answered_wrong`.
- **`_forced_picks`**: a normally-empty array of `"new"` / `"repeat"` consumed one per card at the
  top of `_pick_next`. The lesson needs a card the player has demonstrably seen before, and the
  adaptive picker would only get there by luck. `_tutorial_setup()` sets it to
  `["new", "new", "repeat"]` and raises `card_time_ms` to 20 s, because the drain bar is being
  *explained* and must not expire while the coach talks about it.
- The level's own intro popup is **skipped** in tutorial mode — the tutorial teaches the same
  things, and showing both makes the player dismiss a wall of text before being taught it.
- **`_answered_without_buttons`** records how the current answer was given — set by `_try_swipe`
  and by the arrow keys, cleared by the two button handlers and by every new card. It exists only
  so the tutorial can tell the two input methods apart; `_register_answer` reports
  `answered_without_buttons` / `answered_by_button` alongside the generic `answered`.
- The lesson order follows what first-timers actually get wrong: "seen" meaning *this round*
  first; then the **buttons**, which always work; then the **drag** as its own lesson the player
  must actually perform (the step waits on `answered_without_buttons`, so tapping New again does
  not satisfy it — a passing mention is what left players never discovering the gesture, and a
  hesitant drag under the 60 px threshold does nothing at all, which the hint names); then the
  drain bar as a deadline.

## Pending
- `dino/art/game_screen_200.png` (the chooser tile) is not yet created. Until it exists the
  chooser logs a "Resource file not found" error and the Dino tile has no image. Decide the
  thumbnail source (a dino image, or a custom tile).
