# Moving Cards — Game Design & Implementation Document

## Overview

**Game name:** Moving Cards
**Folder:** `movingcards/`
**Singleton:** `MovingCardsG`
**Save key (short name):** `movingcards`
**Initial time:** 5 minutes
**Background color:** `0xFF8A5CFF` (warm orange)

Moving Cards is a card memory game. The player sees cards face-up for a configurable display time, then they flip face-down and move around the screen. The player must click them in the memorized order. All parameters (number of cards, rounds per level, movement style, speed, display time) are set per level in `level_config.gd`.

---

## File Structure

```
movingcards/
├── docs/
│   └── design.md           ← this file
├── art/
│   └── CardBack1–9.png       (9 card back textures, shuffled each game)
├── scripts/
│   ├── level_config.gd       (MovingCardsLevelConfig — static per-level params)
│   ├── globals.gd            (MovingCardsG autoload)
│   ├── main.gd
│   ├── level.gd
│   ├── hud.gd
│   └── card.gd
└── scenes/
    ├── main.tscn
    ├── level.tscn
    ├── hud.tscn
    └── card.tscn
```

---

## Level Config (`MovingCardsLevelConfig.LEVELS`)

Each entry is a Dictionary with:

| Key | Type | Description |
|-----|------|-------------|
| `level` | int | Level number (for readability) |
| `num_cards` | int | Cards on the board |
| `moving_cards` | bool | Whether cards animate to new positions after display phase |
| `random_order` | bool | Cards numbered in random (non-sequential) order |
| `num_rounds` | int | Successful rounds required to advance difficulty |
| `display_time_ms` | int | Milliseconds cards are shown face-up before hiding |
| `speed_scale` | float | Multiplier on base 200 px/s movement speed |
| `movement_style` | String | `"random"` (freeform, no-overlap) or `"fixed"` (board-coord arrays) |

---

## Globals (`MovingCardsG`)

| Variable | Default | Description |
|----------|---------|-------------|
| `starting_difficulty` | 1 | Level index to start at (1-based) |
| `card_move_speed` | 200.0 | Current effective px/s (overwritten each level from config × speed_scale) |

Settings saved as `[starting_difficulty]`.

---

## Gameplay Flow

1. **Display phase**: All cards revealed face-up showing order numbers; displayed for `display_time_ms`.
2. **Movement phase** (if `moving_cards`): Cards hide and move one-by-one to new positions.
3. **Click phase**: Player clicks cards in the memorized order.
   - Correct click on last card → 2-second enjoy delay → `rounds_done++`
   - After `num_rounds` successes → difficulty advances, `sig_level_is_done` emitted (or silent loop at max level)
   - Wrong click → 1.5-second delay → same round retried (round not counted)
4. Rounds auto-cycle with no "Continue" button.

**Last-level loop (level 8):** At max difficulty, completing `num_rounds` successes saves the score silently (`update_score.emit` + `game.save_ongoing_score([])`) and immediately starts a new round — no popup, no difficulty increase.

---

## Random Movement Style

When `movement_style == "random"`, `level.gd` generates two independent sets of non-overlapping pixel positions (start and end) using rejection sampling:
- 300 attempts per card for start positions, 500 for end positions; returns empty on failure (falls back to "fixed")
- Minimum card-to-card separation: `CARD_SIZE + 32 = 112 px` (applies to start-start, end-end, and end-start pairs)
- End positions are also checked against all start positions to prevent cards from landing on each other's starting spots
- Margins: `TOP_MARGIN = 120 px`, `BOTTOM_MARGIN = 80 px`
- Cards move linearly from their random start to their random end position
- `_optimize_crossings` greedily swaps end positions to maximize path crossings; swaps are skipped if they would violate travel distance or separation constraints

**Sound effects:**
- Any card tap: `res://art/sounds/tap-1.mp3`
- Correct sequence complete: `res://art/sounds/FreeSFX/GameSFX/PickUp/Retro PickUp Coin 07.ogg`
- Wrong card tapped: `res://art/sounds/swoosh.mp3`

---

## Scoring

- +2 per correct card click (while `game.playing`)
- +`score_if_successful` (= 5 + 2 × difficulty) when a full difficulty level is completed
- −2 per clue used

---

## Main Menu

Single slider entry:
1. **Difficulty** (1–N levels) — controls which level config entry is used as starting level

Moving Cards and Random Order are forced on by the level config and not shown in the menu.

---

## Stats Screen

- **Scores tab**: Date | Score
- **Speed tab**: not available
- **Chart tab**: Score metric only; x-axis toggle available

---

## Score Persistence

Score row format: `[unixtime, score, time_left, times_run, didwin, wasaborted, difficulty]`

- `didwin` is always `false` (no natural game-over; session ends when returning to menu)
- `wasaborted` is always `true` for the same reason
- `difficulty` = the level reached when the player exited
