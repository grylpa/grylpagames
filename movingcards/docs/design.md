# Moving Cards — Game Design & Implementation Document

## Overview

**Game name:** Moving Cards
**Folder:** `movingcards/`
**Singleton:** `MovingCardsG`
**Save key (short name):** `movingcards`
**Initial time:** 5 minutes
**Background:** a teal baize table inside a wooden rail (`scripts/felt.gdshader` on the Level's full-screen
`TextureRect`, set up by `level.gd` `_dress_table()`); it was the flat orange image `art/bk3.jpg`

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
│   ├── card.gd
│   └── felt.gdshader     the table (slate-teal baize)
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

**It keeps counts, not a percentage.** `rounds_right` / `rounds_wrong` / `jumped_ahead` /
`fell_back`, a `span` high-water mark, and `break_pos` / `seq_len` lists. None of those were
metrics any stats screen recognised, so this game had no Summary rows despite recording more
than most. `StatsOverview.METRICS` now carries `span`, and `GameInstrument._derive_pct_correct()`
builds the Accuracy row from `rounds_right` / `rounds_wrong` the same way it does from the four
answer cells elsewhere.

## The chooser tile

`art/game_screen_200.png` (200 x 200) is **drawn** (`devtools/make_thumbs.py`, `movingcards()`), not grabbed. The old tile was nine patterned card backs in a grid, standing still.

It is now **memory-game cards on the move**: rounded pastel tiles (not playing cards -- those, with
swap arrows, read as a gambling game, and the game's square card sprites alone read as dice) on a
warm light background, three face down with a plain white ring and one still face up showing a star,
with dotted paths behind them for where they have glided.

## Sounds

Made for this game by `devtools/make_answer_sounds.py` (see Witness's doc): `tap` a light card tap,
`correct` a rising two-note chime, `wrong` a soft low note (all in `main.gd`), and one ambient
loop (`movingcards_ambient.ogg`, `devtools/make_ambient_sounds.py`, -6 dB: bossa nova at the card table -- nylon guitar, bass, shaker, vibes; it was a slow pad). They replaced a generic tap, an arcade coin, a swoosh and three stock
ocean-wave loops.

**The table** (`felt.gdshader`): a slate-teal baize with a fine fiber texture, a soft overhead light
and a darker edge. Low contrast and directionless on purpose -- the card backs are patterns (stripes,
houndstooth) and part of the stimulus, so the table must not echo them. It replaced a flat orange image
that the user found boring. Round it, a TABLE (the felt alone was "still boring"): a polished wooden
rail with its grain along each side, lit on its inner edge and casting a shadow onto the felt, and a
thin gold inlay line a little way in -- all at the edges, nothing patterned. The rail goes round what
is SEEN: the rect runs past the screen, so `_dress_table` passes the visible part below the HUD strip
(`HUD_STRIP`) as the shader's `table` rect.

**The cards stay face up to be looked at.** After each correct tap that is not the last, the cards turn
back 0.7 s later -- unless anything was tapped since or the round finished (`_tap_seq`). Checked only by
round, a quick tap on the LAST card inside those 0.7 s let the earlier timer turn every card back over
during the two seconds meant for looking at the right answer. The clue (`show_clue`) is guarded the same way.

**The card is ONE ROUNDED SHAPE on both sides** (`card.gd`, `CARD_RADIUS` 14): the face, the tap mark,
the fine navy edge (`CardBorder`, rounded) and the patterned BACK (`rounded.gdshader` cuts the square
back art's corners) all share the radius, so turning a card over keeps its shape, and the gold line
inside the face and the inside of the mark stay visibly curved (at 9 px they came out nearly square).

**The front** (`_dress_face` / `_draw_face`, on a child of `CardFront`, so it shows and hides with it):
warm cream stock deepening a touch toward the bottom, a soft bevel (a lit edge along the top-left of
the rounded outline, a shaded one along the bottom-right), a fine gold line inset with its own rounded
corners and a fainter one inside it, and the number large in deep navy with a soft shadow (`CardLabel`,
in the app's text face). **A tap is marked unmistakably** (`clicked` sets `_mark`): a 6 px rounded
ring in green or red and a wash of the same color over the face. History: a plain white square with a
black number in a black and white frame; a playing card with corner indices ("not the goal") whose
right/wrong frame was too faint; a plain cream tile ("a bit bland"). The old `CardFrontFrame` panel is
hidden.

**The card FLIPS** (`_flip_to`): showing or hiding a face narrows the card to its edge (`scale.x` to 0),
puts up the other face and opens it again, 0.2 s in all. The faces used to swap in one frame.

**Cards stay on the table** (`level.gd` `TABLE_SIDE` 40): every placement and every arc's bow keep the
cards inside the felt's gold inlay line; they were placed to within 6 px of the screen edge, over the
wooden rail.

**Cards cast a soft shadow** (`card.gd` `_draw`): ONE pre-blurred 64x64 texture (`_make_shadow`, made
once, shared) drawn filtered under the 80x80 card, so it lies on the table rather than looking pasted
on. The first version stacked three hard-edged translucent rects; their edges snapped from pixel to
pixel as a card moved at sub-pixel steps, and the moving card FLICKERED. The faces and backs are the
stimulus and are untouched.

## The main menu's poster

`scripts/menu_world.gd` (`main.gd` `menu_backdrop()`), REAL 3-D on the shared `scripts/menu_poster3d.gd` (the
shared `main_menu.gd` keeps only a slim panel at the foot): A CAROUSEL IN A ROOM (the user: "make sure to do
everything in correct 3d"). The cards are glazed memory tiles (`scripts/menu_card.gd`: a pastel each; the face a
number in a colored disc ringed with dots, the back the pastel with soft arcs and a five-petal flower; playing cards
with gilt and indices looked like a gambling game), each face and back baked ONCE into a texture (all in one frame,
`flat` drawing) and laid on a 3-D TILE projected by the scene's own camera (`screen_of`): the rounded outline front
and back, a thickness (`CARD_T`) running all round it, each piece of the edge lit by the way it faces (a square box
behind a rounded face read as "printed on a square glass box"). The tiles ride a ring above the table, each facing
out from the ring, so a tile turns its face to us as it comes round the front and its back going round behind;
which face shows, and which edge pieces, are tested from the eye to THAT face or piece (tested from the tile's
center they flipped a frame early or late at the sides of the ring -- a jump); a face exactly edge-on, with no area,
is left out. Their shadows lie on the tabletop. The tiles and shadows are the only live parts.

THE ROOM IS REAL 3-D, BAKED (2026-11-18; the hand-projected room read flat): a wall papered in a figured stripe
(dusty rose and sand, a gold pinstripe, a sprig) over raised wainscot panels, a molded dado rail and a skirting; a
window at dusk cut through the wall -- its reveal, sill, sashes and glazing bars, the sky and low roofs with a lit
window or two beyond; velvet curtains hanging in folds from a brass rod with finials; a framed OIL PAINTING in a gilt
molding (2026-11-18; a dusk sky over three lumps of hill read as a window or "a bit empty"): a summer landscape painted
in dabs (`_painting`) -- soft clouds, blue hills, a river winding down between meadows, stands of trees, a farmhouse
with a red roof, a path with a little figure -- under yellowed varnish with a craquelure, on a flat canvas (a box
spread the texture over six faces and showed a strip of sky), lit by a brass picture light; a FLOOR LAMP (2026-11-18; the user: "the standing lamp is bad") -- turned aged brass (`_lathe`: a heavy stepped
base, a stem with knuckles and collars), a harp to a finial, a LINEN DRUM SHADE lit from within (brightest at the bulb,
the weave showing, trim bands at its rims), its light thrown up and down the wall in two scallops, its cord on the
floor; a round patterned rug on oak boards; and the table -- a round oak
top with a rounded edge and an apron on a turned pedestal with three feet. One picture per platform
(`art/menu_room.webp`, `art/menu_room_d.webp`). Made up, never the board: the menu also opens mid-game.
