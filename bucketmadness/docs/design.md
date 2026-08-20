# Bucket Madness — Design Doc

## Overview

A single item falls from the top center of the screen. Three buckets are at the bottom: left (matches left rule), center (dumpster — neither rule), right (matches right rule). The player must direct the item into the correct bucket before it reaches the bottom. Rules are shown as text labels at first, then hidden after `rounds_before_hide` rounds.

## File Structure

```
bucketmadness/
├── scripts/
│   ├── globals.gd        # Autoloaded as BucketMadnessG
│   ├── main.gd           # Orchestrator
│   ├── level.gd          # Core gameplay
│   └── level_config.gd     # Autoloaded as BucketMadnessLevelConfig
└── scenes/
    ├── main.tscn
    └── level.tscn
```

Independent game: it has its own `bucketmadness/art/` folder (chooser thumbnail + its own `bucket_*.png` / `dumpster_*.png` graphics) and otherwise uses only shared root assets from `res://art/` (e.g. `grass.png` background); the shape/digit/letter objects are drawn as **font glyphs** (Labels), not images. No files reference or depend on rlmadness. Sounds from `res://art/sounds/`.

## Autoloads

- `BucketMadnessG` — `globals.gd`; owns `GenericGameUtil.new("Bucket Madness", "bucketmadness", 0, 10, 0, 0)`; manages level queue, settings (`starting_level_id`, `use_uppercase`)
- `BucketMadnessLevelConfig` — `level_config.gd`; provides `LEVELS`, `LEVEL_PROGRESSION_ORDER`, `get_level(id)`, `level_names()`, `id_to_index(id)`

## Gameplay Design

### Two-object items

Each falling item contains **two objects** side by side (like rlmadness), one from each modality. Display order is shuffled each round so the matching object isn't always on the same side.

Cross-rule constraint: only one object can match one rule — the other is explicitly generated to fail:
- Category 0 (left): `obj_a = left.gen(true)`, `obj_b = right.gen(false)`
- Category 1 (right): `obj_a = right.gen(true)`, `obj_b = left.gen(false)`
- Category 2 (dumpster): `obj_a = left.gen(false)`, `obj_b = right.gen(false)`

Display order is randomised each round. Each sub-label is `ITEM_W/2 = 70` wide at `PAIR_FONT_SIZE = 36`. `ITEM_W = 140` (kept narrow so the two objects appear close together).

### Item categories

Each round, `active_category` is chosen randomly (0, 1, or 2):
- 0 = matches left rule → `correct_bucket = 0` (left)
- 1 = matches right rule → `correct_bucket = 2` (right)
- 2 = neither (dumpster) → `correct_bucket = 1` (center)

### Preview phase

At the start of each level, the rules are shown for `preview_time` seconds (level-defined, 2–4s) before any items drop. A countdown ("Starting in 3...") runs in the AvgTimeLabel so the player can study the rules.

### Fall mechanic

Item starts at `y = -(ITEM_H + 10)` and tweens to `y = h - ITEM_H - 30` over `fall_duration` seconds. If the player doesn't respond, `_on_fall_reached_bottom()` calls `_evaluate_answer(1)` (dumpster default).

After the player answers, the item slides diagonally to the chosen bucket's x position (fracs = [0.1, 0.5, 0.9] × width) and down off-screen over 0.35s.

### Input

- Swipe left (if `abs(delta.x) >= abs(delta.y) * 1.2`) → left bucket (0)
- Swipe right → right bucket (2)
- Swipe down or any other direction → dumpster (1)
- Keyboard: `left`/`ui_left` → 0, `right`/`ui_right` → 2, `ui_down`/`ui_accept` → 1
- Swipe threshold: 60px

### Scoring

- Correct: +10 + speed_bonus (max 20, 1 point per 100ms under 2s)
- Wrong: −min(3, score)
- Timeout (fall reaches bottom) → dumpster answer, scored as wrong unless dumpster was correct
- Level end popup shows accuracy % and mean response time

### Label hiding

After `rounds_before_hide` rounds, both rule labels fade to alpha=0.

## Levels

5 levels, cycling via `LEVEL_PROGRESSION_ORDER = [1,2,3,4,5,3,4,5]`:

Each level defines a **`rules` pool**, not a fixed left/right pair. On every level load, `_pick_pair_from_pool()` shuffles the pool and takes the first two **distinct, non-confusable** keys, so which rules appear — and which bucket each one lands on — varies from play to play. `_are_confusable()` (via `_CONFUSABLE_WITH`) keeps overlapping rules apart (see below).

An **empty** `rules` list means "use every rule". Overlapping rules may safely share a pool — `_find_rule_pair` only ever returns a legal combination. The pair used last time is also avoided whenever the pool offers an alternative, so replaying a level (or wrapping around the progression order) doesn't serve up the same two rules again.

**Stroop sizing.** The two objects of an item do **not** split the width 50/50 — a stroop word ("YELLOW") is many times wider than a glyph and used to spill over its half and collide with the other object. `_share_pair_widths` gives each object a share proportional to its natural text width (clamped to 18–82% so neither is starved), then `_fit_label_width` shrinks each font until its text fits the share it got. On a 220px belt the word keeps its full size; only narrower items shrink it.

**Rule overlap (`_CONFUSABLE_WITH`).** Two rules may only be shown together if **no single object can satisfy both**, otherwise an item legitimately belongs to both sides and the "correct" answer is arbitrary. Overlapping sets: `digit`/`even_odd`/`prime` ("4" is a digit and even; "3" is a digit, prime and odd), `vowel`/`lines` (A, E, I are vowels and straight-line letters), and `square`/`filled`/`color_shape` (a ■ is a square and filled; colored shapes are all filled glyphs). `hollow` is deliberately unconstrained — hollow glyphs are disjoint from square, filled and color_shape. `_pick_pair_from_pool` searches **all** pairs in the shuffled pool for a legal combination, so a pool may safely list overlapping rules as long as some legal pair exists.

| ID | Name   | Rules pool | Hide after | Rounds | Fall duration |
|----|--------|-----------|-----------|--------|--------------|
| 1 | Green | digit, square | 6 | 10 | 2.5s |
| 2 | Blue | even_odd, vowel, hollow | 5 | 12 | 2.2s |
| 3 | Red | hollow, even_odd, vowel, square | 4 | 12 | 2.0s |
| 4 | Cyan | prime, filled, vowel, lines, color_shape | 3 | 15 | 1.8s |
| 5 | Orange | lines, hollow, prime, color_shape, stroop, vowel | 2 | 15 | 1.5s |

**Repeating the last level.** `LEVEL_PROGRESSION_ORDER` normally cycles back to its first entry once exhausted. Ending it with `-1` (`REPEAT_LAST`) instead makes the run **hold on the last level forever** — e.g. `[1, 2, 3, 4, 5, -1]` plays 1..5 then stays on 5. With the sentinel present `reset_queue_from` does **not** wrap the tail around, so picking a mid-list starting level still ends on the final level rather than making an earlier one repeat. `-1` is only a sentinel and is never handed out as a level id. Since the rules are re-picked on every level load (and the previous pair is avoided), a repeated level still plays different rules each time.

If accuracy < 70%, level is replayed.

## Modalities

Same 9 modalities as rlmadness/sorting robots: `digit`, `square`, `even_odd`, `vowel`, `prime`, `filled`, `hollow`, `stroop`, `color_shape`, `lines`. Item font size is 90 (larger than sorting robots' 65).

## Bucket/Dumpster Visuals

PNG images instantiated as `TextureRect` nodes by `_setup_bucket_images()` in `_ready()`, inserted at index 0 in each side VBoxContainer above the rule label. `expand_mode = EXPAND_IGNORE_SIZE`, `stretch_mode = STRETCH_KEEP_ASPECT_CENTERED`.

- **Buckets** (left and right): `res://bucketmadness/art/bucket_open_2.png`, min height 125px
- **Dumpster** (center): `res://bucketmadness/art/dumpster_half_open.png`, min height 160px (taller than buckets)

## Fall Area Trapezoid

`FallArea` is a plain Control (no PanelContainer wrapper). A `Polygon2D` (`_trap_poly`) added as index-0 child draws a dark-green trapezoid:
- Top edge: `ITEM_W + 20` wide, centered (one `top_inset` from each side)
- Bottom edge: full width of `FallArea`

The geometry guarantees that items sliding to any bucket (fracs 0.1/0.5/0.9) never visually exit the trapezoid before reaching the bottom. `_clear_fall_area()` skips `_trap_poly` so it persists across rounds.

## Scene Layout (`level.tscn`)

```
Level (CanvasLayer, script=level.gd)
├── Background (TextureRect, fullscreen)
├── MainLayout (MarginContainer, fullscreen, margins 12/0/12/0)
│   └── VBox (VBoxContainer)
│       ├── TopSpacer (expands)
│       ├── ContentVBox (VBoxContainer, sep=10)
│       │   ├── AvgTimeLabel (Label, unique, centered, font=24)
│       │   ├── FallArea (Control, unique, clip_contents=true, min-h=320)
│       │   ├── BucketsRow (HBoxContainer, sep=8)
│       │   │   ├── LeftBucketSide (VBoxContainer, expand)
│       │   │   │   ├── (bucket TextureRect, inserted at index 0 at runtime)
│       │   │   │   └── LeftRuleLabel (Label, unique, min-h=52, font=18, autowrap)
│       │   │   ├── CenterBucketSide (same structure)
│       │   │   │   ├── (dumpster TextureRect, inserted at index 0 at runtime)
│       │   │   │   └── DumpsterLabel (Label, unique, "♻ Dumpster")
│       │   │   └── RightBucketSide (same structure)
│       │   │       ├── (bucket TextureRect, inserted at index 0 at runtime)
│       │   │       └── RightRuleLabel (Label, unique, min-h=52, font=18, autowrap)
│       └── BottomSpacer (expands)
└── FeedbackLabel (Label, unique, fullscreen anchors, font=60, α=0 initially)
```

### Why FeedbackLabel hangs off the Level root

It is a transient ✓/✗ flash, and it must cost the layout **nothing**. Inside `ContentVBox` it
claimed ~124 px of permanent height — it takes `get_system_sans_font()`, whose Noto Symbols
fallbacks make a single 60 px line ~2.1x as tall as the font size. That pushed `ContentVBox`'s
minimum height to 732 px against the 583 px `MainLayout` actually has, so both spacers collapsed
to zero and Godot grew the oversized `MainLayout` **upward past its own `offset_top`**, dropping
`AvgTimeLabel` on top of the shared HUD's level number (a measured 28.5 px overlap).

The parent must be a **non-container** so anchors cost no space. `FallArea` looks like the natural
home but is wrong: `_clear_fall_area()` frees every child of it except `_trap_poly`, so the label
is deleted on the first round. The `Level` CanvasLayer root is the correct host, and being the
**last** sibling it draws over the board.

`FeedbackLabel` keeps the symbol font because it genuinely renders `✓`/`✗`. Do not "fix" its
height with a negative `line_spacing` — keep it out of the container flow instead.

## Tutorial

`bucketmadness/scripts/tutorial.gd` (13 steps), entry `bucketmadness/scripts/main.gd::start_tutorial()`,
forced to **level 1** (`starting_level_id`, restored in `_on_tutorial_done` and `_exit_tree`) because
level 1's pool is exactly `[digit, square]` — a fixed, readable pair rather than whichever two the
player's own starting level would shuffle up.

It teaches the two things the instruction text leaves out: that an item is **two objects, only one
of which can ever match a rule** (the other is generated to fail), and that **the rule labels fade
away after a few rounds** — met cold, that reads as the game breaking.

Specific to this game:

- **The fall is a Tween, and landing is an ANSWER.** `_on_fall_reached_bottom` evaluates "dumpster"
  on the player's behalf and scores it, so a caption that outlasts the fall costs them the round it
  is talking about. `tutorial_hold_fall` holds each item in mid-air for the whole tutorial — but
  only once it has dropped `TUT_HOLD_FRAC` (45%) of the way. Pausing it where it spawns would
  freeze it *above* the trapezoid, where `FallArea.clip_contents` hides it entirely, and the
  caption would be framing nothing. The last caption says plainly that items fall from here on.
- **Every clock in this level had to be made pause-aware, not just the fall.** Three were not:
  - `_run_preview()` counted down on a `SceneTreeTimer` and **abandoned itself** the moment it saw
    `game.paused()`. `new_game()` then reached `_next_round()` while still paused, and that returned
    early too — so no item dropped and *nothing would ever call it again*. A player who read the
    opening caption for more than a second got a tutorial waiting forever for an item that was not
    coming. Both now wait the pause out (`_wait_ms`, measured in `game_time`, which excludes paused
    time; `_next_round` loops until unpaused).
  - The ✓/✗ flash and the gap before the next round ran on a real-time 0.7 s timer, so the feedback
    a caption might be describing vanished while it was being read.
  - The slide into the chosen bucket is a second Tween (`_slide_tween`), and a Tween ignores
    `game.paused()` unless something stops it. It is paused alongside the fall now.
- **`_input` now returns early on `game.paused()`.** The item hangs mid-fall behind a help screen,
  a "return to menu?" dialog or a caption; without the guard an arrow key pressed over any of them
  lands in a bucket. This is a real-play fix, not only a tutorial one.
- **The buckets have no scene names.** `_setup_bucket_images()` builds the three `TextureRect`s at
  runtime, so they are kept in `_bucket_images` (board order `[left, dumpster, right]`) for the
  coach to point at. The `LeftBucketBox` / `CenterBucketBox` names this document used to describe
  do not exist in `level.tscn`.
- **The caption is kept off the buckets and the rule labels** by per-step `keep_clear` zones (the
  two rule labels, the three bucket pictures, and the item). Docked at the bottom by default it sat
  squarely on all of them, so once the step that read a rule out had passed, the rule was no longer
  on screen to check against — in a game whose whole point is holding those rules in your head.
  With the zones declared, every caption places itself above the fall area instead. The harness
  asserts the outcome directly: no caption may overlap the rules row or the buckets row.
- **`item_ready`, not `item_dropped`, is what a caption waits for.** `item_dropped` fires as the
  round starts, with the item still a full item-height ABOVE the fall area where `clip_contents`
  hides it; a step opening on it framed empty space above the trapezoid. `item_ready` fires from
  `_process` when the item reaches the hold line, once per round.
- **It is two buckets and a dumpster, not three buckets** — and the dumpster is in the middle of a
  row, which is what "middle" is for.
- **Captions read the live rule text** (`tutorial_rule_text`, `tutorial_matching_rule`,
  `tutorial_bucket_name`) rather than naming "digits" and "squares", since a pool is a pool.
- Events: `item_dropped`, `item_ready`, `answered_right`, `answered_wrong`. Both asks wait on `answered_right`,
  so a wrong swipe keeps the step and the next item is another chance — the caption turns into
  "Here comes another one" while the board is empty.
- Points for the coach: `tutorial_item_rect`, `tutorial_left_bucket` / `tutorial_dumpster` /
  `tutorial_right_bucket`, `tutorial_left_rule_label` / `tutorial_right_rule_label`,
  `tutorial_rules_row`, `tutorial_avg_label`.

## Key Pitfalls

- `item_answered` flag prevents double-evaluation if fall tween and input fire close together.
- `fall_tween.kill()` is called at start of `_evaluate_answer()` to stop fall animation immediately.
- The dumpster (`correct_bucket = 1`) is bucket index 1 (center), not the right bucket.
- Category 2 (dumpster) uses `current_pair[0]["gen"].call(false)` — a "wrong" example from the left modality's generator.
