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
├── level.gd          belts, item generation per rule, the judging window, claw, scoring
├── claw.gd           the arm that pulls a correctly picked item off its side
├── belt_edge.gd      belt trim
```

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

The screen was a tiled grass texture over a grass-green clear color — a field, in a game about
machines sorting objects on a conveyor. Being the largest single thing on screen, it is why
restyling the widgets on top of it kept failing to change what the screen looked like.

**This game is top-down.** The belts are conveyors seen from overhead, so the room is a FLOOR and
nothing else: `scripts/factory_floor.gd` (`FactoryFloor`) draws steel plates in a grid, parallel
seams both ways with a lit lip for thickness, bolts at every plate corner, painted hazard bands
down each edge, circular overhead lamp pools, and a vignette.

A top-down room has **no horizon and no vanishing point**. An earlier attempt drew a wall meeting a
floor at a horizon — a side-on view — and against top-down belts it read as a conveyor standing
upright against a wall. `FactoryFloor` has no `horizon` property at all, so that mistake cannot be
repeated by configuration.

Plate tint varies per plate from a hash of its grid position, not `randf()`: a tint chosen inside
`_draw()` reshuffles every frame and the floor shimmers.

`scripts/belt_tread.gd` (`BeltTread`) makes each belt an actual machine: an inset trough, slats
scrolling down it at 34 px/s, a lit lip on each slat's leading edge so the motion reads, side rails
and a roller at each end. Nothing on this screen moved before. It is added as child 0 of the belt's
PanelContainer, which stretches every child to fill — without `move_child(tread, 0)` the tread
paints over the objects instead of under them.

`belt_edge.gd` takes `Sleek.BELT_FILL` for its fade strips; it had a hardcoded copy of the old flat
green and went stale the moment the belt was restyled.

The old TextureRect is hidden rather than deleted — the scene file still owns it.


### The robots

Both games are named after them; neither had one on screen. The only "robot" that existed was a
transient gripper (`claw.gd`) spawned for the half-second of a successful pick-up and thrown away.

A first attempt stood arms in the gap beside each belt, and it was **worse than nothing**: pleasant
to look at, unconnected to anything, crowding the board while a separate claw did the actual
picking. An arm that is not doing the picking is scenery competing with the game.

`scripts/robot_arm.gd` (`RobotBay`) now bolts each base to the **screen edge**, clear of the belts,
and the arm **is** the claw:

- `hold(bay, flyer)` from `_claw_pull` hands the robot the flying item. It tracks that node's real
  position every frame, so the gripper is on the item and is dragged along as it is yanked off —
  not an animation playing next to it. It retracts by itself once the flyer is freed.
- The elbow comes from real **two-bone IK** (law of cosines), with the bend direction chosen per
  side so both arms flex away from the belt instead of one folding across it.
- Idle, the gripper tucks against the edge and drifts on a slow sine; it never crosses onto a belt.
- Jaws open while reaching and close once it has the item; the base lamp is amber at rest, green
  while working.

`claw.gd` is deleted from both games — the robot's own arm replaced it.

It is an overlay across the level rather than nodes in the layout, positioning itself from the
belts' rects every frame, because the layout resizes with the window and belt height is computed at
runtime by `_size_belts`.

### Feedback

The verdict was a label whose color changed and whose alpha went to 1 — the least noticeable way to
tell someone they got it wrong, on a screen where their eyes are on a belt somewhere else.

`_pop_feedback()` punches the ✓/✗ in to 1.45x and settles it (`TRANS_BACK`, measured peak 1.56x),
and `_flash_belt()` floods the **belt the round was about** with the verdict color, thickens its
edge to 6 px, and drains both back over 0.55 s.

The first version tinted only the belt's **2 px border** and was invisible in practice — a flash you
have to look for is not feedback. Measured, the fill now moves 1.07 in RGB distance (near-black to
red) where the border-only version moved nothing the eye could catch. If a visual change cannot be
measured as large, assume it cannot be seen.

### Items already ride in and out

Worth recording, because it was asserted twice as a gap and is not one. `_scroll_belts()` spawns new
items at negative y (above the belt) and only frees them once `position.y >= h`, fully past the
bottom; the containers are `clip_contents`, so both ends are hidden. Measured: a tracked item enters
at y = -65 and leaves below the belt's 472 px height. Nothing pops into existence.

### Thumbnail is stale

`art/game_screen_200.png` — the tile the game chooser shows — predates the visual rework (factory
scenery, running belts/chute, edge-mounted robots, drawn shapes, tiled text, animated feedback). It
still shows the old flat green-on-grass screen, so the chooser advertises a game that no longer
looks like this.

Regenerating it needs a **real display**: `--headless` uses a dummy renderer and cannot capture a
frame, so the game has to run windowed and save `get_viewport().get_texture().get_image()` scaled to
the existing 200 px tile. Worth doing in one pass for all three sorting games, mid-round, so the
belts have items on them.

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

The pitch between consecutive items on a conveyor is `item_h * randf_range(PITCH_MIN, PITCH_MAX)`,
never a pixel range. `item_h` is 72 on desktop and **100 on mobile**, and the pitch used to be a flat
`randf_range(80, 130)` — so the gap between boxes was 8..58 on desktop and **-20..30 on mobile**, and
the items overlapped each other vertically on every phone.

Measured, before and after, on the 680x1200 canvas: smallest gap **-19.2** then **+13.5** units.
Desktop is unchanged by construction — the fractions reproduce the old pixels exactly at
`item_h = 72` (72 x 1.111 = 80, 72 x 1.806 = 130).

Two code paths spawn items and BOTH need the pitch: `_init_belts()` fills the belt at level start and
`_scroll_belts()` adds new ones above as old ones leave the bottom. The second belt's head start
(`STAGGER_*`) is a fraction of `item_h` for the same reason.

## The belts hug the inside, the verdict lands on the item

Each belt box is aligned to the INNER edge of its half — `LeftBox` is `size_flags_horizontal = 8`
(shrink-end), `RightBox` is `0` (begin) — so the two conveyors sit together in the middle and the
robots have the outside to stand in. They were both shrink-CENTER, which put the free space between
them and pushed the robots almost entirely off a phone screen.

### The mark is monkeyc's, ported — not a variant of it

`_mark_item()` / `_pop_mark()` here are monkeyc's, copied. Getting there took four wrong attempts,
all of which came from one decision: this game discarded the highlight window BEFORE scoring, so the
mark had nothing to attach to and had to invent its own frame, its own position and its own
lifetime. Every problem followed from that — the tick appearing in the centre of the screen, a
second frame around the item, a frame that did not match the yellow one it replaced, and a crash
when the item was freed under the label.

The order is now monkeyc's: **mark first, while the panel is alive; tear down after.**

| | |
|---|---|
| the frame | the yellow highlight panel is RECOLOURED, never replaced — it keeps its exact rect, so the verdict frame lands precisely where the yellow one was. A separately drawn frame is always slightly the wrong size and reads as a second box |
| the glyph | a Label child of that panel, sized to it |
| the punch | on EVERY verdict: the glyph overshoots 0.3 -> 1.5 -> 1.0 and the panel flinches 1.0 -> 1.18 -> 1.0. That small increase-decrease is the decision landing |
| growing further | is the PICK-UP, and belongs to the claw (`_claw_pull`). Nothing else swells |

**A miss is marked like any other verdict, on the item, while it is still on the belt.** The timeout
fires at `item_y >= h - item_h` — when the item reaches the BOTTOM of the belt — not at `item_y >= h`,
after it has left. The old trigger came about 11 s after the window opened, at a moment when there
was nothing on screen to attach a verdict to, so letting an item go by really did look like nothing
had happened. It now calls `_mark_item(false)` with the panel still alive: same red X on the item,
same red frame, same belt wash as a wrong answer. Measured: the miss scores at ~9.5 s with the panel
and item both alive, glyph X, frame (1.0, 0.35, 0.0).

**A timeout has to show something too.** Letting an item go by reaches `_score_answer()` with the
window already discarded and the item scrolled off the bottom, so there is nothing left to stamp —
and the belt wash was inside `_mark_item()`, which returns early without a panel. Missing an item
therefore looked like nothing had happened at all: the score ticked down and the screen said
nothing. `_flash_belt()` moved out to `_score_answer()`, where it runs on EVERY outcome, and
`_discard_window()` remembers the belt in `_last_belt` so the wash still knows which one to colour
after the window is gone.

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
after the verdict has been seen. The old centre `FeedbackLabel` is removed from the tree outright in
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
