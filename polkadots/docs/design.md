# Polka Dots — Game Design & Implementation Document

## Overview

**Game name:** Polka Dots
**Folder:** `polkadots/`
**Singleton:** `PolkadotsG`
**Save key (short name):** `polkadots`
**Initial time:** 5 minutes
**Background color:** `0x3C5D3EFF` (dark green)

Polka Dots is a letter/number recognition game. Each round shows a pattern of dots arranged so they outline a letter or digit. The player must identify which character the dots form by tapping one of the displayed options.

---

## File Structure

```
polkadots/
├── docs/
│   └── design.md           ← this file
├── scripts/
│   ├── globals.gd            (PolkadotsG autoload)
│   ├── level_config.gd       (PolkadotsLevelConfig — per-level params array)
│   ├── main.gd
│   ├── level.gd
│   └── dots_display.gd       (Control subclass, renders dot pattern + letter reveal)
└── scenes/
    ├── main.tscn
    ├── level.tscn
    └── hud.tscn
```

---

## Level Config (`PolkadotsLevelConfig.LEVELS`)

| Key | Type | Description |
|-----|------|-------------|
| `num_options` | int | Number of letter choices shown (3–5) |
| `dot_density` | float | Fraction of eligible letter pixels turned into dots |
| `dot_radius` | float | Radius of each dot in screen pixels |
| `timeout_sec` | float | Auto-advance as wrong after this many seconds |
| `rounds_per_level` | int | Correct rounds required before level-done signal |
| `option_display_sec` | float | 0 = always visible; >0 = hide option labels after N sec |
| `letter_size` | int | Font size of the option buttons |

| Level | Options | Density | Radius | Timeout | Rounds | Hide options |
|-------|---------|---------|--------|---------|--------|--------------|
| 1 | 3 | 1.5 | 16 | 4s | 5 | never |
| 2 | 3 | 0.9 | 16 | 4s | 5 | never |
| 3 | 4 | 0.5 | 12 | 4s | 5 | never |
| 4 | 4 | 0.5 | 12 | 3s | 5 | 5s |
| 5 | 5 | 0.4 | 10 | 2s | 5 | 4s |
| 6 | 5 | 0.5 | 9 | 2s | 6 | 3.5s |
| 7 | 5 | 0.5 | 8 | 2s | 6 | 3s |
| 8 | 5 | 0.5 | 8 | 2s | 6 | 2.5s |

---

## Globals (`PolkadotsG`)

| Variable | Default | Description |
|----------|---------|-------------|
| `starting_difficulty` | 1 | Level index to start at (1-based) |

Settings saved as `[starting_difficulty]`.

---

## Gameplay Flow

1. **Dot display**: A `SubViewport` renders the current letter at the configured font size. Eligible pixels (inside the letter, after erosion by `dot_radius`) are sampled using a stratified 6×6 grid + jitter. Dots are placed within the `DotsDisplay` control using `set_dots()`.
2. **Option buttons**: `num_options` letter choices are created dynamically in a VBoxContainer. The correct letter is always included; wrong options avoid confusable character groups.
3. **Uniqueness check**: Each wrong option is rendered in the SubViewport and its overlap fraction with the current dot positions is measured. If >50% of dots fall inside a wrong option's shape, that option is replaced from a pool of unused CHARSET characters. This ensures dots can only plausibly fit one option.
4. **Player taps**: Option button pressed → reveal animation (`DotsDisplay.reveal_letter()`) → feedback popup → `_next_or_finish()`.
5. **Timeout**: If no tap within `timeout_sec`, the round counts as wrong.
6. **Option hide**: If `option_display_sec > 0`, option labels are hidden after that time (the player must have already noted them).

**Last-level loop (level 8):** At max difficulty, `sig_level_is_done` is emitted directly (silent save) and the game loops at level 8 — no popup, no difficulty increase. Running stats (`rounds_done`, `rounds_correct`, `total_response_time_ms`) persist across loops via `keep_stats=true` in `new_game()`.

---

## Dot Generation Algorithm

1. Render current character in `$CharViewport` (SubViewport, fixed 256×256).
2. Erode inward by `dot_radius` pixels (circular kernel) — only pixels entirely inside the letter remain. If full erosion leaves no pixels (thin strokes), halve the radius and retry until pixels are found.
3. Stratified 6×6 grid: distribute eligible pixels into 36 cells, sample one dot per cell until 70% of non-empty cells are covered, then fill remaining count from leftover pixels.
4. Uniqueness: render each wrong option → measure overlap fraction → replace >50%-overlap options.

---

## Sound Effects

- Correct answer: `res://art/sounds/FreeSFX/GameSFX/PickUp/Retro PickUp Coin 07.ogg`
- Wrong answer / timeout: `res://art/sounds/swoosh.mp3`

---

## Scoring

- Correct tap: `+10` points
- Wrong tap or timeout: `+0` (no deduction)
- `update_score.emit(delta)` → `main.gd` calls `game.add_score_and_time(delta, 0)` + updates HUD

---

## Stats Screen

Score row format: `[unixtime, score, corrects, mistakes, didwin, wasaborted, level_id, avg_time_ms, pct_correct]`

- `progress_level_pos = 6` → level column in Scores tab
- `progress_time_pos = 7` → avg response time (ms) in Speed tab
- `progress_pct_pos = 8` → % correct in Speed tab

---

## Implementation Pitfalls

- **`same_size_as_options` was permanently removed** from `level_config.gd` and all supporting code. The dots panel always uses `size_flags_stretch_ratio = 2.0`. Do not re-add this flag — it caused "no dots visible" bugs because viewport scaling made the erosion radius exceed the letter stroke width, leaving no interior pixels.
- **Erosion fallback**: `erode_px = max(1, ceil(dot_radius * iw / display_size.x))`. If full erosion yields zero pixels (thin strokes), halve `try_erode` and retry until pixels are found or `try_erode == 0`. Always verify this path is preserved when changing dot generation.
- **Option letters are drawn in a child `Label`, not the Button's own text.** Each option Button has no text; instead it holds a mouse-ignoring child `Label` (referenced via `btn.get_meta("glyph")`) that renders the letter. This is deliberate: a Button's *minimum height* is driven by its text, and the option Buttons sit in a size-to-content container chain (`OptionsVBox → OptionsMargin → OptionsPanel → HBox → GameArea`). With the large `letter_size` fonts (90–120), button-text minimum heights summed past the screen height and pushed the whole game area below the screen ("fine when empty, too tall once the letters appear"). An anchor-positioned child does not contribute to its parent Button's minimum size, so the layout stays bounded on any engine. This surfaced on the Godot **4.6 → 4.7** migration. Do NOT set option-letter text back onto the Button itself.
  - **Centering:** the glyph Label is anchored to the Button **center** (all four anchors = 0.5) with `grow_horizontal`/`grow_vertical = GROW_DIRECTION_BOTH`, so it is content-sized and grows symmetrically around the center. This keeps the letter centerd regardless of the font's line-box metrics and auto-recenters when the letter/font changes — a full-rect Label relying on `vertical_alignment = CENTER` rendered the big glyphs bottom-aligned. The Button's `clip_contents` trims any overflow.

## Key Signals

| Signal | Direction | Purpose |
|--------|-----------|---------|
| `Level.sig_level_is_done(level_id, avg_time_ms, pct_correct)` | level → main | level complete → save + popup or loop |
| `Level.update_score(delta)` | level → main | add points to running score |

## Passing a level

Each level in `level_config.gd` carries a **`pass_pct`** — the accuracy needed to move on.
`PolkadotsG.pass_pct_for(level_id)` reads it, falling back to `DEFAULT_PASS_PCT` (70) for a level
that does not state one.

**A level is a fixed number of rounds, so only some percentages exist.** Out of 10 rounds a score
is a multiple of 10; out of 12 the rungs are 8, 16, 25, 33, 41, 50, 58, 66, 75, 83, 91. A
`pass_pct` off those rungs makes the card promise a bar that cannot be met — "need 65%" out of 10
rounds really means 7/10, i.e. 70%. The values are chosen to land exactly:

| level | rounds | pass_pct | really |
|---|---|---|---|
| 1-2 | 10 | 60 | 6/10, 4 misses |
| 3-5 | 10 | 70 | 7/10, 3 misses |
| 6-7 | 12 | 75 | 9/12, 3 misses |
| 8 | 12 | 83 | 10/12, 2 misses |

Recheck them whenever `rounds_per_level` changes.

`_next_or_finish` ends the level after `rounds_per_level` rounds PLAYED. It used to end after that
many rounds WON — a wrong answer just bought another round, so the level could not be failed and
you always finished on a win, which leaves an accuracy gate nothing to measure.

Before the gate, `_on_level_sig_level_is_done` set `game.need_to_increase_level = true`
unconditionally: finishing the rounds WAS passing, so a player could get every round wrong and still be moved up,
which made the accuracy number on the summary decorative. It is now `= passed`, and
`MainGlobals.global_level_is_done(passed)` reports the same truth.

The summary says which happened, because "80% correct" on its own does not tell the player whether
they are moving on:

- passed -> `Level passed — on to level N.`
- failed -> `You need at least NN% accuracy to pass to the next level.`

The last level is unaffected: it loops with cumulative stats and never shows the card.

## "complete!" only when it was

This game can END a level without PASSING it, so `show_level_done_popup` is called with the gate
result as its `passed` argument. The card then reads "Level N complete!" with a check badge on the
success color, or **"Level N not passed"** with no badge on the warning color — a tick over "you
need at least NN% accuracy" was the card congratulating the player for failing.

The level id is passed too, so the title names the level instead of saying a bare "Level complete!".
`passed` defaults to true in the shared helper, which is right for every game where reaching the
end of a level IS finishing it.

The accuracy row is the number ALONE — `Accuracy: 50%`, not `50% (need 60%)`. The threshold is
already stated in full by the progress line under the table, and on a level the player passed, the
bar they cleared is not something they need told.

## No session clock

`PolkadotsG.init_globals()` sets `game.uses_session_clock = false`, which hides the HUD countdown
and keeps a "Time left" row out of the level summary.

A session clock only means something if the game RUNS it — `game.playing = true` plus
`hud.restart_time_left_timer()`, after which it counts down and ends the session at zero (whack is
the model). This game never did either: `game.playing` appears exactly once in its scripts, as
`= false`. So the countdown sat frozen at 00:05:00 in the HUD and every level summary printed
"Time left: 00:05:00" — a number that looks like a limit and is not one.

The time pressure here is the **per-round `timeout_sec`**, the bar above the options, and the level
ends after `rounds_per_level` rounds. Neither has anything to do with the session clock.

The `0, 5, 0` in the `GenericGameUtil` constructor is now inert. If this game ever WANTS a cap, the
fix is to run the clock (set `playing`, restart the timer) and drop the flag — not to re-show a
number nothing decrements.

## A replay starts clean

Failing the gate replays the level, and `Level.new_game()` clears `_rounds_done`, `_rounds_correct`,
`_total_response_time_ms` and the HUD's `game.corrects` / `game.mistakes` — the pair the player can
see, which used to still show the failed attempt.

The exception is `_keep_stats`, which is the last level looping on purpose: there a running average
over everything played at that level IS the point, so nothing is cleared.

The repaint sits next to the clearing (`MainGlobals.global_update_hud()`), not in `main.gd`.
Whether the HUD is refreshed after the level is rebuilt differs per game — polkadots never did it —
so the counters read 0 while the labels still showed the level the player had just failed. Clearing
a counter and showing the cleared value belong together.

## A failed level earns nothing

`Level.score_at_level_start` is stamped when a level begins (main.gd reads it), and a level that misses the gate restores
it. Otherwise the gate is a scoring exploit: the score is cumulative across a session, so every
failed attempt banked its points and the retry cost nothing — fail forever, earn forever.

**When** it happens is split on purpose. The score row is written the moment the level ends and
must already hold the kept value, or failing repeatedly would farm the score list — so the kept
value is put in place just for that save. The screen, though, keeps showing the score the player
had while playing, because watching it drop out from under a summary you are still reading is
alarming. The visible rollback lands in `new_game()` along with the counters, when Continue is
pressed.

Only the failed level's points go back. Everything earned in levels already passed is untouched.

## What this game measures

Session records are the v6 named-dictionary format (see `scripts/generic_game_util.gd`
and `scripts/session_stats.gd`). Metrics reset centrally in `reset(from_scratch)`.

Each round logs which character was shown, which was chosen, the response time, and whether
the option labels were still on screen when the answer was given (`hidden`). Individual
response times are kept; the game previously held only a running sum, so it had no
distribution to measure spread from.

**Why there is no confusion matrix.** The obvious view here — a grid of what was shown
against what was chosen — was built and then removed, for two reasons that are both
properties of this game rather than of the data collected so far:

- `_build_options()` deliberately excludes the look-alike group (`CONFUSABLE_GROUPS`) that
  contains the correct character, so O/0/Q, I/1, S/5, Z/2, B/8 and G/6 can *never* appear as
  each other's distractor. Precisely the confusions worth measuring are the ones the game
  makes impossible; whatever is left is an arbitrary random distractor.
- The grid would be 36x36 = 1296 cells against roughly 10-12 rounds a session and five
  sessions kept — under two showings per character, let alone per pair.

**What the Memory view shows instead.** Accuracy in each of the two conditions, one bar
each, built by `GameInstrument._visibility_split()`. The split is a real difference the game
creates on purpose: the same perceptual task with and without a memory load on top. It
appears in the Charts tab under the **Memory** button once a condition has enough rounds,
captioned, with the rounds and the typical answer time under each bar.

**It is not a 2x2, and must not go back to being one.** It was, and that was wrong twice
over. `MatrixControl` shades each cell in proportion to its raw count, and the polkadots
table set `cool_diagonal = false` because "correct" here is a whole column rather than the
diagonal — so nothing was exempted from the heat scale and the two CORRECT cells, being the
largest counts, were painted the hottest red while the worst cell was nearly invisible. The
picture said the opposite of what it meant. Second, two rows of counts only compare when
they hold the same number of rounds, and which levels were played decides that: levels 1-3
produce only on-screen rounds and 4-8 only hidden ones, so a player who mostly plays level 2
gets a large top row and a tiny bottom one. A percentage is comparable by construction.

(The yes/no games' 2x2 in `_four_cells()` keeps `cool_diagonal = true`, so its correct cells
go green and only the mistakes take the red scale. That one is fine.)

The rows are named after **what the player sees change**: `option_display_sec` is 0 on
levels 1-3, so the characters stay; from level 4 it is 5s down to 2.5s, after which
`_on_hide_options_timer_timeout()` makes each option button's glyph transparent. The button
itself stays in place showing its index number, so the round is still answerable — from
memory of which position held which character.

**The `hidden` flag must come from `_options_hidden`, not from the buttons.** It used to be
recorded as `not _options_visible()`, and that helper asked whether the option *buttons* were
still visible — which they always are, because hiding only recolours the glyph Label inside
them. The flag was therefore `false` in every round ever logged, on every level, and the
choices-hidden half of the view could not fill at all. Do not reintroduce a check that reads
the buttons.

## Level naming, and where the scores wiring lives

The game supplies its level names as **bare numbers** (`str(cfg["level"])`), from
`main.gd` and nowhere else. The shared display rules produce both forms wanted:
`ScoresList._level_header()` turns a numeric name into `Level 3` for the heading over a block
of rows, and `ChartControl.legend_entries()` turns it into `L3` in a chart legend, where a key
has to stay narrow. Prefixing "L" at the source would give `L3` in both.

`globals.gd` used to set the same names to `"L" + str(level)`, and also set
`progress_level_pos/time_pos/pct_pos` as the literals 6/7/8 beside `main.gd`'s `POS_LEVEL`,
`POS_TIME_MS`, `POS_PCT`. Which form the screens showed therefore depended on which file ran
last - main.gd does, which is the only reason the naming looked right - and adding a column
would have had to be remembered in two places. That block is gone from `globals.gd`; the
scores wiring lives in `main.gd`.
