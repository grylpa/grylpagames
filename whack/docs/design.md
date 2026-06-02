# Whack — Game Design & Implementation Document

## Overview

**Game name:** Whack
**Folder:** `whack/`
**Singleton:** `WhackG`
**Save key (short name):** `whack`
**Initial time:** 10 minutes
**Background color:** `res://art/grass.png` tiled TextureRect (shared default); clear color `0x3C5D3EFF` as fallback
**Initial score:** 100, `game_over_on_zero_score = true`

Whack is a reaction-speed and accuracy game. A circular target appears at a random position on the screen. The player must tap it as fast as possible before it disappears. Only taps whose center lands inside the target count as hits. Two metrics are tracked: reaction time (ms from appearance to tap) and accuracy (100 = center hit, 0 = edge hit).

---

## File Structure

```
whack/
├── docs/
│   └── design.md           ← this file
├── art/                    (empty — uses shared sounds only)
├── scripts/
│   ├── globals.gd            (WhackG autoload)
│   ├── level_config.gd       (WhackLevelConfig — per-level params array)
│   ├── main.gd
│   ├── level.gd
│   └── draw_area.gd          (Control subclass, draws target via _draw())
└── scenes/
    ├── main.tscn
    └── level.tscn
```

---

## Registration

### `project.godot` autoloads
```
WhackG="*res://whack/scripts/globals.gd"
```

### `scripts/config.gd`
```gdscript
["whack", "Whack", "Tap the target as fast and accurately as you can"],
```

---

## Scene Structure

### `scenes/main.tscn`
Root node `Main` (Node, `main.gd`). Children:
- `Level` — instance of `level.tscn` (CanvasLayer)
- `HUD` — instance of `res://scenes/generic_game_hud.tscn`
- `GameTick` — Timer, wait=0.05s, autostart
- `Help` — instance of `res://scenes/help.tscn`, hidden

### `scenes/level.tscn`
Root node `Level` (CanvasLayer, `level.gd`). One child:
- `DrawArea` (Control, `draw_area.gd`) — `mouse_filter=STOP`, fills viewport, handles both drawing and tap input

---

## Globals (`WhackG`)

| Variable | Default | Description |
|----------|---------|-------------|
| `starting_difficulty` | 1 | Starting difficulty (1–6) |

Settings saved as `[starting_difficulty]`.

---

## Difficulty Levels

Defined in `scripts/level_config.gd` (`WhackLevelConfig.LEVELS` array). Number of levels = array size. Each entry:

| Field | Description |
|-------|-------------|
| `radius` | Target radius in pixels |
| `interval_min_ms` | Minimum ms between targets |
| `interval_max_ms` | Maximum ms between targets |
| `show_ms` | Ms before target auto-disappears |
| `hits_to_complete` | Hits to advance to next level |

| Level | Radius (px) | Min (ms) | Max (ms) | Show (ms) | Hits |
|-------|-------------|----------|----------|-----------|------|
| 1     | 48          | 1000     | 2500     | 2000      | 10   |
| 2     | 40          | 900      | 2000     | 1500      | 12   |
| 3     | 33          | 800      | 1800     | 1000      | 12   |
| 4     | 27          | 700      | 1500     | 1000      | 15   |
| 5     | 22          | 600      | 1200     | 800       | 15   |
| 6     | 17          | 500      | 1000     | 700       | 20   |
| 7     | 10          | 500      | 1000     | 500       | 999  |

---

## Gameplay Flow

1. Target appears at a random position (avoiding HUD top area and bottom button bar, plus `radius + 12px` edge padding)
2. Player taps within the target area (`distance_to_center <= radius`) → hit
3. Tap outside the target area → miss (penalty, no target disappears)
4. Target times out if not tapped within `show_ms` → miss penalty, next target scheduled
5. After `corrects_for_next_level` hits: level advance popup, then next level (except at max level — see below)

**Last-level loop (level 7):** At max difficulty, completing 999 hits saves the score silently and immediately restarts at level 7 — no popup, no difficulty increase. Both `_reaction_times` and `_accuracies` (rolling windows of last 20) persist across loops so the saved avg reaction time and avg distance reflect a running average over recent rounds.

**Sound effects:**
- Appear: `res://art/sounds/click-2.mp3`
- Hit: `res://art/sounds/tap-1.mp3`
- Miss (out-of-area tap): `res://art/sounds/bump-sound-7.mp3` (no sound played — penalty only, sound suppressed to avoid spam on rapid tapping)
- Wrong (decoy hit / target timeout): `res://art/sounds/swoosh.mp3` (once per mistake event)

**Visual feedback:**
- Green flash at tap position on hit
- Red flash at tap position on miss
- Urgency orange ring around target when >70% of show time elapsed

---

## Scoring

- Hit (in-target tap): `+max(1, 20 - reaction_ms/200)` score, `+10s` time
- Miss (out-of-target tap): `−3` score, `−3s` time
- Timeout (target disappears unhit): `−5` score, `−5s` time
- `game_over_on_zero_score = true`

**Distance metric:** raw pixel distance from tap center to target center, for successful hits only.
- 0 = perfect center hit
- Values up to `radius` (e.g. 0–48 px at level 1)
- Out-of-target taps do not affect the distance average

**Reaction time:** time from target appearance to valid (in-target) tap, in ms. Stored per hit. Mean over last 20 hits used for stats.

---

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
| 7 | mean_reaction_ms (POS_SCORE_MEAN_REACTION_MS = 7) |
| 8 | mean_dist_px (POS_SCORE_MEAN_DIST_PX = 8) |

---

## Stats Screen

- **Scores tab**: Date | Score | Level
- **Speed tab**: grouped by level, shows avg reaction time and avg distance (px)
- **Chart tab**: Score, Avg Reaction Time, Avg Dist; x-axis toggle available

**Bottom bar in main menu:** help (`h`), mute (`t`), scores (`o`) buttons.

---

## Main Menu

One slider entry:
1. **Difficulty** (1–6) — starting level

---

## Shared System Notes

See `rlmadness/docs/design.md` → "Shared system changes" for details on:
- Chart tab design and x-axis toggle
- `score_was_changed` save gate
- Per-level saves: `save_score` is called at each level completion so the speed table shows all levels played within a session, not just the final one
- Monotonic mode, % Correct column
