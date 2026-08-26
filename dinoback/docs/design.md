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
├── art/game_screen_200.png       # chooser tile, built by docs/make_thumbnail.py
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
*distractor* before it becomes the *rule*, then N grows.

**Photographs recur at every N** — 1-back at 4–5, 2-back at 11–12, 3-back at 15–16 and 18–19 —
rather than only at the end. A dino has no name to rehearse, so it is its own axis of difficulty
independent of N; meeting it first at N=1, where the task itself is already understood, isolates
that one new thing instead of stacking it on a bigger N.

19 levels, 1-back → 3-back, ending in an endless 20-minute practice level.

**Ids are the play order.** `new_game` advances with `current_level_id + 1`, so ids must stay
sequential and match the array order — inserting a level means renumbering everything after it,
which also re-labels any already-saved score rows (they store the level id).

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
  polygon shapes.
- **No diamond** — a rotated square is not a distinct shape (project rule).
- **Frame color**: white is reserved for dino photos (as in Dino); people and all three drawn
  categories get the yellow zigzag. On a drawn face — a dark plate with one bright symbol — a white
  frame reads as a second bright element competing with it. The frame never encodes the card's own
  color, or the color rule would be readable off the frame instead of the symbol.

## Chooser tile

`docs/make_thumbnail.py` (PIL, run by hand) composites `art/game_screen_200.png` from the **real
dino photographs** in `res://art/dinos` — the game is called Dino N-Back, so the tile should not be
abstract shapes. Three cards in a row, white-framed as dino cards are in game, all at full
strength: **the outer two are the same dino**, the middle a different one; below them an arc
joining the matching pair, with the `N` it all turns on. That is the whole game in one picture.
The middle card is deliberately *not* dimmed — that read as "this card is inactive" rather than
"these two are the same one".

`DINO_A` / `DINO_B` at the top pick the photos by index (1..48) — currently dino5 (repeated) and
dino9 (middle); the script prints which files it used.

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

- **Generator, 6000 trials per level × all 19 levels.** Every trial's scored label agrees with the
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

## Tutorial

`dinoback/scripts/tutorial.gd` (12 steps), entry `dinoback/scripts/main.gd::start_tutorial()`,
level 1 (1-back, four shapes, one color). See `docs/tutorials.md` for the step schema.

What a first-timer gets wrong, and what the tutorial does about it:

- **They play it as Dino** — "have I seen this card?". With a pool of four, every card is one they
  have seen, so familiarity answers nothing. The tutorial says this outright, and says it *late*,
  once the player has answered a match and a non-match and can feel what the question really is.
- **The priming cards.** The first N cards have nothing to compare against: answers are refused and
  the buttons are dimmed, which reads as a broken game unless someone explains it first.
- **The bar is a deadline.** No answer scores like a wrong one.

Specific to this game:

- **No freeze work was needed.** `_can_play()` requires `not game.paused()`, and the card deadline
  is measured in `game.game_time`, which excludes paused time — so a caption stops the stream and
  the countdown bar together. Verified by seeding: removing `not game.paused()` from `_can_play()`
  breaks the run (the harness catches it as a step ending on its timeout).
- **`tutorial_force_target`** (1 = match, 0 = non-match, -1 = normal) short-circuits the
  `target_rate`/`lure_rate` roll in `_next_trial`, so a clean match and a clean non-match are each
  taught on demand instead of whenever the generator obliges.
- **`tutorial_hold_cards` is defensive, not load-bearing.** Removing it does not break the run —
  the pause already stops `_process` on every talking step. It is kept to close the window between
  an answer being registered and the next caption pausing the game, which on a slow device could
  in principle be long enough to deal a card.
- `new_game()` skips the "Level 1 / N = 1 / MATCH = same shape as…" intro popup in tutorial_mode:
  the tutorial *is* that explanation, delivered one beat at a time.
- `_level_done()` returns early in tutorial_mode, so `duration_sec` running out mid-lesson cannot
  drop a level-completed popup on the coach.
- **The captions on card steps are deliberately short.** A "big" card is ~427px tall on a 748px
  screen, leaving only ~150px of clear space above it; a longer caption has nowhere to go that does
  not bury the card it is pointing at.
- **No talking step says "swipe".** The board is frozen while a caption is up, so an instruction
  there cannot be obeyed — and the player's attempt just dismisses the step. Every swipe
  instruction lives on the action step that accepts it.
- Events reported to the coach: `card_shown`, `priming_card`, `scored_card`, `target_card`,
  `plain_card`, `answered`, `answered_right`, `answered_wrong` — all `game.tutorial_notify`,
  no-ops outside tutorial mode.
- Points for the coach, all in screen coordinates: `tutorial_card_rect`, `tutorial_bar_rect`,
  `tutorial_buttons_rect`.

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
