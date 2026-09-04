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

## A level is a fixed number of rounds, and can be failed

`num_rounds` counts rounds PLAYED. It used to count only the successful ones — a wrong answer just
restarted the round without counting it — so the level could not be failed, it always ended on a
win, and there was nothing for an accuracy gate to measure. All eight values were doubled when this
changed, since a level of "6 rounds however they go" is a shorter sitting than "3 rounds you must
win".

`_finish_round(was_correct)` is now the single place a round ends, called from both the wrong-card
branch and the last-correct-card branch. When `rounds_done_this_level` reaches `num_rounds` it
works out the accuracy and emits `sig_level_is_done(passed, pct, bonus)`.

Each level carries a **`pass_pct`** chosen to be exactly reachable in that many rounds — 3/6, 4/6,
6/8, 8/10 — so the number on the card is the number required. Recheck them if `num_rounds` changes.

## The level card

Before this, a level ended by silently becoming the next one: a transient "Level Up!" flash from
the HUD and nothing else. `main.gd` now shows the shared level card
(`GenericGameUtil.show_level_done_popup`), the same one every other game uses, saying either
"on to level N" or what accuracy was needed. Play resumes when it closes, into the next level or
into the same one again.

A failed level earns nothing: the bonus is only added on a pass, and the score row written at that
moment holds the kept score, while the screen keeps showing what the player had until they press
Continue (`mark_score_rollback` / `continue_after_level`).

The HUD's `game_over()` is gone — it only ever showed that "Level Up!" flash, and the card replaces
it. This game still has no losing state; nothing ends it.

## Cards travel an arc

`card.begin_move(from, to, bow)` bows the path sideways, deepest at the halfway point, `sin()`
being zero at both ends so the card still starts and finishes exactly on the positions the level
laid out. The bow is proportional to the trip (10..40px) and its direction is random.

`Level._bow_for()` picks it, because the level is the only thing that knows the margins: it tests
the arc's deepest point against the playable rect and flips the bow, or drops it to zero, rather
than letting a curve carry a card into the header or off the side. Only ONE card moves at a time,
so a bowed path cannot collide with another card.

## The HUD is the shared one

This game had its OWN HUD (`movingcards/scenes/hud.tscn`, now deleted), which is why it had no
correct/wrong counters and never showed the shared game-over screen. The apparent reason for the
fork was that its instruction line ("ORDER: 3,1,2") has to sit at the TOP while the board is
visible, and the shared HUD's `Message` is center-screen — it is the game-over banner slot.

That was not a reason: deliverem and delemfp put their persistent top line in `hud.dispatch()`, and
so does this game now.

What WAS real is that `Dispatch` and the correct/wrong counters are both anchored top-center and
their rects overlap — counters (256,0)-(424,60), dispatch (216,3)-(463,53). No game had ever hit it
because none used both: the 14 games that dispatch never show counters, and none of the 22 that
show counters dispatch.

`GenericGameHud._sync_top_strip()` drops the LINE below the counters when a game shows both. The
line moves and the counters do not, because the counters are level state — a running tally watched
across the whole level — while the line is per round. Letting the line take precedence and hide
them was tried, and it made the tally blink out and back on every single round, which is worse than
a line sitting 60px lower.

A game that never shows counters is completely unaffected: its line stays at y=3, exactly where the
scene puts it.

`TOP_MARGIN` is 130 — score and counters at y 0..60, the line at 65..115, and a card's top edge starts at 136.

The counters are fed by `_finish_round` and cleared per level, like every other graded game, and
`uses_session_clock = false` hides a countdown that nothing here ever runs.

## What this game measures

Session records are the v6 named-dictionary format (see `scripts/generic_game_util.gd`
and `scripts/session_stats.gd`). Metrics reset centrally in `reset(from_scratch)`.

A wrong click records where in the sequence it broke and whether the player jumped ahead or fell back; a completed round records the span. Where it breaks distinguishes a lost place from a lost order.
