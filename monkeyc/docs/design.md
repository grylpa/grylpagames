# Monkey C — Design Doc

## Overview

The player watches a robot sort items on one or two endless conveyor belts without seeing the rule. A yellow window slides in on an item; when the item reaches the h/2..3h/4 band the robot picks up (✓, item removed) or leaves it (✗); the ✓/✗ answer appears `robot_answer_time` earlier. After `min_examples` examples per active belt rule, a multiple-choice question asks the player to identify the hidden rule.

## File Structure

```
monkeyc/
├── scripts/
│   ├── globals.gd        # Autoloaded as MonkeyCG
│   ├── main.gd           # Orchestrator
│   ├── level.gd          # Core gameplay
│   └── level_config.gd     # Autoloaded as MonkeyCLevelConfig
└── scenes/
    ├── main.tscn
    └── level.tscn
```

Independent game: it has its own `monkeyc/art/` folder (just the chooser thumbnail) and uses only shared root assets from `res://art/` (e.g. `grass.png` background); the shape/digit/letter objects are drawn as **font glyphs** (Labels), not images. No files reference or depend on rlmadness. Sounds from `res://art/sounds/`.

## Autoloads

- `MonkeyCG` — `globals.gd`; owns `GenericGameUtil.new("Monkey C", "monkeyc", 0, 10, 0, 0)`; manages level queue, settings (`starting_level_id`, `use_uppercase`)
- `MonkeyCLevelConfig` — `level_config.gd`; provides `LEVELS`, `LEVEL_PROGRESSION_ORDER`, `get_level(id)`, `level_names()`, `id_to_index(id)`

## Gameplay Design

### Demo phase (endless conveyor)

Both belts (or just the left for 1-belt levels) scroll continuously. Items enter from the top. A yellow window slides in on an item and scrolls with it. The ✓/✗ answer shows at `_mark_top`, then the robot acts when the item reaches the take band (h/2..3h/4):
- **Pick up** (item matches rule): window flashes green with ✓, item is removed from belt.
- **Reject** (item does not match): window flashes red/orange with ✗, window disappears (item continues scrolling).

The window only opens on belts that still need more examples. `next_window_timer` (0.8–1.5s random) controls gap between actions.

If an item exits the bottom before the robot acts, the window is silently discarded (no example counted).

### Example counting

`examples_per_belt[0]` and `examples_per_belt[1]` count robot actions (pick-up or reject) per belt. When all active belts reach `min_examples`, demo phase ends and question phase begins.

### Question phase

For each active belt in order, a full-screen overlay shows a multiple-choice question with `num_options` options. The correct answer is the modality label for that belt's rule; every wrong answer is validated against the demos first (see Key Pitfalls) so it is always one the player could have ruled out.

- Correct: +10, green highlight on correct button
- Wrong: −min(3, score), red on chosen, green on correct

After all questions are answered, `rounds_done` increments. If `rounds_done >= num_rounds_per_level`, level ends. Otherwise, demo resets and repeats.

### Scene Layout

Uses the same scene structure as Sorting Robots:
- `%LeftItemsContainer` / `%RightItemsContainer` — clip_contents=true, direct item children
- Right side hidden for 1-belt levels
- `%AvgTimeLabel` — always reads "Watch the robot..."; the mean option-selection time is deliberately NOT shown mid-level (it measures how fast the player names the rule, not anything about the belt). Still tracked in `times_to_answer` for the score row and level-end popup.
- `%FeedbackLabel` — not used in demo; question feedback handled inline by button highlights
- `%LeftRuleLabel`, `%RightRuleLabel` — always hidden (alpha=0); no rules shown to player

### Items

Each belt item is a **pair** (two objects side by side), identical to sorting robots: `current_pair[0]` (left modality) and `current_pair[1]` (right modality), with display order randomised per item. `truth_l` = whether left-modality object matches left rule; `truth_r` = right-modality vs right rule. The robot acts on `truth_l` for the left belt and `truth_r` for the right belt — the player must figure out which modality the robot is using.

`PAIR_FONT_SIZE = 32`, `ITEM_H = 72.0` — identical to sorting robots. Items scroll at `belt_spd` px/s with random spacing (80–130 px). The window `Panel` tracks its target item every frame (including during robot action animation) so it never freezes.

## Levels

5 levels, cycling via `LEVEL_PROGRESSION_ORDER = [1,2,3,4,5,3,4,5]`:

Each level defines a **`rules` pool**, not a fixed left/right pair. Every **round**, `_pick_pair_from_pool()` shuffles the pool and takes the first two **distinct, non-confusable** keys, so the hidden rule changes from round to round instead of being the same one all level. For 1 belt the first pick is the hidden rule and the second is a visible decoy attribute; for 2 belts both picks are hidden rules (one per belt). A bigger pool = harder and less predictable.

An **empty** `rules` list means "use every rule". Overlapping rules may safely share a pool — `_find_rule_pair` only ever returns a legal combination. The pair used last time is also avoided whenever the pool offers an alternative, so replaying a level (or wrapping around the progression order) doesn't serve up the same two rules again.

**Stroop sizing.** The two objects of an item do **not** split the width 50/50 — a stroop word ("YELLOW") is many times wider than a glyph and used to spill over its half and collide with the other object. `_share_pair_widths` gives each object a share proportional to its natural text width (clamped to 18–82% so neither is starved), then `_fit_label_width` shrinks each font until its text fits the share it got. On a 220px belt the word keeps its full size; only narrower items shrink it.

| ID | Name   | Rules pool | Belts | Belt spd | Robot answer time | Min ex | Rounds | Options |
|----|--------|-----------|-------|----------|-------------------|--------|--------|---------|
| 1 | Simple | digit, square | 1 | 55 | 5.8s | 4 | 3 | 2 |
| 2 | Even | even_odd, vowel, hollow | 1 | 60 | 1.6s | 4 | 3 | 3 |
| 3 | Two | hollow, vowel, even_odd, square | 2 | 60 | 1.4s | 4 | 3 | 4 |
| 4 | Tricky | prime, filled, vowel, lines, color_shape | 1 | 65 | 1.2s | 5 | 4 | 4 |
| 5 | Expert | lines, hollow, prime, color_shape, stroop, vowel | 2 | 70 | 1.0s | 5 | 4 | 5 |

**Repeating the last level.** `LEVEL_PROGRESSION_ORDER` normally cycles back to its first entry once exhausted. Ending it with `-1` (`REPEAT_LAST`) instead makes the run **hold on the last level forever** — e.g. `[1, 2, 3, 4, 5, -1]` plays 1..5 then stays on 5. With the sentinel present `reset_queue_from` does **not** wrap the tail around, so picking a mid-list starting level still ends on the final level rather than making an earlier one repeat. `-1` is only a sentinel and is never handed out as a level id. Since the rules are re-picked on every level load (and the previous pair is avoided), a repeated level still plays different rules each time.

If accuracy < 70%, level is replayed.

## Modalities

Same 9 modalities as other games: `digit`, `square`, `even_odd`, `vowel`, `prime`, `filled`, `hollow`, `stroop`, `color_shape`, `lines`.

## Key Pitfalls

- `_demo_phase` and `_question_phase` are mutually exclusive; `_process` only opens windows when `_demo_phase = true`.
- `_showing_demo_action = true` (set in `_take_item`) blocks new windows during the take; cleared right after the claw/discard.
- Window item may be freed by belt scroll while `_showing_demo_action` is true — `_discard_window` handles null/invalid checks.
- `question_correct_keys` is built in `_load_level` from `current_pair[i]["key"]`; must match what `_build_options` uses as the correct answer.
- For 1-belt levels, `current_pair[1]` exists (set from level def) but `_spawn_belt_item` is only called for `si in num_belts` (i.e., only si=0).
- `_take_item` is async (awaits the question phase) and is called from `_process`; `_showing_demo_action` prevents re-entry.
- **Mark vs take are position-based** (`_mark_item` / `_take_item`, driven by `_process`): on window-open, `_open_demo_window` picks a random `_take_top` so the item is **between h/2 and 3h/4** when taken, and `_mark_top = max(0, _take_top − robot_answer_time·scroll_speed)`. `_mark_item()` shows the ✓/✗ answer when the item reaches `_mark_top`; `_take_item()` pulls (yes) or leaves (no) it at `_take_top`. So **`robot_answer_time` = how long the answer is shown before the take** (bigger = answer appears sooner/higher, shown longer = easier), while the take always lands in the h/2..3h/4 band. (`mark_time` was merged into this — removed.)
- **Rule overlap**: two rules may only be shown together if **no single object can satisfy both** (`_CONFUSABLE_WITH`): `digit`/`even_odd`/`prime`, `vowel`/`lines`, `square`/`filled`/`color_shape`. `hollow` is deliberately unconstrained — hollow glyphs are disjoint from square, filled and color_shape.
- **Rule variety comes from the pool**: `_pick_pair_from_pool()` runs in `_load_level` AND in `_refresh_rules` (per round), shuffling the level's `rules` pool and taking the first two distinct, non-confusable keys. So the hidden rule varies round to round, and a given rule lands on the left belt sometimes and the right belt other times. (This replaced the old fixed `left`/`right` keys plus the 1-belt `current_pair.reverse()` hack.)
- **Every offered wrong answer is proved fair against the demos.** `_build_options` never trusts a static overlap table; it calls `_is_distinguishable(mod, belt)`, which replays `_demo_log[belt]` (every item the robot judged this round, logged in `_mark_item`) and keeps the option only if the rule **disagrees with the robot on at least one demo**. A rule that agrees with everything the player saw explains the demos as well as the real rule, so offering it would mark a sound answer wrong. This catches *accidental* overlaps a table cannot — e.g. rule "digit" where the demoed digits all happened to be prime, so "Is it prime?" must not be offered that round.
  - Each modality carries a `"test"` callable returning 1/0/−1 (satisfies / does not / rule doesn't apply to this object kind). `_rule_verdict` says an item matches when **either** object satisfies the rule; a rule applying to neither object yields **false, not "unknown"** (an item with no letters is not a vowel) — and since gating guarantees a pick-up was demoed, such a rule is genuinely ruled out.
  - The modality is built **once** and that same instance is validated and offered — `even_odd` randomizes even-vs-odd per build, so testing one instance and showing another would desync the label from the verdict.
  - Candidate order: other visible attribute → rest of the level pool → any remaining modality. Because candidates fall back to all 10 modalities, `num_options` is **not** capped by pool size. If too few candidates survive validation, **fewer options are shown** — deliberately, since a smaller honest question beats a full-size one containing an unanswerable option.
- **`_demo_log` must be cleared with the rules** (both round reset and `new_game`), or last round's evidence validates this round's options.
- **Demo gating**: the question screen only appears once every belt has demonstrated **≥3 picked-up (yes)** and **≥2 left (no)** items (`_yes_per_belt`/`_no_per_belt`), so the rule is always inferable. The window-opening candidate check (`_open_demo_window`) uses the **same** condition, otherwise the demo stalls at `min_examples` and the belt scrolls forever. Item selection is biased toward the still-needed answer so it converges.
- **No ambiguous options**: `_build_options` drops any distractor listed in `_CONFUSABLE_WITH[correct_key]` — e.g. a filled ■ is also a square, so "filled"/"hollow" are never offered when the rule is "square" (and "square" isn't offered when the rule is filled/hollow). Extend the map for other overlaps.
- **Window slides in from the top**: `_open_demo_window` opens on an **entering** item (`item_y < 0`), so the highlight slides in gradually with it (clip_contents). It never marks mid-entry — the mark waits for `_mark_top` (which is ≥ 0, i.e. fully inside). Item selection is biased toward the still-needed answer (gating), which keeps the yes/no spread balanced.
- **Claw pickup** (`_claw_pull`): on a correct pick-up the **actual item** (removed from `belt_items`, reparented into a flyer with `reparent(flyer, true)` so it looks exactly as on the belt) is gripped by a `claw.gd` arm and yanked off the **nearest** side. On pick-up the item is first **popped to 1.18× over 0.14s** (TRANS_BACK ease-out, so it slightly overshoots — reading as the claw closing and lifting it off the belt) and only **then** yanked off the side over 0.55s. The flyer's origin is set to the item's **center** so the pop grows it in place; with the origin at (0,0) the scale-up would drag the item toward the canvas corner. Durations live in `_GRAB_TIME` / `_PULL_TIME` / `_GRAB_SCALE` (single-belt → right; belt 0 → left, belt 1 → right). The highlight **rectangle is kept** around it (border reparented too, fill set transparent, ✓/✗ removed) so nothing covers the item, and it **moves the whole time** (no freeze/hold).
- **Layout**: `LeftSide`/`RightSide` fill their screen halves (rule label spans the half); each belt keeps its width but is `size_flags_horizontal = 4` (shrink-center) so its center sits at ~w/4 and ~3w/4. Rule labels reserve a 2-line height (like sortingrobots) so a 1- vs 2-line rule doesn't shift a belt down.

## Tutorial

`monkeyc/scripts/tutorial.gd` (12 steps), entry `monkeyc/scripts/main.gd::start_tutorial()`,
level 1. See `docs/tutorials.md` for the step schema.

What a first-timer gets wrong, and what the tutorial does about it:

- **They do not realize there is a hidden rule.** The robot picking things up reads as scenery
  until the question arrives out of nowhere. The first caption names the game as a guessing game
  before anything moves.
- **Every item is a PAIR and the rule applies to only one half.** Nothing on screen says so, and
  working out which half matters is most of the game. Step 3 points at one item and says it.
- **The ✓/✗ appears BEFORE the robot acts** (`robot_answer_time`, 5.8s on level 1). Players read
  the pull as the decision and miss the mark. The ✓ caption says the answer always comes first.

Specific to this game:

- **No belt freeze is needed.** `_process` returns early on `game.paused()`, so a talking step
  stops the belts, the window and the ✓/✗ timing together.
- **But that same early return means the belts are never filled while the coach talks.**
  `_init_belts()` normally runs on the first `_process` tick; `new_game()` therefore calls it
  directly in tutorial_mode, or the tutorial points at "one of these items" on an empty belt.
- **The window step waits for `window_ready`, not `window_opened`.** `_open_demo_window` picks an
  item still ENTERING (`item_y < 0`) so the highlight slides in with it — but the belt is
  `clip_contents`, so at that instant the panel is above the visible belt and there is nothing on
  screen to point at. "It picked one" framed empty space outside the belt. `window_ready` fires
  from `_process` the first frame the item is inside, and returns immediately afterwards in
  tutorial_mode so the ✓/✗ cannot land in that same frame (`_mark_top` is 0 on easy levels, where
  `robot_answer_time` exceeds the run-in).
- **`tutorial_window_rect()` is clipped to the belt**, so it can only ever return the part of the
  highlight the player can actually see; off the belt it returns nothing rather than a rect over
  empty space.
- **`tutorial_force_truth` picks the next verdict** (1 = will be taken, 0 = will be left),
  overriding the `need_truth` gating in `_open_demo_window`. That is how one ✓ and then one ✗ are
  taught back to back instead of whenever the shuffle obliges. Cleared for the free-watching step.
- **`_ask_all_rules` returns early in tutorial_mode after the first round.** Otherwise it starts
  another round, or calls `_level_done()` and drops a level-completed popup over the coach's
  closing caption.
- Events reported to the coach: `window_opened`, `item_marked`, `marked_yes`, `marked_no`,
  `item_resolved`, `question_shown`, `question_answered` — all `game.tutorial_notify`, no-ops
  outside tutorial mode.
- **`tutorial_an_item_rect()` picks the item nearest the MIDDLE of the belt**, and only one lying
  fully inside it. Taking the item furthest down instead put the spotlight at y=792 on a 788px
  overlay — below the screen entirely — because the lowest item is often half off the belt's end.
- Points for the coach, all in screen coordinates: `tutorial_belt_rect`, `tutorial_window_rect`,
  `tutorial_an_item_rect`, `tutorial_question_rect`.

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

