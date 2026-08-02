# Dino N-Back — design

## Overview

An **n-back working-memory** game, built on the Dino shell (same card, same swipe, same buttons,
same HUD, same bottom bar, same level-done flow).

One card at a time. The player answers whether it matches the card **exactly N positions back** —
swipe RIGHT / "Match", or swipe LEFT / "No". A card left unanswered past its time limit is a miss.
Each level runs a fixed duration, then completes and advances.

**This is not Dino.** Dino asks "have I seen this card at all this round"; here the pool is small
and every card recurs constantly, so familiarity tells the player nothing — only *position in the
stream* does.

Cards come from five categories. Two are photographs (`dinos`, `people`) and three are drawn
(`letters`, `digits`, `shapes`). The drawn ones carry a second, implied dimension: **color**. A
level's rule therefore asks about the symbol, the color, or both.

## File structure

```
dinoback/
├── scripts/
│   ├── globals.gd       # DinobackG: categories, symbol pools, color palette, settings
│   ├── level_config.gd  # DinobackLevelConfig: LEVELS array
│   ├── symbol_art.gd    # the DRAWN card face (letter / digit / filled shape)
│   ├── level.gd         # pool, sequence generation, phases, swipe/buttons, scoring
│   └── main.gd          # orchestrator: menu, HUD, help, score/progress wiring
├── scenes/{level,main}.tscn      # all UI built in code
├── art/game_screen_200.png       # chooser tile
└── docs/{design.md,make_thumbnail.py}
```

Shared assets only: the card is `res://shared/scripts/card.gd` (unmodified) with the
`res://art/zig1.png` border, images come from `res://art/dinos/` and `res://art/people/`, the
background is `res://art/dinos/bk1.jpg`, sounds from `res://art/sounds/`. No file references
another game.

## Autoloads

- `DinobackG` — `globals.gd`; owns `GenericGameUtil.new("Dino N-Back", "dinoback", 0, 2, 0)`,
  the symbol pools and color palette, export-safe image loading (`ResourceLoader.exists` probing,
  never `DirAccess`), settings save/load.
- `DinobackLevelConfig` — `level_config.gd`; `LEVELS` + `get_level` / `level_names` /
  `id_to_index` / `max_level`.

## Level config

| field | meaning |
|---|---|
| `n_back` | how many cards back to compare against — the main difficulty axis |
| `source` | category or comma list: `shapes`, `letters`, `digits`, `dinos`, `people` |
| `rule` | `symbol` (same shape/letter/digit/picture) \| `color` \| `both` |
| `pool_size` | how many DISTINCT faces are in play |
| `num_colors` | distinct colors; `1` = no color dimension |
| `card_size` | `small` \| `med` \| `big` |
| `card_time_sec` | timeout before a non-answer counts as a miss |
| `gap_sec` | blank pause between cards |
| `duration_sec` | level length |
| `target_rate` | optional, default 0.30 — fraction of scored cards that ARE a match |
| `lure_rate` | optional, default 0.15 — non-matches deliberately made to match N±1 |
| `partial_rate` | optional, default 0.40 — rule `both` only: non-matches that match exactly one |

**`pool_size` must stay small (4–8).** This is what makes it an n-back task at all. With a large
pool every non-target is brand new, so "is it a match" collapses into "have I seen it" and the
player never has to track position — which is the *other* game.

**Photographs cannot express color.** `_load_level` forces `num_colors: 1` and `rule: "symbol"`
whenever any source is an image category, and downgrades `color`/`both` to `symbol` when
`num_colors < 2` — a rule needs at least two of whatever it reads or no non-match could be built.
Configs are corrected rather than trusted.

### Difficulty ramp

Shapes first (a filled shape in one color is the least to hold in mind), then color arrives as a
*distractor* before it becomes the *rule*, then letters and digits, then N grows. **Photographs
come last**: a dino has no name to rehearse, so a 2-back on dinos bites harder than a 3-back on
shapes. 17 levels, 1-back → 3-back, ending in an endless 20-minute practice level.

## The sequence generator

The heart of the game. Each trial is `{item: int, col: int}`; `_seq` holds every trial in order.

- **Priming.** The first `n_back` cards have no predecessor, so they are shown to be memorized:
  no answer accepted, no score, a neutral blue timeout bar, dimmed buttons and their own prompt
  ("Remember this card / 2 more, then you answer"). They run for `_prime_ms()`
  (55% of card_time, clamped 0.9–2.2 s) — there is nothing to decide, and a full card_time of
  staring at card 1 of 3 is dead air.
- **Targets** at `target_rate`: copy whatever the rule reads from the N-back card. The *other*
  attribute stays random, so the distractor keeps varying on a match too — that is what stops the
  distractor from leaking the answer.
- **Lures** at `lure_rate`: a non-match built to match the **N−1 or N+1** card instead. This is
  where n-back difficulty actually lives; without lures the task is far easier than its N suggests.
- **Partial matches** (`rule: both`) at `partial_rate`: match exactly one of symbol/color — the
  half-right card, by far the easiest thing to answer wrongly.
- `_break_match` is the safety net: any candidate that accidentally matches is forced apart on
  exactly the attribute the rule reads.

`_make_neither` exists as an explicit case for `rule: both` rather than leaving clean non-matches
to `_break_match`. Without it, `_break_match` changed the symbol and left the color standing, so
**67%** of non-targets came out half-right against a configured `partial_rate` of 0.40 — the knob
did not mean what it documented. With the explicit split it measures 0.41–0.44.

## Card faces

- **Photographs** use the card's `ASPECT` fit, so the frame matches the image and the whole photo
  shows uncropped (as in Dino).
- **Drawn faces** use `FILL` fit with a **square** card, and `symbol_art.gd` is added as a **child
  of the card** — `card.gd` is a `Node2D`, so the deal/swipe-out tweens carry the art without
  knowing it exists. It draws a dark plate plus one big symbol: shapes at 80% of the box, glyphs
  at 76% of its height.
- **Glyphs are sized and placed by their actual INK BOX**, queried from the text server, not from
  font metrics. `ascent - descent` only approximates cap height and is wrong by different amounts
  per face — here it measured 0.69 em against a real cap ink of 0.74 em, so glyphs came out **7%
  oversized and sat high**. The ink box is exact, per glyph, and needs no per-font constant, which
  matters because this is a `SystemFont` that resolves to a different face on a phone.
  `_draw_glyph_by_metrics` is the fallback if a face cannot report ink. Centering error after the
  change: **0.00 px**. The size search then steps down until inside both caps, so a symbol never
  touches the frame; a wide glyph is width-limited by design (a `W` cannot be as tall as an `A`),
  and the invariant is "inside both caps, maxed on one of them", not "all the same height".
- Shape radii are **per-shape multipliers** that equalize *perceived* size: a triangle or star
  inscribed in the same circle as a square looks much smaller because so much of the circle is
  empty.
- **Every polygon is bounding-box centered** (`_centered`). Building a shape around its
  circumcenter does *not* center it: a point-up triangle reaches a full radius up but only half a
  radius down, so it sat visibly high in the card; a 5-point star and a pentagon are off by ~0.1
  radius the same way. Symmetric shapes (square, plus, hexagon) are unaffected, so it runs for all
  of them rather than special-casing. Measured centering error after the fix: 0.00 px on all six
  polygon shapes. `docs/make_thumbnail.py` does the same thing for the chooser tile.
- **No diamond** — a rotated square is not a distinct shape (project rule).
- **Frame color**: white is reserved for dino photos (as in Dino); people and all three drawn
  categories get the yellow zigzag. On a drawn face — a dark plate with one bright symbol — a white
  frame reads as a second bright element competing with it. The frame never encodes the card's own
  color, or the color rule would be readable off the frame instead of the symbol.

## Scoring

- Correct: `+10 + speed bonus` on a **match**, `+5` on a non-match. Only ~30% of cards are matches,
  so a player who always answered "No" would otherwise bank most of the level's score for free.
- Wrong / timeout: `-min(3, score)`. Feedback distinguishes **Missed** (a target answered "No")
  from **Wrong** (a false alarm).
- Level-done popup shows accuracy **and `Matches found: k/m`** — plain accuracy flatters an n-back
  player because "No" is right by default about 70% of the time.
- Score row `[didwin, wasaborted, level_id, mean_response_time_ms, pct_correct]`
  (`POS_SCORE_LEVEL_ID=6`, `MEAN_TIME=7`, `PCT=8`).

## Level names, the HUD, and the intro

Three places say what a level is, and each says a different amount on purpose.

Two names per level, because the places that show them have very different room:

- **`menu_name`** — the dropdown only: `"<id> N<n> <what to match>"`, space-padded so the ids line
  up in the mono font (`" 9 N2 Letter/digit"`, `"10 N2 Letter+color"`). `only` means the other
  attribute is a distractor to ignore, `+` means both must match, `/` separates mixed categories.
- **`name`** — the compact label (`"9 N2"`) for the **scores table and the chart legend**. The
  scores level column is weighted 4 of 16, about a quarter of the table width, and the legend is
  narrower still, so a 20-character name would overflow both. `menu_names()` falls back to `name`,
  so a level may omit `menu_name`.

There is no `3+` or similar — **N is a fixed per-level integer and never varies during play**; an
earlier `"17 Di3+"` read as a dynamic N and was wrong for that reason alone.

Fitting those names took two things. `main.gd` passes the caption **"Level"**, not "Starting
level": the caption's minimum width is subtracted from the dropdown's, and at "Starting level" the
dropdown got only 282 px of a 600 px row — 13 mono characters. "Level" leaves it **465 px**, and
the widest name renders at 389 px, at the full theme font size. `main_menu._fit_option_font` then
shrinks the mono size only if a list still would not fit, so this cannot clip whatever a game does.

**The HUD** shows `Level 9   N=2` — not the long name. Which cards you are looking at is obvious
from the screen; N is not, and it is the one thing worth having permanently on display.

**The intro** opens with the two facts needed before the first card:

```
Cards: Letters and digits, in 4 colors
N = 2

MATCH = same SYMBOL as
the card 2 back.
The color does not matter.
...
```

then the rule in full, the swipe directions, and how many opening cards are just to watch. It
names the symbol dimension the way this level's categories make sense (`SHAPE` / `LETTER` /
`DIGIT` / `SYMBOL` / `PICTURE`). **Card time is deliberately not shown.**

## Key pitfalls

- `game_over_on_time_out` must stay **false**: the duration is a per-level budget, not a game-over.
- `_register_answer` ignores priming cards entirely — a tap during priming must not score.
- A swipe must BEGIN during the current card: press state is reset in `_show_next_card`,
  `new_game` and `stop_level`, and an answer in the first 150 ms of SHOW is dropped.
- Card sizing is in **actual pixels**; never size the card via `Node2D.scale`.
- The `_seq` array is never trimmed — it is the level's whole history and `_lure_ref` reads back
  into it. A 20-minute level holds a few hundred small dictionaries, which is fine.

## Verification

No CLI test pipeline. Everything below was checked with temporary headless probes (since deleted):

- **Generator, 6000 trials per level × all 17 levels.** Every trial's scored label agrees with the
  rule; no trial out of pool/color range; target rate 0.29–0.32 against 0.30; lures present above
  half the configured rate; `rule: both` partials 0.41–0.44 against 0.40.
- **The distractor does not leak the answer** — the key property. P(distractor also matches) is
  within 0.02 between targets and non-targets on every multi-color level (e.g. 0.336 vs 0.336,
  0.253 vs 0.251). If a target were more likely to also match on color, "same color" would become
  a free hint for a "same shape" level.
- **Play-through, 60 trials on levels 1/8/12/14.** Exactly `n_back` priming cards, none scored;
  scored count = trials − n_back; a perfect player scores 100% and hits every target.
- **All 26 drawn faces render** (7 shapes, 14 letters, 5 digits) with no glyph shrunk to the size
  floor.
- Headless boot of the game and of the whole app is clean; source-lint clean for `:=`,
  base-class shadowing, unused locals and British spellings.

**Not verified: how any of it looks.** Headless has no renderer. The shape multipliers, glyph
sizing, plate contrast and card sizes all need an eyeball in the editor.
