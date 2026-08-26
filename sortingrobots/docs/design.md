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

