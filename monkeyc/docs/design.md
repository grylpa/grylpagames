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

For each active belt in order, a full-screen overlay shows a multiple-choice question with `num_options` options. The correct answer is the modality label for that belt's rule; wrong answers are randomly drawn from other modalities.

- Correct: +10, green highlight on correct button
- Wrong: −min(3, score), red on chosen, green on correct

After all questions are answered, `rounds_done` increments. If `rounds_done >= num_rounds_per_level`, level ends. Otherwise, demo resets and repeats.

### Scene Layout

Uses the same scene structure as Sorting Robots:
- `%LeftItemsContainer` / `%RightItemsContainer` — clip_contents=true, direct item children
- Right side hidden for 1-belt levels
- `%AvgTimeLabel` — "Watch the robot..." during demo, avg time after first question round
- `%FeedbackLabel` — not used in demo; question feedback handled inline by button highlights
- `%LeftRuleLabel`, `%RightRuleLabel` — always hidden (alpha=0); no rules shown to player

### Items

Each belt item is a **pair** (two objects side by side), identical to sorting robots: `current_pair[0]` (left modality) and `current_pair[1]` (right modality), with display order randomised per item. `truth_l` = whether left-modality object matches left rule; `truth_r` = right-modality vs right rule. The robot acts on `truth_l` for the left belt and `truth_r` for the right belt — the player must figure out which modality the robot is using.

`PAIR_FONT_SIZE = 32`, `ITEM_H = 72.0` — identical to sorting robots. Items scroll at `belt_spd` px/s with random spacing (80–130 px). The window `Panel` tracks its target item every frame (including during robot action animation) so it never freezes.

## Levels

5 levels, cycling via `LEVEL_PROGRESSION_ORDER = [1,2,1,2,3,4,5,3,4,5]`:

Each level defines a **`rules` pool**, not a fixed left/right pair. Every **round**, `_pick_pair_from_pool()` shuffles the pool and takes the first two **distinct, non-confusable** keys, so the hidden rule changes from round to round instead of being the same one all level. For 1 belt the first pick is the hidden rule and the second is a visible decoy attribute; for 2 belts both picks are hidden rules (one per belt). A bigger pool = harder and less predictable.

| ID | Name   | Rules pool | Belts | Belt spd | Robot answer time | Min ex | Rounds | Options |
|----|--------|-----------|-------|----------|-------------------|--------|--------|---------|
| 1  | Simple | digit, square | 1 | 55 | 5.8s | 4 | 3 | 2 |
| 2  | Even   | even_odd, vowel, digit | 1 | 60 | 1.6s | 4 | 3 | 3 |
| 3  | Two    | digit, vowel, even_odd, square | 2 | 60 | 1.4s | 4 | 3 | 4 |
| 4  | Tricky | prime, filled, vowel, lines, digit | 1 | 65 | 1.2s | 5 | 4 | 4 |
| 5  | Expert | lines, hollow, prime, color_shape, stroop, vowel | 2 | 70 | 1.0s | 5 | 4 | 5 |

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
- **Rule variety comes from the pool**: `_pick_pair_from_pool()` runs in `_load_level` AND in `_refresh_rules` (per round), shuffling the level's `rules` pool and taking the first two distinct, non-confusable keys. So the hidden rule varies round to round, and a given rule lands on the left belt sometimes and the right belt other times. (This replaced the old fixed `left`/`right` keys plus the 1-belt `current_pair.reverse()` hack.)
- **Options are drawn from the level's pool**, not from all 10 modalities: `_build_options` force-includes the other **visible** attribute first (the tempting wrong guess — the player must reason rather than pick the only shown alternative), then fills the rest from the pool. Keep `num_options` ≤ pool size, or fewer options are offered than requested.
- **Demo gating**: the question screen only appears once every belt has demonstrated **≥3 picked-up (yes)** and **≥2 left (no)** items (`_yes_per_belt`/`_no_per_belt`), so the rule is always inferable. The window-opening candidate check (`_open_demo_window`) uses the **same** condition, otherwise the demo stalls at `min_examples` and the belt scrolls forever. Item selection is biased toward the still-needed answer so it converges.
- **No ambiguous options**: `_build_options` drops any distractor listed in `_CONFUSABLE_WITH[correct_key]` — e.g. a filled ■ is also a square, so "filled"/"hollow" are never offered when the rule is "square" (and "square" isn't offered when the rule is filled/hollow). Extend the map for other overlaps.
- **Window slides in from the top**: `_open_demo_window` opens on an **entering** item (`item_y < 0`), so the highlight slides in gradually with it (clip_contents). It never marks mid-entry — the mark waits for `_mark_top` (which is ≥ 0, i.e. fully inside). Item selection is biased toward the still-needed answer (gating), which keeps the yes/no spread balanced.
- **Claw pickup** (`_claw_pull`): on a correct pick-up the **actual item** (removed from `belt_items`, reparented into a flyer with `reparent(flyer, true)` so it looks exactly as on the belt) is gripped by a `claw.gd` arm and yanked off the **nearest** side (single-belt → right; belt 0 → left, belt 1 → right). The highlight **rectangle is kept** around it (border reparented too, fill set transparent, ✓/✗ removed) so nothing covers the item, and it **moves the whole time** (no freeze/hold).
- **Layout**: `LeftSide`/`RightSide` fill their screen halves (rule label spans the half); each belt keeps its width but is `size_flags_horizontal = 4` (shrink-center) so its center sits at ~w/4 and ~3w/4. Rule labels reserve a 2-line height (like sortingrobots) so a 1- vs 2-line rule doesn't shift a belt down.
