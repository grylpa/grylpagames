# Sorting Robots — design

Two conveyor belts run down the screen, each with its **own rule** written at its head. Items scroll
past on both. Every so often a frame closes around one item, and you judge that item against the
rule of **the belt it is on**: swipe right to pick it up (yes, it matches), left to leave it (no).
A correct pick-up sends a robot claw out to yank the item off that side.

Then the thing the game is really about: **after a few rounds the rule labels fade away** and you
have to keep both rules in your head.

## Files

```
sortingrobots/scripts/
├── globals.gd        SortingRobotsG autoload: starting_level, save/load settings
├── level_config.gd   levels: the RULE POOL, hide_after, rounds, window_dur, belt_spd
├── main.gd           orchestrator: menu, HUD, instructions
├── level.gd          belts, item generation per rule, the judging window, scoring
├── tutorial.gd       the coached tutorial
```

Shared, in `scripts/`: `parcel_art.gd` (the items), `belt_tread.gd` + `belt_hood.gd` (the belt),
`factory_floor.gd` (the depot floor), `robot_arm.gd` (the robots), `sleek.gd` (palette, signs).

## Rules and pairing

`level_config.gd` lists a **pool** per level; the two rules actually shown are drawn from it at
random each time the level loads, so which rules appear and which belt each lands on varies between
plays. Rule keys: `digit`, `square`, `even_odd`, `vowel`, `prime`, `filled`, `hollow`, `stroop`,
`color_shape`, `lines`.

`_are_confusable()` keeps overlapping rules apart — a filled square satisfies both "is it a square?"
and "is it filled?", so those two are never shown together. A pool may safely contain both.

## A round

1. `_open_window()` picks a belt at random and frames an item that is still entering from the top,
   preferring one whose truth balances the yes/no spread so far. `window_target_truth` is whether
   that item satisfies THAT belt's rule.
2. The player swipes (or uses arrow keys) — `_input` → `_evaluate_answer(user_picks_up)`.
3. `_score_answer()` scores it: a speed bonus on top of 10 for a right call, a small penalty for a
   wrong one or a timeout at `window_duration`.
4. After `rounds_before_hide` judgments, `_hide_labels()` fades both rule labels to alpha 0.

## Tutorial

`sortingrobots/scripts/tutorial.gd`, entry `sortingrobots/scripts/main.gd::start_tutorial()`.

Two things make this game confusing on first contact, and neither survives being written in a
paragraph:

- **The framed item is judged against its OWN belt's rule**, not against whichever rule you happen
  to be reading. With two rules on screen it is natural to check the wrong one.
- **The rules disappear.** It happens six rounds in, just as the player has settled, and reads as
  the game breaking rather than as the point of it.

So the tutorial names the belt and its rule at the moment the frame appears (the caption is built
from the live label text), and then makes the labels vanish deliberately, with the coach present to
say what just happened.

Specific to this game:

- Level 1's pool is `digit` / `square` — two rules a first-timer can hold without effort.
- `window_duration` is pushed out of reach for the tutorial and restored: judging under a 3 s clock
  while reading a caption is not a fair introduction.
- `rounds_before_hide` is pushed out too, so the labels vanish exactly when the coach says so
  rather than mid-explanation.
- **The belts stop for the tutorial.** `_open_window()` deliberately frames an item that is still
  ABOVE the belt so the frame slides in with it — which during a tutorial puts the frame over the
  rule label, reading as though the RULE were framed. In tutorial mode the belts run on until the
  framed item clears the label, then `tutorial_hold_belts` stops everything and `window_settled` is
  reported; the hold lifts when the judgment is made.
- **The staging is never announced.** The second judgment is forced to be a non-match, but the
  caption does not say so: it is written before the item has even been chosen, so a promise made
  there is one the tutorial cannot keep by itself. The player judges for themselves; the staging
  only guarantees they meet both answers.
- **The player meets both answers.** `_open_window()` only PREFERS a truth that balances the yes/no
  spread, so two "leave it" rounds in a row are perfectly possible and a player could finish having
  never picked anything up. `tutorial_want_truth` makes the first judgment a match and the second a
  non-match, and while it is set the picker waits for an item of that kind rather than settling for
  whatever is closest.
- Events reported to the coach: `window_opened`, `window_settled`, `judged`, `labels_hidden` — all
  `game.tutorial_notify`, no-ops outside tutorial mode.

---

## Visual style: a parcel depot (2026-11-02)

The game looked plain for a long time -- white glyphs on dark tiles, grey steel, then a "workshop at
night" in warm wood -- and the items were the problem, not the room. Now:

### The items are parcels (`scripts/parcel_art.gd`, `ParcelArt`)

Each pair is ONE real 3-D cardboard box with the pair's two items on **two equal cards** on its lid.
**The pair stays two equal things** (the user's point, and the game's: the player must first work out
which of the two the rule is about) -- same size, side by side with a gap, each card turned its own
way; a wide card (a stroop word) only gets wider. Drawn 2-D boxes were tried first, several times,
and read as cartoons; this is a mesh with a CC0 cardboard material (`art/cardboard/`, ambientCG
Cardboard004 at 512 px, `README-LICENSE.md` beside it), crumpled, dented, with BOTH tape strips on
every box (lengthways and crossways, each off-center and a little slanted), a lamp behind it so the
lid is lit and the front fold reads, boxes of slightly different sizes turned 6-14 degrees so a side
shows. The camera looks down at 50 degrees (62 read as flat lids).

**Cheap on a phone:** 16 box variants are rendered ONCE per item size into images; every item picks
one; there is no 3-D while playing. The **cards are 2-D**, drawn through the exact (affine,
orthographic) mapping of the lid, so they stay sharp and their colors are EXACTLY the game's --
`level.gd` builds the same Labels the rules always made and hands only what each says (text or shape,
color, font) to `ParcelArt.make` (`_item_desc`).

**The rule tests compare item colors for EQUALITY** (`item["color"] == _color_values[word]`), so
every color must still come from `Sleek.PALETTE`; the cards draw them unlit for the same reason.

The belt starts EMPTY and parcels only enter from the top (`_init_belts` spawns above the belt only):
filling it at once made them pop in one by one at random places as their pictures finished rendering.

### The depot

- **Floor** (`scripts/factory_floor.gd`, `FactoryFloor`, TOP-DOWN -- no horizon): dark warm concrete
  with saw-cut joints, curing marks, stains and trolley scuffs; worn yellow lane lines along each belt
  (the game feeds `belts` from `_position_robots`); litter -- stamped envelopes, torn-off shipping
  labels, strips of tape -- never on a belt or behind the signs; and depot props in the free floor
  (rendered by the parcels' own renderer: a stacked pallet, a loose pile of boxes, a pallet with one or
  two left), one or two a side, each at its own height, size and kind -- four identical pallets in four
  corners read as staged. Too narrow a margin gets none (Sorting Robots' two wide belts leave little).
- **Belts**: a ROLLER conveyor (`scripts/belt_tread.gd`, steel rollers turning, brass side rails) under
  a dark housing with a brass lip across each end, drawn OVER the items (`scripts/belt_hood.gd`), so a
  parcel comes out from under the top one and goes back under the bottom one. Both games build the
  belt the same way (it used to differ: here items slid in over the belt's top frame). `belt_edge.gd`
  (fade strips past the belt's ends) is deleted.
- **Rule signs** (`Sleek.header`): blue enamel depot signs with a cream rim.
- Belts are 225 wide (310 on a phone); `item_h` follows from it (`belt_w * ParcelArt.ASPECT`).

### The item in question, and the verdict

- **In question**: the flat yellow frame is gone (it looked pasted on over a 3-D box). The parcel's
  `set_spotlight(true)`: amber LEDs along both of the belt's rails level with it, a lit strip behind
  them and a chase running through them, and a warm glow on the belt UNDER the box (over it, it dimmed
  the cards). The window panel stays, INVISIBLE, for the tutorial's spotlight and the claw's grip.
  Tried and turned down: the box lifted into lamplight, a red scanner laser.
- **Verdict**: `ParcelArt.stamp(ok)` -- a solid seal (a green ✓ or red ✗ in a filled disc, white
  mark) thumps onto the box's FRONT EDGE below the cards, facing the viewer, with a small squash of the
  box. Thin ink outlines were lost on both the cards and the cardboard.
- **One active item at a time**: flagging a new item clears the last one's seal (`clear_stamp`).
- **No belt wash**: `_flash_belt` (the whole belt flooding with the verdict color) is removed -- the
  user disliked it, and the seal is the answer. A miss still shows: the main timeout path stamps a red
  ✗ on the box before it leaves the belt.

### The robots

`scripts/robot_arm.gd` (`RobotBay`) bolts each base to the screen edge and the arm IS the claw:
`hold(bay, flyer)` from `_claw_pull` hands it the flying item, real two-bone IK, jaws open while
reaching. Orange-painted since the warm look.

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

## Belt spacing scales with the item

The pitch between items is `item_h * randf_range(PITCH_MIN, PITCH_MAX)`, never a pixel range (a flat
80-130 px once made items overlap on a phone). With parcels -- taller than the old tiles -- it is
**1.04-1.30** (it was 1.111-1.806), so the belt holds enough items; the second belt's head start
(`STAGGER_*`) is a fraction of `item_h` too.

## The belts hug the inside, the verdict lands on the item

Each belt box is aligned to the INNER edge of its half — `LeftBox` is `size_flags_horizontal = 8`
(shrink-end), `RightBox` is `0` (begin) — so the two conveyors sit together in the middle and the
robots have the outside to stand in. They were both shrink-CENTER, which put the free space between
them and pushed the robots almost entirely off a phone screen.

### The mark is monkeyc's, ported — not a variant of it

`_mark_item()` / `_pop_mark()` here are monkeyc's, copied. Getting there took four wrong attempts,
all of which came from one decision: this game discarded the highlight window BEFORE scoring, so the
mark had nothing to attach to and had to invent its own frame, its own position and its own
lifetime. Every problem followed from that — the tick appearing in the center of the screen, a
second frame around the item, a frame that did not match the yellow one it replaced, and a crash
when the item was freed under the label.

The order is now monkeyc's: **mark first, while the panel is alive; tear down after.**

| | |
|---|---|
| the frame | the highlight panel is INVISIBLE now; the item in question is marked by the parcel's rail lights (see Visual style) and the panel stays only as an anchor |
| the verdict | a seal stamped on the parcel's front edge (`ParcelArt.stamp`); the old ✓/✗ label on the panel is the fallback for a non-parcel item only |
| the punch | the seal lands from above with a small squash of the box |
| growing further | is the PICK-UP, and belongs to the claw (`_claw_pull`). Nothing else swells |

**A miss is marked like any other verdict, on the item, while it is still on the belt.** The timeout
fires at `item_y >= h - item_h` — when the item reaches the BOTTOM of the belt — not at `item_y >= h`,
after it has left. The old trigger came about 11 s after the window opened, at a moment when there
was nothing on screen to attach a verdict to, so letting an item go by really did look like nothing
had happened. It now calls `_mark_item(false)` with the panel still alive: same red X on the item,
same red seal as a wrong answer. Measured: the miss scores at ~9.5 s with the panel
and item both alive, glyph X, frame (1.0, 0.35, 0.0).

(The score is `min(3, score)`, so a miss costs nothing at zero. That is the game's own floor, not a
missing penalty — worth knowing, because it makes a naive "did the score drop?" test fail.)

`_track_window_panel()` keeps the frame on the item every frame while the verdict is up. The panel
only ever followed the item while the window was ROLLING OUT; after an answer nothing moved it, which
never showed while the panel was discarded the instant the player answered. Now that it lives through
the verdict and the belt keeps scrolling underneath, a frame left at a fixed y slides off the item it
marks — measured, it drifted 7.5 units in 18 frames, and holds to 0.0 with the tracking. It does not
track an item the claw has carried off: `_claw_pull` reparents it into a flyer, and chasing a node in
another coordinate space would throw the frame across the screen.

`_discard_window()` is no longer called from `_evaluate_answer()`; `_score_answer()` frees the panel
after the verdict has been seen. The old center `FeedbackLabel` is removed from the tree outright in
`_ready()` — an unused Label left in `ContentVBox` silently reserves its height.

## _size_belts measures the column, it does not list it

The belt gets the room left after everything ELSE in `ContentVBox`, and that "everything else" is
**measured** — every visible child's `get_combined_minimum_size().y`, plus the container separations
and `LeftSide`'s own rule-to-belt separation — rather than written out by hand.

A hand-written subtraction misses a child the moment one is added or one stops being reparented
away, and that is exactly how it broke: sortingrobots lifts its `FeedbackLabel` out of the flow in
`_ready()`, monkeyc left it in at **alpha 0** — invisible but still occupying its height — so the
belt height copied across overshot by that label, the column outgrew its VBox, the spacer collapsed
and the status line rode up under the app's top bar. monkeyc's label is now `visible = false`, since
a transparent Control still takes space and this game does not use the label at all.

Checked at both canvas sizes: the column's combined minimum is inside the room MainLayout gives it,
with slack, rather than overflowing it.

## The belt EXPANDS; the computed height is only a floor

`ContentVBox`, `BoxesRow`, `LeftSide`/`RightSide` and the belt boxes all carry
`size_flags_vertical = SIZE_EXPAND_FILL`, and the two spacers no longer expand — so the belt takes
whatever height is actually left rather than the height `_size_belts()` predicted. That computed
value is now a MINIMUM only, a floor for a very short window.

This is deliberate after two failed attempts at getting the number right by arithmetic: the belt came
out too short, and the sizer could not be checked here because the containers never sort in a
headless run (every node reports the same `global_position.y`, so measured positions are worthless).
Letting the container do the arithmetic removes the guess entirely.

`LeftSide`'s rule-to-belt separation is **12**, not 4, so the belt's top edge is unmistakably clear
of the rule text above it.

`TopSpacer` reserves a fixed 34 rather than expanding. It used to expand, and removing that expand
(so the belt could have the room instead) let the column start right under the header, where the
game's status line collided with the app's level string.

## What this game measures

Session records are the v6 named-dictionary format (see `scripts/generic_game_util.gd`
and `scripts/session_stats.gd`). Metrics reset centrally in `reset(from_scratch)`.

Response times are handed to the shared session record as a whole distribution, not just a mean: `game.record_times()` in `main.gd::get_game_score()` stores spread, median, within-session slope and lapse count beside the mean. The spread is the point — it moves before the mean does.

Accuracy is stored as four counts, not a percentage: `game.record_answer(said_yes, was_yes)` at the decision point. A percentage cannot separate how well the player tells the cases apart from how willing they are to say yes, and someone compensating for a slip by guessing more holds the percentage steady while both hits and false alarms rise. Unanswered trials go to `record_no_answer()` and never into the four counts — no decision was made, so calling it a "no" would invent one.

Picking up is the yes and `window_target_truth` the truth. Timeouts are recorded separately in `_score_answer()`.

**Which RULE each judgement was against, and whether its label was still up.**
`_evaluate_answer()` calls `game.record_trial({rule, rule_name, right, hidden, ms})` beside the
four counts. Both belts draw from a pool at random (`_pick_pair_from_pool`), so one percentage
for the session cannot say that the player reads "is it prime?" easily and never sees the Stroop
rule — and the difficulty curve here IS the labels going away, which the same percentage also
hides. `GameInstrument._rule_breakdown()` draws a row per kind of rule under the 2x2, hardest
first, for the level the picker is on.

`RULE_NAMES` is a short noun per key, kept here rather than in the shared stats code: the rule
labels are questions ("Is it a digit?"), which read badly as a row heading, and even_odd's
wording flips between "even" and "odd" while the rule behind it is one thing. The name travels
with the trial, so `scripts/game_instrument.gd` needs to know nothing about this game's
vocabulary.

`hidden` is recorded but nothing draws it yet — the "accuracy before the labels fade, against
after" split is one panel away, and the data is accumulating for it now.

**Before the rule labels fade, against after.** That is the difficulty curve of a level: up to then the rule is on
screen to read, after it the same judgement has to come from memory, and one accuracy for the
session averages the two together. `hidden` travels with every trial and
`GameInstrument._memory_split()` draws the two as accuracy bars under the grid. Generic over the
flag rather than reusing Polka Dots' `_visibility_split`, which reads a shown/chose pair this
game does not keep; both halves need `MIN_PER_BUCKET` rounds or the comparison is not one.

## The chooser tile

`art/game_screen_200.png` is drawn in Godot by `devtools/probe_sort_tiles.gd` (it needs a display): a
single cute robot with six arms (the user's idea) -- a glass-dome head on a metal neck, a narrow tapered torso (a plain pill read as a bean) floating on a glowing hover base -- each arm holding a shape in `Sleek.PALETTE`, on a deep
navy ground. The arms are straight steel limbs with one orange elbow joint each and a two-finger
gripper, dark-outlined so they stand out, and NOT mirrored -- each its own reach and bend (a
symmetric ring of curved arms read as a spider). Each held shape has a fixed spot more than 100 apart from the others and the arm is worked back from it; no square (a big green one read as a slab). Two earlier tries -- a crop of the game screen, then a scene from it (a parcel and the
robot arm) -- did not convey the game; a tile says what the game is about in one look.
The published copies: the games-doc build (`--site`) and the site's front-page `thumbnails/`.

## The colored-shape item's key is "shape"

`_gen_colored_shape` returns `{"shape": ..., "color": ...}`, and everything that reads it
(`_make_colored_shape`, MonkeyC's rule test) reads `"shape"`. A rename of a local `shape` -> `shp`
(it shadows a base-class member) also caught the dictionary KEY in all three sorting games, so the
"Shape is blue or red?" rule crashed building its first item ("Invalid access to property or key
'shape'"); fixed 2026-11-02. Rename the variable, never the key.

## Sounds

A FACTORY ambient, as MUSIC (`sortingrobots_ambient.ogg`, `devtools/make_ambient_sounds.py` `factory_music`: a mechanical groove -- clanks on the beat, air on the off-beat, a plucked bass, a metallic marimba ostinato over moving chords, a steel-pan tune; it was a motor's hum with roller ticks, one held tone) plays while the board is up (`main.gd` `show_level`, -6 dB) and stops at the menu. Its right/wrong sounds were inaudible until the shared registry stopped using positional players (see `scripts/generic_game_util.gd` `add_sound`). The ROBOT is heard too (`devtools/make_action_sounds.py`, "robot"): `grab` (a servo whirring up, the claw clamping, an air whoosh) whenever an arm takes an item (`_claw_pull`), so a correct pick-up (ding and the arm's grab) now sounds different from a correct let-go (the ding alone). It is mastered by its audible band (`music.master`); the old loop's motor hum was below what a small speaker plays, so it seemed to start late, with the first roller tick.

Made for this game by `devtools/make_answer_sounds.py` (synthesized, seeded; one timbre per family of
games): a soft latch and machine chime for an item sorted right, a low note for wrong. They replaced an arcade coin and a swoosh shared by nearly every game in the app.
