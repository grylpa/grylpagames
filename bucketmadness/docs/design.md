# Pockets — Design Doc

(Shown as **Pockets** since 2026-11-02; it was Bucket Madness. The folder, the autoloads and the
save/upload key all keep `bucketmadness`, so saved scores and settings carry over. **In the code a
"bucket" is a pocket and the "dumpster" is the middle pocket with the net** -- `correct_bucket`,
`_bucket_images`, `tutorial_dumpster()` kept their names.)

## Overview

Two balls roll down a pool table side by side, each carrying one object. Three pockets wait at the near end: the left corner pocket (matches the left rule), the middle pocket with its net (neither rule), the right corner pocket (matches the right rule). The player sends the balls into the right pocket before they reach the end. Rules are shown as text labels at first, then hidden after `rounds_before_hide` rounds.

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

Independent game: it has its own `bucketmadness/art/` folder (just the chooser tile) and otherwise uses shared assets and scripts: `scripts/ball_art.gd`, `chute_view.gd` (the felt), `bucket_stage.gd` (the near rail and pockets), `bucket_view.gd` (the target markers), `factory_backdrop.gd` (the room), `bottle_art.gd`, `bridge_art.gd`. No files reference or depend on rlmadness. Sounds from `res://art/sounds/`.

## Autoloads

- `BucketMadnessG` — `globals.gd`; owns `GenericGameUtil.new("Pockets", "bucketmadness", 0, 10, 0, 0)`; manages level queue, settings (`starting_level_id`, `use_uppercase`)
- `BucketMadnessLevelConfig` — `level_config.gd`; provides `LEVELS`, `LEVEL_PROGRESSION_ORDER`, `get_level(id)`, `level_names()`, `id_to_index(id)`

## Gameplay Design

### Two-object items

Each falling item contains **two objects** side by side (like rlmadness), one from each modality. Display order is shuffled each round so the matching object isn't always on the same side.

Cross-rule constraint: only one object can match one rule — the other is explicitly generated to fail:
- Category 0 (left): `obj_a = left.gen(true)`, `obj_b = right.gen(false)`
- Category 1 (right): `obj_a = right.gen(true)`, `obj_b = left.gen(false)`
- Category 2 (dumpster): `obj_a = left.gen(false)`, `obj_b = right.gen(false)`

Display order is randomized each round. The pair is TWO BALLS (`BallArt`, `item_w` 176 x `item_h` 86; 230 x 112 on a phone), one object on each ball's label.

### Item categories

Each round, `active_category` is chosen randomly (0, 1, or 2):
- 0 = matches left rule → `correct_bucket = 0` (left)
- 1 = matches right rule → `correct_bucket = 2` (right)
- 2 = neither (dumpster) → `correct_bucket = 1` (center)

### Preview phase

At the start of each level, the rules are shown for `preview_time` seconds (level-defined, 2–4s) before any items drop. A countdown ("Starting in 3...") runs in the AvgTimeLabel so the player can study the rules.

### Fall mechanic

Item starts at `y = -(ITEM_H + 10)` and tweens to `y = h - ITEM_H - 30` over `fall_duration` seconds. If the player doesn't respond, `_on_fall_reached_bottom()` calls `_evaluate_answer(1)` (dumpster default).

After the player answers, each ball rolls to the chosen pocket and drops in, the second a beat behind the first (`BallArt.sink_into`, `SINK_TIME` 0.6 s), and the pocket sparkles (`BucketStage.thump`).

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

## The targets

The three targets (`scripts/bucket_view.gd`, `BucketView`) are INVISIBLE markers in the layout now,
keeping their place (the rule plaques stand under them; `min_heights` 44/98/44 so each plaque sits
right under its pocket) and the game's API (`open_amount`, `is_dumpster`, `mouth_global()`). The
pockets themselves are drawn by the stage at the table's real corners (see Visual style), and the
level feeds each marker its pocket's center (`mouth_at`) every frame in `_position_stage`.

## The felt area

`FallArea` keeps its trapezoid: `_trap_poly` (now `ChuteView.FELT_DARK`) is the base under the drawn
felt, the table in perspective -- narrow far end at the top (`top_inset`), wide near end at the
bottom.

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
│       │   │   │   ├── (BucketView target marker, inserted at index 0 at runtime)
│       │   │   │   └── LeftRuleLabel (Label, unique, min-h=52, font=18, autowrap)
│       │   │   ├── CenterBucketSide (same structure)
│       │   │   │   ├── (BucketView target marker, the middle pocket)
│       │   │   │   └── DumpsterLabel (Label, unique; set to "NEITHER" at runtime)
│       │   │   └── RightBucketSide (same structure)
│       │   │       ├── (BucketView target marker, inserted at index 0 at runtime)
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
- **It is two corner pockets and a net, not three pockets** — the captions say "left pocket",
  "right pocket", "the net"; the spotlights go on the stage's marker over each pocket
  (`BucketStage.pocket_spot`), since the target controls are invisible.
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

---

## Visual style: a billiard room (2026-11-02)

The items were tiles falling down a chute into buckets, in a factory and then a "workshop at night";
the user found the tiles ugly and, once the items were billiard balls, the buckets and chute did not
fit at all. Everything is now a pool table in a billiard room:

- **The balls** (`scripts/ball_art.gd`, `BallArt`): glossy ivory, one object on a dark round label in
  its EXACT palette color (the rules compare colors). The sphere is rendered in 3-D ONCE per pixel
  size; label, roll and gloss are 2-D. A label is a cap on the sphere, projected correctly as it turns.
  In play the balls only ROCK (always readable); they turn over as they drop into the pocket.
- **The felt** (`scripts/chute_view.gd`, `ChuteView`): the trapezoid is the table in perspective --
  matte green cloth (no shiny rings: felt is not reflective) with three soft pools of light, one under
  each shade of the lamp; rubber cushions and polished rails with pearl diamonds; the far rail drawn
  OVER the balls (`_mouth`) so they roll out from under it; beer bottles on the side rails (two far,
  small, two nearer, bigger, all at different depths; real 3-D, four designs, none green:
  `scripts/bottle_art.gd`); blue chalk cubes on the rails.
- **The near rail and pockets** (`scripts/bucket_stage.gd`, `BucketStage`): one rail across the
  table's end with a CORNER POCKET at each end (the two rules) and a SIDE POCKET in the middle (neither
  rule) whose string NET hangs from a brass ring under the rail. A separate row of containers under the
  table read as buckets; a net hanging free read as a basketball hoop. The pocket a ball is heading for
  lights up; the table's two near legs (thick turned wood) go down to the floor.
- **The room** (`scripts/factory_backdrop.gd`): green damask walls, a wainscot, a wooden floor; the
  three-shade green billiard lamp; cues leaning on both walls; a triangle rack on a hook; a scoring
  wire; the MECHANICAL BRIDGE standing against the wall (`scripts/bridge_art.gd`, 3-D: a pole with a
  thick chrome-wire head, two legs and a dent for the cue, its dent toward the wall; earlier drawn
  shapes -- a hook-hung rake, a cross, a solid plate -- were wrong); a small gilt-framed picture of the
  APP'S icon (`art/icon_big.png`, the Android launcher icon); in front of the table a patterned carpet
  (filled borders, a lattice, a medallion -- lines on a flat color read as a basketball court) whose far
  edge is hidden under the table and whose size and perspective follow the TABLE (the level feeds
  `table_rect`, `table_inset`, `table_bottom`), so it is right on a phone too; a leather bar stool.
- **Labels**: the rules on BRASS PLAQUES (`_brass_plaque`); the middle one reads "NEITHER".

### Driving a tween from `_process`

Both of this game's animations are paused/resumed every frame from `_process` so they follow the
game's own paused state. That spammed the log once a round's animation finished:

```
Can't play finished Tween, use stop() first to reset its state.
```

**Godot has no `is_dead()`.** A tween that has run to the end still reports `is_valid() == true`,
and `is_running() == false` is indistinguishable from "paused" — so neither guard is enough, and
`_process` keeps calling `play()` on a corpse every frame for the rest of the round. Guarding with
`is_instance_valid()` alone (the original code) or with `is_valid()` (the first fix) both still
error.

The reliable answer is not to hold a reference to a finished tween: `_forget_when_done()` connects
each tween's `finished` signal to clear its own variable, so the plain `!= null` check is finally
telling the truth. `_drive_tween()` then keeps the pause/resume logic in one place.

### Rule labels use the prose font

Rule labels wrap ("Shape is / blue or red?"), and they used `get_system_sans_font()`, whose line box
is **2.09x** the font size because a Font's line height is the MAX over its fallbacks and the Noto
Symbols fallback is very tall. That nearly doubled the gap between the wrapped lines.

They now take `MainGlobals.get_text_font()` (1.41x); only the ✓/✗ keeps the symbol face. See the
Fonts section in the project `CLAUDE.md` — the same trap applies to every wrapped label in the app.

### Passing a level

Each level carries a **`pass_pct`** — the accuracy needed to move on. Below it, the **same level is
played again** rather than the next one.

Before this, 70 was hardcoded in `globals.gd` for every level, and failing only re-queued the level
*behind* the next one — so a player could get every answer wrong and still advance, and the accuracy
shown in the level-done popup was decorative.

- `pass_pct_for(id)` reads the level's own value, falling back to `DEFAULT_PASS_PCT` (70) if a level
  omits it, so adding a level cannot silently make it ungated.
- `record_level_result()` now **returns** whether the player passed, and inserts the failed level at
  the FRONT of the queue.
- `_level_done()` passes that result into `sig_level_is_done` and `global_level_is_done`, so a failed
  level is no longer reported as a win.

The popup says what happens next, either way — "Accuracy: 55% (need 70%)" plus either
*"Level passed — on to level 3."* or *"You need at least 70% accuracy to pass to the next level."* The number alone never told the player the one thing they wanted to know.

Thresholds ramp with difficulty rather than sitting flat.

### History

The containers were drawn buckets and a dumpster (2026-10), each opening and reacting to a landing; the
item was a tile pair that fell down a drawn chute. All of it was replaced by the pool table on
2026-11-02 (see Visual style); the "♻ Dumpster" label had already become plain text when the
recycling glyph turned out to be missing from the prose font -- worth knowing for any label that mixes
prose and symbols.

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

## A replay starts clean

Failing the gate brings the same level round again, and that has to be a fresh attempt: the level's
own `new_game()` clears `total_rounds`, `total_corrects`, `game.corrects`, `game.mistakes` and
`times_to_answer` on EVERY level start, not just `if from_scratch`.

They were per-session before, which is wrong twice over. The visible half is the HUD still showing
the last level's correct/wrong tally. The half that mattered is that `pct_correct()` reads those
counters and the gate reads `pct_correct()` — so a replay inherited the misses that failed the
level, and even a flawless retry could not reach the threshold. (aliens always reset them here;
this is the other games catching up.)

`score` deliberately does NOT reset — it accumulates across a session, and only `game.reset(true)`
clears it.

The repaint sits next to the clearing (`MainGlobals.global_update_hud()`), not in `main.gd`.
Whether the HUD is refreshed after the level is rebuilt differs per game — polkadots never did it —
so the counters read 0 while the labels still showed the level the player had just failed. Clearing
a counter and showing the cleared value belong together.

## A failed level earns nothing

`_score_at_level_start` is stamped when a level begins, and a level that misses the gate restores
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

**The Answers tab is a 3x3, not a 2x2.** Three destinations means "wrong" splits three ways —
a matching item sent to the dumpster, a non-matching item sent to a bucket, and one bucket taken
for the other — and which way it split is the only thing a grid adds to a percentage.
`_evaluate_answer()` calls `game.record_choice(correct_bucket, bucket)`, which stores nine counts
`c00`..`c22`; `GameInstrument.THREE_WAY_GAMES` names the axes. Letting an item land is not a
missing answer: it *is* choosing the dumpster, so it goes through the same call as any other
choice and there is nothing here for `record_no_answer()` to count.

**Why the axis is the bucket POSITION and not the rule.** `_pick_pair_from_pool()` draws the two
rules at random *and in random order*, so a given rule is on the left in one session and the
right in the next. That is what makes a positional reading honest: pooling a level's sessions
averages the rule identity out, so a left/right lean that survives is about the side rather than
about one rule being harder. The confound would be a FIXED layout, not a shuffled one — and it
does mean a single session's grid confounds the two, since within one session the sides hold
still.

Response times are handed to the shared session record as a whole distribution, not just a mean: `game.record_times()` in `main.gd::get_game_score()` stores spread, median, within-session slope and lapse count beside the mean. The spread is the point — it moves before the mean does.

**Which RULE each item was against, alongside the 3x3.** `_evaluate_answer()` also calls
`game.record_trial({rule, rule_name, right, hidden, ms})`. The two rules are drawn from a pool
at random, so the grid says which KIND of mistake was made and the rule rows under it say ON
WHICH RULES — neither answers the other's question. An item matching NEITHER rule belongs to no
rule, so it is filed under "Matched neither" rather than credited to one of them.

`RULE_NAMES` is this game's own short noun per key, for the same reason as sortingrobots': the
rule labels are questions, and the name has to travel with the trial so the shared stats code
stays ignorant of this game's vocabulary.

`hidden` is recorded but nothing draws it yet — "accuracy before the rules are hidden, against
after" is one panel away.

**Before the rules are hidden, against after.** That is the difficulty curve of a level: up to then the rule is on
screen to read, after it the same judgement has to come from memory, and one accuracy for the
session averages the two together. `hidden` travels with every trial and
`GameInstrument._memory_split()` draws the two as accuracy bars under the grid. Generic over the
flag rather than reusing Polka Dots' `_visibility_split`, which reads a shown/chose pair this
game does not keep; both halves need `MIN_PER_BUCKET` rounds or the comparison is not one.

## The chooser tile

`art/game_screen_200.png` is drawn in Godot by `devtools/probe_sort_tiles.gd` (it needs a display):
two of the game's balls (`BallArt`, a blue star and a red disc), big and laid along the diagonal
(`BallArt.make(..., diag = true)`; the game keeps them side by side), on green felt framed by
snooker-mahogany rails with pearl diamonds and a big pocket in each corner -- clean, as the user asked. Two earlier
tries (crops and scenes of the table) did not convey the game.
The published copies: the games-doc build (`--site`) and the site's front-page `thumbnails/`.

## The colored-shape item's key is "shape"

`_gen_colored_shape` returns `{"shape": ..., "color": ...}`, and everything that reads it
(`_make_colored_shape`, MonkeyC's rule test) reads `"shape"`. A rename of a local `shape` -> `shp`
(it shadows a base-class member) also caught the dictionary KEY in all three sorting games, so the
"Shape is blue or red?" rule crashed building its first item ("Invalid access to property or key
'shape'"); fixed 2026-11-02. Rename the variable, never the key.

## Sounds

A POOL HALL ambient, as MUSIC (`bucketmadness_ambient.ogg`, `devtools/make_ambient_sounds.py` `pockets`, 2026-11-09: a slow blues -- walking bass, electric-piano comping, a light ride, a sax-like tune, the click of balls now and then; it was the sorting games' factory groove, with an air hiss on every off-beat, in what is now a billiard room) plays while the board is up (`main.gd` `show_level`, -6 dB) and stops at the menu. Its right/wrong sounds were inaudible until the shared registry stopped using positional players (see `scripts/generic_game_util.gd` `add_sound`).

Made for this game by `devtools/make_answer_sounds.py` (synthesized, seeded; one timbre per family of
games): a soft latch and machine chime for an item sorted right, a low note for wrong. They replaced an arcade coin and a swoosh shared by nearly every game in the app.
