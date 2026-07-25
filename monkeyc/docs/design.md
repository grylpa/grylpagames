# Monkey C — Design Doc

## Overview

The player watches a robot sort items on one or two endless conveyor belts without seeing the rule. A yellow window highlights an item; after `robot_answer_time` seconds the robot picks up (✓, item removed) or rejects (✗, window disappears). After `min_examples` examples per active belt rule, a multiple-choice question asks the player to identify the hidden rule.

## File Structure

```
monkeyc/
├── scripts/
│   ├── globals.gd        # Autoloaded as MonkeyCG
│   ├── main.gd           # Orchestrator
│   ├── level.gd          # Core gameplay
│   └── level_defs.gd     # Autoloaded as MonkeyCLevelDefs
└── scenes/
    ├── main.tscn
    └── level.tscn
```

Independent game: it has its own `monkeyc/art/` folder (just the chooser thumbnail) and uses only shared root assets from `res://art/` (e.g. `grass.png` background); the shape/digit/letter objects are drawn as **font glyphs** (Labels), not images. No files reference or depend on rlmadness. Sounds from `res://art/sounds/`.

## Autoloads

- `MonkeyCG` — `globals.gd`; owns `GenericGameUtil.new("Monkey C", "monkeyc", 0, 10, 0, 0)`; manages level queue, settings (`starting_level_id`, `use_uppercase`)
- `MonkeyCLevelDefs` — `level_defs.gd`; provides `LEVELS`, `LEVEL_PROGRESSION_ORDER`, `get_level(id)`, `level_names()`, `id_to_index(id)`

## Gameplay Design

### Demo phase (endless conveyor)

Both belts (or just the left for 1-belt levels) scroll continuously. Items enter from the top. A yellow window frame appears on a single item on one belt and scrolls with it. After `robot_answer_time` seconds:
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

| ID | Name   | Left       | Right      | Belts | Belt spd | Robot time | Min ex | Rounds | Options |
|----|--------|-----------|------------|-------|----------|------------|--------|--------|---------|
| 1  | Simple | digit     | square     | 1     | 55       | 1.8s       | 4      | 3      | 3       |
| 2  | Even   | even_odd  | vowel      | 1     | 60       | 1.5s       | 4      | 3      | 3       |
| 3  | Two    | digit     | vowel      | 2     | 60       | 1.5s       | 4      | 3      | 4       |
| 4  | Tricky | prime     | filled     | 1     | 65       | 1.3s       | 5      | 4      | 4       |
| 5  | Expert | lines     | hollow   | 2     | 70       | 1.2s       | 5      | 4      | 5       |

If accuracy < 70%, level is replayed.

## Modalities

Same 9 modalities as other games: `digit`, `square`, `even_odd`, `vowel`, `prime`, `filled`, `hollow`, `stroop`, `color_shape`, `lines`.

## Key Pitfalls

- `_demo_phase` and `_question_phase` are mutually exclusive; `_process` only opens windows when `_demo_phase = true`.
- `_showing_demo_action = true` blocks new windows during the 0.45s robot animation. It is cleared in `_robot_answer` after the await.
- Window item may be freed by belt scroll while `_showing_demo_action` is true — `_discard_window` handles null/invalid checks.
- `question_correct_keys` is built in `_load_level` from `current_pair[i]["key"]`; must match what `_build_options` uses as the correct answer.
- For 1-belt levels, `current_pair[1]` exists (set from level def) but `_spawn_belt_item` is only called for `si in num_belts` (i.e., only si=0).
- `_robot_answer` is an async function called from `_process`; `_showing_demo_action` prevents re-entry.
