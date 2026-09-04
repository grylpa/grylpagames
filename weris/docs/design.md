# Weris — Game Design & Implementation Document

## Overview

**Game name:** Weris
**Folder:** `weris/`
**Singleton:** `WerisG`
**Save key (short name):** `weris`
**Initial time:** 5 minutes
**Background color:** `0x3C5D3EFF` (same dark green as OOO / Friends)

Weris is a face-recognition speed game. The player studies one person (with their name), then must find that person in a growing grid of faces as fast as possible — without any name labels. It trains detection speed, which can later be tracked via response-time reports.

---

## File Structure

```
weris/
├── docs/
│   └── design.md           ← this file
├── scripts/
│   ├── globals.gd            + globals.gd.uid
│   ├── main.gd               + main.gd.uid
│   ├── level.gd              + level.gd.uid
│   └── card.gd               + card.gd.uid
└── scenes/
    ├── main.tscn
    ├── level.tscn
    └── card.tscn
```

**Art dependency:** People images are loaded from `res://friends/art/people/` and the card border uses `res://friends/art/zig1.png` (intentional cross-game reference — weris reuses the same friends art assets). No local art copies.

**Self-containment:** All scripts and scenes are in `weris/`. The only external references are to top-level shared resources (`res://scenes/`, `res://scenes/in_game_yellow_button.tres`, `res://friends/art/`) and the required shared singletons.

---

## UIDs

| File | UID |
|------|-----|
| `scripts/globals.gd` | `uid://wer0a1b2c3d4n` |
| `scripts/main.gd` | `uid://wer2a3b4c5d6f` |
| `scripts/level.gd` | `uid://wer4a5b6c7d8h` |
| `scripts/card.gd` | `uid://wer6a7b8c9d0j` |
| `scenes/main.tscn` | `uid://wer1a2b3c4d5e` |
| `scenes/level.tscn` | `uid://wer3a4b5c6d7g` |
| `scenes/card.tscn` | `uid://wer5a6b7c8d9i` |

---

## Registration (files outside weris/ that were modified)

### `project.godot`
Added autoload entry after `StormG`:
```
WerisG="*res://weris/scripts/globals.gd"
```

### `scripts/config.gd`
Added entry at end of games array:
```gdscript
["weris", "Weris", "Memorize a person, then find them in a crowd as fast as you can"],
```

---

## Scene Structure

### `scenes/main.tscn`
Root node `Main` (Node, main.gd). Children:
- `Level` — instance of `level.tscn` (CanvasLayer)
- `HUD` — instance of `res://scenes/generic_game_hud.tscn`
- `GameTick` — Timer, wait=0.05s, autostart
- `Help` — instance of `res://scenes/help.tscn`, unique_name_in_owner, hidden

Connections:
- `HUD.start_game` → `_on_hud_start_game`
- `GameTick.timeout` → `_on_game_tick_timeout`

### `scenes/level.tscn`
Root node `Level` (CanvasLayer, level.gd). Static children:
- `TextureRect` — tiled grass background (`res://friends/art/grass.png`, fills screen)
- `InstructionsLabel` — shows "This is {name}" during study phase (z_index=5, font_size=34), at offset_top=116 to offset_bottom=162, hidden by default
- `FindLabel` — shows "Where is {name}?" during find phase (z_index=5, font_size=28), same position as InstructionsLabel, hidden by default
- `FeedbackLabel` — centered feedback ("Correct!" / "Wrong person!"), z_index=10, hidden by default
- `CountdownLabel` — large countdown number (z_index=5, offset_right=680, offset_bottom=70, font_size=60); position.y is set dynamically in code, hidden by default

Cards are instantiated dynamically at runtime. No StudyButton.

### `scenes/card.tscn`
Root: `Node2D` (card.gd) — matches friends' resizeable_card structure.
- `Container` — Control, anchors_preset=5 (CENTER_TOP), mouse_filter=STOP. Card is horizontally centered at Node2D.position.x.
  - `GlobalMarginContainer` — MarginContainer (uid=30003), anchors_preset=5, offset_left=-118, offset_right=118, offset_bottom=334. Unscaled size = 236×334. The whole Node2D is scaled via `scale = Vector2(sf, sf)` to resize the card.
    - `NinePatchRect` — fills GlobalMarginContainer (size_flags h=3,v=3), `res://friends/art/zig1.png`, yellow tint `self_modulate=Color(1,0.8,0,1)`, patch_margin=4, axis_stretch=TILE_FIT(2). Provides zigzag yellow border.
    - `ContentLayer` — plain Control (size_flags h=3,v=3), fills GlobalMarginContainer. Children use anchor layout relative to ContentLayer.
      - `TextureRect` — unique_name_in_owner=true, anchors_preset=15 with 6px offset inset on all sides (fills 224×322), stretch_mode=KEEP_ASPECT_COVERED (6). Image always fills the inner area.
      - `NameLabel` — unique_name_in_owner=true, anchor_top=1/anchor_bottom=1 (bottom-anchored), offset_top=-52/offset_bottom=-6 (bottom 46px strip). Yellow StyleBoxFlat, bold font (font_size=40, LabelSettings font_size=46). Hidden by default; overlaid on image when visible (study mode).

When `NameLabel.visible=false` (find mode): TextureRect fills full inner area — NameLabel visibility has no effect on TextureRect size since they use anchor layout, not VBox. When visible (study mode): NameLabel overlays the bottom strip of the image.

**Card sizing API (card.gd):**
- `set_width(w)`: sets `scale = Vector2(w/236, w/236)`, proportional scaling
- `setup(idx, show_name)`: loads image + name, shows/hides NameLabel
- `scaled_h()`: returns `334 * scale_factor`
- `UNSCALED_W = 236.0`, `UNSCALED_H = 334.0`
- Click detection via `_unhandled_input` + Rect2 hit test: `Rect2(position.x - sw/2, position.y, sw, sh)`

**Positioning in CanvasLayer:**
- Node2D.position.x = horizontal center of the card
- Node2D.position.y = top edge of the card

---

## People Data

50 people loaded from `res://friends/art/people/{name}.jpg`. Same list as `FriendsG`. Names are stored with underscores-to-spaces conversion and `.capitalize()`. WerisG maintains a shuffled index array so different people appear in different orders each game.

---

## Gameplay Design

### Config Variables (in `WerisG` / `globals.gd`)

| Variable | Default | Description |
|----------|---------|-------------|
| `starting_difficulty` | 1 | Initial difficulty level |
| `study_time_sec` | 10 | Seconds to study the target person (auto-advances, no player interaction). Updated per difficulty in `increase_difficulty()`. |
| `find_time_sec` | 30 | Time limit to find the person in the grid |

### Phase Flow

Each round has three phases managed by `Phase` enum in level.gd:

```
STUDY → FIND → FEEDBACK → STUDY → ...
```

#### STUDY Phase
1. Pick a random `target_idx` from the people pool
2. Instantiate a large study card centered on screen, showing image + first name
3. Show `InstructionsLabel` (person's first name) and `CountdownLabel` below the card
4. Countdown auto-advances to FIND when it reaches 0; player cannot skip
5. Countdown updated every tick: `ceili((study_time_sec*1000 - elapsed) / 1000.0)`

Study card sizing:
- `avail_h = screen_h - (LABEL_BOTTOM+4) - buttons_h - 70 - 20` (70 for countdown label, 20 for gaps)
- `card_w = int(min(screen_w * 0.45, avail_h * 236/334))`
- `card_h = int(card_w * 334/236)` — from the unscaled 236×334 aspect ratio
- Position: Node2D at `(screen_w/2, LABEL_BOTTOM+4)` — horizontally centered, top at label bottom
- CountdownLabel.position.y = LABEL_BOTTOM + 4 + card_h + 28

#### FIND Phase
1. Remove study card, hide countdown, show `FindLabel` ("Find this person!")
2. Create `grid_cols × grid_rows` cards without names
3. One cell holds `target_idx` at a random position
4. Remaining cells hold random distinct people (no duplicates, no target)
5. Player taps a card → `_on_find_card_pressed`
6. Auto-timeout after `WerisG.find_time_sec * 1000` ms (checked in `tick()`)

Grid sizing:
- Usable top: `LABEL_BOTTOM + 4 = 166`
- `card_h_from_rows = int((usable_h - CARD_GAP*(rows-1)) / rows)`
- `card_w = int(card_h_from_rows * 236/334)` — height-first portrait ratio
- If `card_w > card_w_from_cols`: width-constrained, recalculate `card_h = int(card_w * 334/236)`
- Grid centered horizontally and vertically in usable area
- Card Node2D positioned at center-x of each cell: `start_x = (screen_w - total_grid_w)/2 + card_w/2`

#### FEEDBACK Phase
1. All cards cleared, feedback message shown for `FEEDBACK_DURATION_MS` (1500ms)
2. Then: if level completion condition met → `level_is_done(true)`; otherwise → new STUDY phase

---

## Scoring

### Correct find:
- Speed bonus: `max(1, 10 - int(elapsed_ms / 200))` → 1 to 10 points
- +15s time
- `num_corrects_in_level_so_far += 1`
- Response time recorded in `times_to_answer` array (last 20 kept, for future speed report)
- Sound: `res://art/sounds/FreeSFX/GameSFX/PickUp/Retro PickUp Coin 07.ogg`

### Wrong tap or timeout:
- -1 score
- -5s time
- +1 mistake counter
- Sound: `res://art/sounds/swoosh.mp3`

---

## Difficulty Scaling

| d | Grid | Corrects to level | Study time |
|---|------|-------------------|------------|
| 1 | 2×2 (4 faces) | 3 | 5s |
| 2 | 3×2 (6 faces) | 5 | 4s |
| 3 | 3×3 (9 faces) | 5 | 3s |
| 4 | 4×3 (12 faces) | 10 | 3s |
| 5 | 4×4 (16 faces) | 10 | 2s |
| 6 | 5×4 (20 faces) | 15 | 2s |

`WerisG.study_time_sec` is updated by `increase_difficulty()` in level.gd.

---

## Score Saving Behavior

- When the player presses 'm' to go to the main menu: `_on_level_show_main_menu` calls `_save_ongoing_score()` then `game.convert_ongoing_score_to_permanent()` — score is saved immediately (no continuation from main menu)
- Periodic auto-save every 60s via `game.save_ongoing_score()` during gameplay
- Both `save_ongoing_score` and `save_score` are gated on `game.score_was_changed` (set in `GenericGameUtil.add_score_and_time` when `score != initial_score`). Scores at the unchanged initial value are never written to disk.

**Last-level loop (level 6):** At max difficulty, completing the required finds saves the score silently via `game.sig_level_is_done` and immediately restarts at level 6 — no popup, no difficulty increase. `times_to_answer` is only cleared on a full new game (`from_scratch=true`), so the rolling average persists across loops.

The scores button in the bottom bar shows a small orange dot badge whenever a new score is saved (any game). The badge disappears when the player opens the scores table. This is handled by `scripts/bottom_option_buttons.gd` via `MainGlobals.sig_new_best_score` / `sig_scores_viewed` signals, and persists across sessions via a flag file `user://new_best_v1_weris.gpa`.

---

## Key Signals

| Signal | Direction | Purpose |
|--------|-----------|---------|-
| `Level.started_playing` | level → main | restart HUD timer |
| `Level.sig_level_is_done(bool)` | level → main | level complete → new game |
| `game.sig_game_is_done` | GenericGameUtil → main | game over |
| `game.sig_level_is_done` | GenericGameUtil → main | save ongoing score |

---

## Response Time Tracking

`level.gd` stores up to 20 most recent correct find times in `times_to_answer`. This data is kept in memory only (not persisted). `mean_time_to_answer_ms()` returns the average. This data is shown in the level-done popup and in the score record for future speed-report analysis.

Score row format: `[didwin, wasaborted, difficulty, mean_time_ms, pct_correct]`

`POS_SCORE_PCT_CORRECT = 8` — `pct_correct = int(100 * game.corrects / (game.corrects + game.mistakes))` across the full session. Enables the % Correct metric in the Chart tab.

---

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
misses that failed the level could not pass it even played perfectly. The timing list is the same argument applied to the card's "Average find time" row, and to the mean time `main.gd` writes into the score row.

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

## Recreating From Scratch

1. Create folder structure above
2. Write `globals.gd` — `GenericGameUtil.new("Weris", "weris", 0, 5, 0)` plus config vars and people loading
3. Write `card.gd` — `extends Node2D`; constants `UNSCALED_W=236, UNSCALED_H=334`; `setup(idx, show_name)`, `set_width(w)` sets uniform scale, `scaled_h()`; `_unhandled_input` with Rect2 hit test emits `card_pressed(person_idx)`
4. Write `level.gd` — three-phase STUDY/FIND/FEEDBACK state machine; `increase_difficulty()` sets `WerisG.study_time_sec` per level; card sizing uses CARD_W_UNSCALED=236/CARD_H_UNSCALED=334; countdown replaces study button
5. Write `main.gd` — identical pattern to other games, replace FriendsG with WerisG
6. Write `scenes/card.tscn` — Node2D root (card.gd); Container(Control, anchors_preset=5, mouse_filter=STOP); GlobalMarginContainer(236×334, anchors_preset=5, offset_left=-118, offset_right=118, offset_bottom=334); NinePatchRect (zig1.png, yellow tint, size_flags h=3,v=3, patch_margin=4, TILE_FIT) + InnerMargin (size_flags h=4,v=4, margin=6) as siblings; VBoxContainer → TextureRect (FILL+EXPAND, stretch_mode=2) + NameLabel (yellow StyleBoxFlat, bold, hidden)
7. Write `scenes/level.tscn` — CanvasLayer, grass background, InstructionsLabel/FindLabel at y=108-152, FeedbackLabel centered, CountdownLabel (font_size=60, offset_right=680, offset_bottom=70); no StudyButton
8. Write `scenes/main.tscn` — standard game main with GameTick
9. Add `WerisG="*res://weris/scripts/globals.gd"` to `project.godot` `[autoload]`
10. Add `["weris", "Weris", "...description...\"]` to `scripts/config.gd` games array

## The look

`_apply_look()`, called from `_ready()`. The board's ground is the drawn backdrop the rest of the
app uses (`scripts/screen_backdrop.gd`) in this game's own green — a gradient, a pool of light at
the top, slow dust and a vignette — in place of the tiled `res://art/grass.png` that every screen in
the app used to wear. The instruction, find and feedback labels take the app's prose font, and the
countdown takes the app's accent.

Nothing about the layout, the flow or the logic changed: only what it is made of.

## What this game measures

Session records are the v6 named-dictionary format (see `scripts/generic_game_util.gd`
and `scripts/session_stats.gd`). Metrics reset centrally in `reset(from_scratch)`.

Response times are handed to the shared session record as a whole distribution, not just a mean: `game.record_times()` in `main.gd::get_game_score()` stores spread, median, within-session slope and lapse count beside the mean. The spread is the point — it moves before the mean does.

Each find logs crowd size and time to the per-trial log; the Search panel fits the slope, which is the cost of each extra face and is steadier across sessions than raw speed. Failed and timed-out finds are excluded — they say nothing about search time.

The Search tab is always present. It needs 3 sessions and correct finds at two or more crowd sizes, 4+ each — the crowd grows with the level, so the message says so rather than leaving the player guessing.
