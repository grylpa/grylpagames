this  Bucket Madness — Design Doc

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

---

## Visual style

The objects on the belt are **drawn**, not typeset. They used to be font glyphs in a Label — `"■"`
tinted `Color.RED` — which is the whole reason this game looked flat: a glyph is one silhouette at
whatever weight the font happens to have, in the most saturated red a screen can produce, with no
shading anywhere.

`scripts/sleek.gd` (`Sleek`) draws each shape with a contact shadow, a vertical gradient and a rim
light along the top edge — the three things a real object does under a light — and
`scripts/shape_label.gd` (`ShapeLabel`) wraps that as a **Label subclass**, so the pair-layout pass
that measures both objects and shares the row width between them is untouched. The text is still
set, because that is what the layout measures; it is just painted transparent.

The palette moved there too. `Color.RED` is literally `(1, 0, 0)`: it vibrates against a dark
background and has no headroom left to lighten into, so a gradient has nowhere to go.

### Shapes were only part of it

Measured across all ten rules, 40 items each: **only four rules produce shapes** (`square`,
`filled`, `hollow`, `color_shape`) — 160 of 400 items. The other six produce **digits, letters and
words**, and no amount of shape drawing touches those: a bare "7" on a flat belt looks exactly as
unfinished as a flat square did.

So every object, text or shape, now sits on the same **tile**: rounded, slightly raised, soft
shadow (`Sleek.tile()`). That is what turns a character into an object, and it is the change that
makes text and shapes look like they belong to the same game. Coverage is asserted rather than
assumed: 400/400 items in each game are either a drawn shape or tiled text.

The tile goes on as the Label's `"normal"` stylebox, which draws **behind** the text. A script's
`_draw()` on a Label paints *over* it — right for the shape, useless for a backing card.

**The one thing to be careful with:** item colors are compared for **equality** by the rule tests
(`item["color"] == _color_values[word]` for stroop, `c == BLUE or c == RED` for colored shapes), so
every color must come from `Sleek.PALETTE` and nowhere else. A raw `Color.BLUE` left behind
anywhere silently stops matching and the rule quietly becomes unsatisfiable — there were three such
sites per game, and they are now all lookups.

### The chrome

The belts were the largest thing on screen after the background and the flattest of all: a
`PanelContainer` whose entire style was `bg_color = Color(0, 0.06, 0, 0.6)` — no border, no corner
radius, no shadow. Two 140x420 slabs of flat dark green over a grass photo. Restyling the objects
ON them could never fix that, which is why the first passes barely showed.

`Sleek.belt()` gives them rounded corners, a lit top edge, a darker base and a real drop shadow, so
the machine sits on the scene instead of being a hole cut in it. `Sleek.header()` puts each rule on
a chip that belongs to the belt below it, rather than bare yellow text floating on grass.
Bucketmadness has no belts — its chute (`_trap_poly`) takes the same `BELT_FILL`, so the three
games read as one family.

Applied from `_apply_sleek_chrome()` in `_ready()` rather than by editing the scene's sub-resources,
so the styling lives with the rest of the look.

### The scene

The whole screen was `res://art/grass.png` — a photographic grass texture, in a game about machines
sorting things. It covered 100% of the pixels and had nothing to do with the subject, which is why
restyling the widgets on top of it kept failing to change what the screen looked like.

`scripts/sleek_scene.gd` (`SleekBackdrop`) draws an interior instead: a vertical gradient wall, a
darker floor below a horizon line at 70% height, a pool of light over the play area, and a vignette
closing the corners so the center reads as lit. Drawn rather than an image, so it scales to any
screen with no second asset and the palette stays with the rest of the look. The old TextureRect is
hidden, not deleted — the scene file still owns it.

`scripts/belt_tread.gd` (`BeltTread`) makes a belt an actual machine: an inset trough, slats
scrolling down it, a lit lip on each slat's leading edge, side rails and a roller at each end.
**Nothing on these screens moved before** — that, as much as the flat color, is what made them read
as a list of labels rather than something running. It is added as child 0 of the belt's
PanelContainer, which stretches every child to fill: without `move_child(tread, 0)` the tread paints
over the objects instead of under them.

The tread runs at 34 px/s on purpose. Background motion that competes with the objects the player
is trying to read is worse than none.

`belt_edge.gd` now takes `Sleek.BELT_FILL` for its fade strips. It had a hardcoded copy of the old
flat green and went stale the moment the belt was restyled.

### The chute and the buckets

The fall area was a single flat-colored trapezoid — one `Polygon2D`, covering the largest part of
the play area, with no edges, no depth and nothing moving in it. The falling object was the only
thing that ever changed.

`scripts/chute_view.gd` (`ChuteView`) draws it as an actual chute: walls darkening toward the
sides, rails down both slanted edges, a shadow under the mouth, a pool of light at the bottom where
the item is heading, and chevrons drifting downward so the chute reads as flowing the way the item
is about to. The chevrons are the belt-tread idea from the other two sorting games, so the three
look like one family. The flat trapezoid stays underneath as a base fill so nothing shows through
where the two disagree by a pixel.

**`_clear_fall_area()` had to learn about it.** It frees every child of `%FallArea` except
`_trap_poly`, so the chute was destroyed at the end of the first round and the game ran in an empty
box from then on. Anything scenic added there needs the same exemption.

The buckets now **react to catching an item** (`_bucket_react`): a squash-and-settle plus a brief
brightening when the answer was right, a short shake when it was wrong. Nothing on this screen used
to move on a drop except a tick appearing in a label — the buckets sat perfectly still either way,
which is most of why the game felt inert.

### Thumbnail is stale

`art/game_screen_200.png` — the tile the game chooser shows — predates the visual rework (factory
scenery, running belts/chute, edge-mounted robots, drawn shapes, tiled text, animated feedback). It
still shows the old flat green-on-grass screen, so the chooser advertises a game that no longer
looks like this.

Regenerating it needs a **real display**: `--headless` uses a dummy renderer and cannot capture a
frame, so the game has to run windowed and save `get_viewport().get_texture().get_image()` scaled to
the existing 200 px tile. Worth doing in one pass for all three sorting games, mid-round, so the
belts have items on them.

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

### The containers are drawn

The three containers were illustrated PNGs sitting among a screen that is otherwise entirely drawn —
the factory wall, the chute, the object tiles, the shapes. They read as pasted in from a different
game, and being fixed images they could not react to anything either.

`scripts/bucket_view.gd` (`BucketView`) draws them in the same palette: a tapered body with a lit
side and a shaded edge, a dark mouth so the container reads as hollow, a rim, and two hoops. The
dumpster is the same object drawn wider, squarer and with a hazard band, so it stays visibly the odd
one out without belonging to another art style.

Because the lid is drawn, `open_amount` (0..1) is a real angle: it is **tweened**, so the flaps
swing. Measured, 20 intermediate values across a 0.18 s open.

**A mistake worth recording.** An earlier attempt animated the shipped sprites instead, assuming
`bucket_closed` / `bucket_open_1` / `bucket_open_2` were three frames of one bucket because of their
names. They are not related images, so swapping between them looked like the bucket being *replaced*
rather than opening. Filenames are not evidence about what a picture contains; the only ways to know
are to look at it or to draw it yourself.

`scripts/bucket_stage.gd` (`BucketStage`) still gives them a floor: one shelf spanning the row, a
contact shadow under each, and a puff of dust when something lands. It draws under the containers
and reads their live rects each frame, since the row is laid out by a container.

### The item goes IN

It used to tween to `h + 20` inside `%FallArea`, which is `clip_contents` — so it was cut off at the
bottom of the chute and **vanished in mid-air above the buckets**. It never reached one, which made
the whole point of the game invisible.

It is now reparented to the `BucketStage` for the last leg. That fixes both halves at once: the
stage is not clipped, and it sits UNDER the containers in the tree, so the item is **occluded by the
bucket's front wall** as it drops in rather than sliding across it. It shrinks to 0.45 on the way
down, which reads as going into the container rather than onto it, and the dust puff fires on
arrival rather than at the moment of judgement. Measured: the item finishes 5 px from the mouth,
from 490 px away at release.

**Z-order matters as much as the reparent.** The stage sits below `MainLayout` in the tree, so on
its own that hid the item behind the chute for the entire journey — it only reappeared as it entered
the container, which looked like it had teleported. The item takes `z_index = 4` and the containers
`z_index = 8`, so the order is chute (0) < item (4) < containers (8): visible the whole way down,
and still occluded by the bucket's front wall at the end.

### Bucket vs dumpster

They differed only in width, which is not a difference a player can name, and the dumpster wore a
straight yellow band that meant nothing and fought the rounded shading around it.

They are now different **objects**: the bucket is a cylinder, the dumpster a box.

Two geometry mistakes worth recording, because both made the shapes read as wrong rather than as
plain:

- **A cylinder's base is an ellipse, not a line.** The mouth is drawn as an ellipse because we look
  slightly down into it, so a flat bottom edge contradicts it — the whole thing reads as a flat
  trapezoid wearing a round lid. The silhouette now runs down the left wall, around the FRONT of
  the base ellipse, up the right wall and back across the front of the mouth, as one closed shape.
  Its hoops follow the same curve instead of cutting straight across.

  The first attempt at that outline walked the base arc **right to left** while the previous point
  was the bottom-LEFT corner, so the loop folded back over itself: `Invalid polygon data,
  triangulation failed` — 618 times in a single run, and nothing drawn. `bucket_silhouette()` is a
  method so a probe can test the real outline for self-intersection; the probe that missed this
  rebuilt the same maths itself and confirmed its own bug.
- **Nothing may be drawn below the dumpster's far top edge.** The top face recedes UP the screen
  (it is the opening); an earlier version also drew a "far wall" polygon below that edge, which put
  a solid surface inside the hole and made the box look inside-out. The faces are now drawn side,
  then opening, then front — back to front — and the lid hinges along the far edge and folds back
  over the top.

### Buckets have no lids

The buckets briefly grew two hinged flaps that swung out of the rim as an item approached. Buckets
are open-topped containers; the flaps existed only because an open/close animation was wanted, and
on screen they read as two diagonal lines appearing from nowhere.

They are gone. "Ready to receive" is now a lift in the rim color and a little light down the inside
wall — what an open container catching the light would actually do. `open_amount` still drives it,
so the timing is unchanged.

**The dumpster lid folds, it does not swing.** Its hinge is a horizontal axis in the scene, so the
lid must foreshorten as it lifts: the projected depth shrinks by `cos(angle)` while it rises by
`sin(angle)`. It was being rotated as a 2D vector (`span.rotated()`), which swung it sideways across
the screen — which is exactly why the shut lid looked right and the open one did not. Shut, the two
methods agree; they only diverge as it opens. Measured: horizontal reach from the hinge falls 21 px
to 3 px while the tip rises, and the panel stays rigid.

### Only the chosen container reacts

All three used to open the moment an item was released. That says nothing — no choice has been made
yet, so three containers gaping at once is just movement. They now stay shut while the item falls,
and `_open_one()` opens **only the one the item is going into**, at the moment the answer is given.

### Going in, not behind

The item was at `z_index = 4`, under the containers (z 8), so the container's body covered it as
soon as they overlapped: it read as sliding out of sight BEHIND the bucket rather than dropping into
it. Being occluded is the wrong tool here — the mouth is drawn as part of the same node, so there is
no "inside" to be occluded by.

It now draws **above** the containers (z 12) and sells going in the way a falling object does:
shrinking to 0.12 as it descends, and fading out only over the **last third** of the trip, so it
stays solid all the way to the rim and disappears as it passes below it. Measured: solid while more
than 40 px from the mouth, faded within it.

### The dumpster label, and a tofu trap

The label read "♻ Dumpster". After the prose/symbol font split it renders as a **blank box**: the
no-fallback face has no U+267B, verified with `Font.has_char()`. The glyph was also wrong in meaning
— a recycling symbol on the bin for things that match *neither* rule implies sorting for reuse,
which is the opposite. It now reads "Dumpster", and the drawn container carries the meaning.

**The general trap:** splitting prose from symbols means any label that mixes them silently loses
its glyph. A runtime scan over every Label and Button in six games checked 14 non-ASCII glyphs
against the font each one is actually using and found 0 missing — worth re-running after any font
change, since nothing about a tofu box shows up as an error.

### The dumpster reacts too

Its opening brightens and its front lip catches the light as it receives, the same cue the bucket
mouths use. It was the only container that gave nothing back when something went into it.

### The chute is hardware

It was a dark trapezoid with chevrons and two hairline rails. It now has: rails as tapering bands
with rivets and a lit inner edge, a bolted lip across the mouth so it reads as fixed to something
above rather than being a hole, a shadow under that lip so the throat recedes, and a flared bottom
edge that catches the light — so the chute visibly DELIVERS into the row of containers instead of
merely stopping above them.

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
