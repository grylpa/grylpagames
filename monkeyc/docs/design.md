# Apprentice — Design Doc

## Overview

The player watches a robot sort items on one or two endless conveyor belts without seeing the rule. The item in question is marked by amber lights along the belt's rails; when the item reaches the h/2..3h/4 band the robot picks up (✓, item removed) or leaves it (✗); the ✓/✗ seal is stamped on the parcel `robot_answer_time` earlier. After `min_examples` examples per active belt rule, a multiple-choice question asks the player to identify the hidden rule.

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

Independent game: it has its own `monkeyc/art/` folder (just the chooser thumbnail) and uses only shared root assets and scripts (`res://art/`, `scripts/parcel_art.gd` and the rest of the depot look -- see Visual style). No files reference or depend on rlmadness. Sounds from `res://art/sounds/`.

## Autoloads

- `MonkeyCG` — `globals.gd`; owns `GenericGameUtil.new("Apprentice", "monkeyc", 0, 10, 0, 0)`; manages level queue, settings (`starting_level_id`, `use_uppercase`)
- `MonkeyCLevelConfig` — `level_config.gd`; provides `LEVELS`, `LEVEL_PROGRESSION_ORDER`, `get_level(id)`, `level_names()`, `id_to_index(id)`

## Gameplay Design

### Demo phase (endless conveyor)

Both belts (or just the left for 1-belt levels) scroll continuously. Items enter from the top. The rail lights come on beside one item and travel with it. The ✓/✗ answer shows at `_mark_top`, then the robot acts when the item reaches the take band (h/2..3h/4):
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
- `%LeftRuleLabel`, `%RightRuleLabel` — hidden outright (`visible = false`); no rules shown to the player. They used to be kept at alpha 0, still reserving two lines above the belt; their height now goes to the belt (`_size_belts(f, belt_w, 0.0, ...)`), which with parcels was down to three items.

### Items

Each belt item is a **pair** (two objects side by side), identical to sorting robots: `current_pair[0]` (left modality) and `current_pair[1]` (right modality), with display order randomised per item. `truth_l` = whether left-modality object matches left rule; `truth_r` = right-modality vs right rule. The robot acts on `truth_l` for the left belt and `truth_r` for the right belt — the player must figure out which modality the robot is using.

Each pair is a PARCEL (`ParcelArt`, as in Sorting Robots): one 3-D cardboard box with the two items on two equal cards. `item_h = belt_w * ParcelArt.ASPECT`; items scroll at `belt_spd` px/s with spacing `item_h * 1.03-1.20`. The window `Panel` (now invisible: the parcel's rail lights mark the item in question) tracks its target item every frame so it never freezes. The robot's verdict is a seal stamped on the parcel (`ParcelArt.stamp`); a new item in question clears the last seal.

## Levels

6 levels, played in the order `LEVEL_PROGRESSION_ORDER = [1,2,3,4,5,3,4,5,6,-1]`:

Each level defines a **`rules` pool**, not a fixed left/right pair. Every **round**, `_pick_pair_from_pool()` shuffles the pool and takes the first two **distinct, non-confusable** keys, so the hidden rule changes from round to round instead of being the same one all level. For 1 belt the first pick is the hidden rule and the second is a visible decoy attribute; for 2 belts both picks are hidden rules (one per belt). A bigger pool = harder and less predictable.

An **empty** `rules` list means "use every rule". Overlapping rules may safely share a pool — `_find_rule_pair` only ever returns a legal combination. The pair used last time is also avoided whenever the pool offers an alternative, so replaying a level (or wrapping around the progression order) doesn't serve up the same two rules again.

**Stroop sizing.** On a parcel each item is its own card (`ParcelArt._layout_cards`): equal heights, a card as wide as its content needs (at least square); if the two do not fit side by side on the lid they share the room in proportion and their text shrinks. (The old `_share_pair_widths` label layout is removed.)

| ID | Rules pool | Belts | Belt spd | Robot answer time | Min ex | Rounds | Options | pass_pct |
|----|-----------|-------|----------|-------------------|--------|--------|---------|----------|
| 1 | digit, square | 1 | 55 | 5.0s | 4 | 3 | 2 | 60 |
| 2 | even_odd, vowel, hollow | 1 | 60 | 2.6s | 4 | 3 | 3 | 60 |
| 3 | hollow, vowel, even_odd, square | 2 | 60 | 1.4s | 4 | 3 | 4 | 65 |
| 4 | prime, filled, vowel, lines, color_shape | 1 | 65 | 1.2s | 5 | 4 | 4 | 70 |
| 5 | lines, hollow, prime, color_shape, stroop, vowel | 2 | 70 | 1.0s | 5 | 4 | 5 | 70 |
| 6 | *(empty = every rule)* | 2 | 70 | 1.0s | 5 | 4 | 5 | 75 |

**Repeating the last level.** `LEVEL_PROGRESSION_ORDER` normally cycles back to its first entry once exhausted. Ending it with `-1` (`REPEAT_LAST`) instead makes the run **hold on the last level forever** — e.g. `[1, 2, 3, 4, 5, -1]` plays 1..5 then stays on 5. With the sentinel present `reset_queue_from` does **not** wrap the tail around, so picking a mid-list starting level still ends on the final level rather than making an earlier one repeat. `-1` is only a sentinel and is never handed out as a level id. Since the rules are re-picked on every level load (and the previous pair is avoided), a repeated level still plays different rules each time.

## Passing a level

Each level carries a **`pass_pct`** — the accuracy needed to move on. `MonkeyCG.pass_pct_for(id)`
reads it, falling back to `DEFAULT_PASS_PCT` (70) for a level that does not state one, so adding a
level cannot silently make it ungated.

`record_level_result()` returns whether the player passed and, when they did not, puts the level
back at the **FRONT** of `level_queue` — so the same level comes round again.

**It used to insert it at index 1**, behind the level that follows. A player could get every answer
wrong and still be handed the next level, with the failed one queued up after it; the accuracy
number on the summary card decided nothing. The threshold was also hardcoded at 70 for every level,
so the hardest level asked no more of the player than the first.

**The percentages have to land on a rung.** A level is a fixed number of rounds, so out of 3 the
only scores that exist are 0, 33, 66 and 100; out of 4, 0, 25, 50, 75 and 100. The values above sit
exactly on one — 60 and 65 both mean 2 of 3, 70 and 75 mean 3 of 4. Recheck them whenever `rounds`
changes.

## "complete!" only when it was

`show_level_done_popup` is called with the gate result as its `passed` argument and with
`current_level_id`, so the card reads "Level N complete!" with a check badge, or **"Level N not
passed"** with no badge on the warning color. Under it, the accuracy as a number alone, the mean
response time, and then what happens next:

- passed -> `Level passed — on to level N.` (from `MonkeyCG.peek_next_level_id()`)
- failed -> `You need at least NN% accuracy to pass to the next level.`

The threshold is stated in full by that line, so the accuracy row does not repeat it —
and on a level the player passed, the bar they cleared is not something they need told.
`MainGlobals.global_level_is_done()` takes the same result, so the fanfare does not play over a
level that was not passed.

## A replay starts clean

`new_game()` clears `total_rounds`, `total_corrects`, `game.corrects` and `game.mistakes` on
**every** level start, not just `if from_scratch`, and repaints the HUD next to the clearing.

The gate reads `pct_correct()`, which reads those counters — so a replay that inherited the misses
which failed the level could not pass it even played perfectly.

## A failed level earns nothing

`_score_at_level_start` is stamped at the top of `new_game()` (after the rollback, so consecutive
failures all measure from the same point) and a level that misses the gate goes back to it.
Otherwise the gate is a scoring exploit: the score is cumulative across a session, so every failed
attempt banked its points and the retry cost nothing.

**When** it happens is split on purpose. The score ROW is written the moment the level ends
(`main.gd` saves on `game.sig_level_is_done`), so the kept value is swapped in just for that emit
and swapped straight back — without it, failing repeatedly would farm the score list. The VISIBLE
score keeps showing what the player played with while the card is up, because watching it drop out
from under a summary you are still reading is alarming; the visible rollback lands in `new_game()`
when Continue is pressed.

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

## Visual style: the parcel depot (2026-11-02)

The same look as Sorting Robots -- see its `docs/design.md`, "Visual style", for the whole of it:
parcels (`scripts/parcel_art.gd`, real 3-D boxes rendered once, cards drawn 2-D in the exact palette),
the depot floor (`scripts/factory_floor.gd`: concrete, lane lines, litter, varied box piles -- here on
both sides of the single belt, at irregular heights; four identical pallets in four corners read as
staged), the roller belt under end housings (`belt_tread.gd`, `belt_hood.gd`), the rail lights for the
item in question and the seal for the verdict. MonkeyC's own differences: one lamp over the single
belt (`fb.lamps`), no rule signs, and the seal is the evidence the player collects -- it goes on the
box's FRONT EDGE so it never covers what was judged.

The belt starts EMPTY and parcels enter from the top only (they popped in at random places as their
pictures rendered); the tutorial's "Pairs" step therefore waits, silently, for the first parcel to
be fully on the belt (`tutorial_wait_for_item`, event `item_on_belt`) -- and, if the robot's window
has already opened meanwhile, for THE item it is judging, which "Pairs" then points at
(`_item_ready_for_pairs`, `tutorial_an_item_rect`); pointing at a different one failed the probe now
and then. The "It picked one" caption speaks of the lights along the belt (the yellow frame is gone).

### The robots

`scripts/robot_arm.gd` (`RobotBay`): bases bolted to the screen edge, the arm IS the claw (`hold()`
from `_claw_pull`), two-bone IK. Orange-painted. It visibly reaches for the item (`REACH_TIME`, 0.3 s)
before the lift and pull, and the question waits that much longer after the last pick-up.

### Rule labels use the prose font

Rule labels wrap ("Shape is / blue or red?"), and they used `get_system_sans_font()`, whose line box
is **2.09x** the font size because a Font's line height is the MAX over its fallbacks and the Noto
Symbols fallback is very tall. That nearly doubled the gap between the wrapped lines.

They now take `MainGlobals.get_text_font()` (1.41x); only the ✓/✗ keeps the symbol face. See the
Fonts section in the project `CLAUDE.md` — the same trap applies to every wrapped label in the app.

## Name

The game is **Apprentice** to the player: you learn the robot's rule by watching it work, never by
being told. The folder, the `MonkeyCG` / `MonkeyCLevelConfig` autoloads and the save shortname stay
`monkeyc` (from "monkey see", the development name) — renaming the shortname would orphan every
`*_monkeyc.gru` score file on every device.

## Belt spacing scales with the item

The pitch between consecutive items on a conveyor is `item_h * randf_range(PITCH_MIN, PITCH_MAX)`,
never a pixel range (a flat 80-130 px once made items overlap on a phone). With parcels it is
**1.03-1.20** (it was 1.111-1.806, which left too few items on the belt).

Two code paths spawn items and BOTH need the pitch: `_init_belts()` (above the belt only, now) and
`_scroll_belts()` adds new ones above as old ones leave the bottom. The second belt's head start
(`STAGGER_*`) is a fraction of `item_h` for the same reason.

## The belts hug the inside, the verdict lands on the item

Each belt box is aligned to the INNER edge of its half — `LeftBox` is `size_flags_horizontal = 8`
(shrink-end), `RightBox` is `0` (begin) — so the two conveyors sit together in the middle and the
robots have the outside to stand in. They were both shrink-CENTER, which put the free space between
them and pushed the robots almost entirely off a phone screen.

That leaves no center gap, which this game was already prepared for: its verdict has always been drawn on the judged item
by `_mark_item()`, never in the center.

## Belt height comes from the room available

`layout.offset_top` is `header_height + 12` and `_size_belts()` hands the belts whatever is left after
the status line and the rule labels — the same arrangement sortingrobots uses. This game used to
reserve a FIXED 148/192px top pad and hardcode the belt at `Vector2(220, 500)`, which is why its
conveyors were visibly shorter than sortingrobots' on the same screen: neither number knew how much
room there actually was. Measured after the fix, the two games agree within 6px at both canvas sizes
(mobile 791 vs 797, desktop 466 vs 472).

One knock-on: the tutorial's "this is the belt" step spotlights only the belt's TOP HALF now. A
full-height belt leaves the caption nowhere to stand, and it ended up covering the very thing it
points at.

## One belt centers, two hug the inside

`_align_belts()` runs whenever the belt count is applied. With **two** belts each hugs the inner edge
of its half (`SHRINK_END` / `SHRINK_BEGIN`) so the free space is on the OUTSIDE, where the robots
stand — authored as shrink-center, the slack sat between them and pushed the robots almost entirely
off a phone screen. With **one** belt it centers instead: there is no inner edge to hug when there is
nothing to be inside of, and a lone belt jammed against the middle of the screen just looks broken.

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

**This is a watched game, so most of what happens is not the player's.** The belt speed
(`belt_spd`), how many examples the robot shows before asking (`min_examples`) and how long it
takes over each one (`robot_answer_time`) are all set by the level. The player decides exactly
three things:

1. which rule they name,
2. whether that was right,
3. how long they take **once every option is on screen** — `_question_start_time` is set at the
   moment the options appear, so the watching phase is not in it.

Those three go into one trial per question (`game.record_trial`), carrying the rule KEY and a
short display name. `GameInstrument._rule_breakdown()` draws a row per kind of rule, hardest
first: the overall percentage is the least interesting of the three, and a player who reads
"is it prime?" off four examples but never spots the Stroop rule has a specific difficulty that
one number for the session hides.

**No "Consistency" row.** A level is 3–4 rounds, so a session yields 3–8 answers, and the spread
of three numbers is noise. `GameInstrument.summary_rows_for()` drops `rt_cv` when the typical
`rt_n` is below `SessionStats.MIN_TRIALS_FOR_TREND`. Accuracy over those same answers is kept —
three out of three is a real three — so the gate is per METRIC, not per session.

**Nothing measures "how many examples you needed".** It is fixed by `min_examples`; the player
cannot ask to see more or answer early, so it says nothing about them.

## The chooser tile

`art/game_screen_200.png` is drawn in Godot by `devtools/probe_sort_tiles.gd` (it needs a display):
the game as detective work -- a magnifying glass held over a big parcel (filling the tile) and its two cards, on a warm ground,
no verdict seal. Two earlier tries (crops and scenes of the belt, ✓/✗ seals) did not convey the game.
The published copies: the games-doc build (`--site`) and the site's front-page `thumbnails/`.

## The colored-shape item's key is "shape"

`_gen_colored_shape` returns `{"shape": ..., "color": ...}`, and everything that reads it
(`_make_colored_shape`, MonkeyC's rule test) reads `"shape"`. A rename of a local `shape` -> `shp`
(it shadows a base-class member) also caught the dictionary KEY in all three sorting games, so the
"Shape is blue or red?" rule crashed building its first item ("Invalid access to property or key
'shape'"); fixed 2026-11-02. Rename the variable, never the key.

## Sounds

A FACTORY ambient, as MUSIC (`monkeyc_ambient.ogg`, `devtools/make_ambient_sounds.py` `factory_music`: a mechanical groove -- clanks on the beat, air on the off-beat, a plucked bass, a metallic marimba ostinato over moving chords, a steel-pan tune; it was a motor's hum with roller ticks, one held tone) plays while the board is up (`main.gd` `show_level`, -6 dB) and stops at the menu. Its right/wrong sounds were inaudible until the shared registry stopped using positional players (see `scripts/generic_game_util.gd` `add_sound`). The ROBOT is heard too (`devtools/make_action_sounds.py`, "robot"): `grab` (a servo whirring up, the claw clamping, an air whoosh) whenever an arm takes an item (`_claw_pull`), and `pass` (a little falling two-note beep) when the robot lets a demo item go by (`_take_item`) -- the game had no robot sounds at all. It is mastered by its audible band (`music.master`); the old loop's motor hum was below what a small speaker plays, so it seemed to start late, with the first roller tick.

Made for this game by `devtools/make_answer_sounds.py` (synthesized, seeded; one timbre per family of
games): a soft latch and machine chime for an item sorted right, a low note for wrong. They replaced an arcade coin and a swoosh shared by nearly every game in the app.
