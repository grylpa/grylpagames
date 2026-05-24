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
│   └── level_defs.gd     # Autoloaded as BucketMadnessLevelDefs
└── scenes/
    ├── main.tscn
    └── level.tscn
```

Art assets shared with rlmadness (copied at game creation). Sounds from `res://art/sounds/`.

## Autoloads

- `BucketMadnessG` — `globals.gd`; owns `GenericGameUtil.new("Bucket Madness", "bucketmadness", 0, 10, 0, 0)`; manages level queue, settings (`starting_level_id`, `use_uppercase`)
- `BucketMadnessLevelDefs` — `level_defs.gd`; provides `LEVELS`, `LEVEL_PROGRESSION_ORDER`, `get_level(id)`, `level_names()`, `id_to_index(id)`

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

5 levels, cycling via `LEVEL_PROGRESSION_ORDER = [1,2,1,2,3,4,5,3,4,5]`:

| ID | Name   | Left       | Right       | Hide after | Rounds | Fall duration |
|----|--------|-----------|-------------|-----------|--------|--------------|
| 1  | Green  | digit     | square      | 6         | 10     | 2.5s         |
| 2  | Blue   | even_odd  | vowel       | 5         | 12     | 2.2s         |
| 3  | Red    | prime     | convex      | 4         | 12     | 2.0s         |
| 4  | Cyan   | stroop    | color_shape | 3         | 15     | 1.8s         |
| 5  | Orange | lines     | even_odd    | 2         | 15     | 1.5s         |

If accuracy < 70%, level is replayed.

## Modalities

Same 9 modalities as rlmadness/sorting robots: `digit`, `square`, `even_odd`, `vowel`, `prime`, `convex`, `stroop`, `color_shape`, `lines`. Item font size is 90 (larger than sorting robots' 65).

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
└── MainLayout (MarginContainer, fullscreen, margins 12/0/12/0)
    └── VBox (VBoxContainer)
        ├── TopSpacer (expands)
        └── ContentVBox (VBoxContainer, sep=10)
            ├── AvgTimeLabel (Label, unique, centered, font=24)
            ├── FallArea (Control, unique, clip_contents=true, min-h=320)
            ├── BucketsRow (HBoxContainer, sep=8)
            │   ├── LeftBucketSide (VBoxContainer, expand)
            │   │   ├── LeftBucketBox (PanelContainer, min-h=70, yellow border)
            │   │   └── LeftRuleLabel (Label, unique, min-h=52, font=18, autowrap)
            │   ├── CenterBucketSide (same structure)
            │   │   ├── CenterBucketBox
            │   │   └── DumpsterLabel (Label, unique, "♻ Dumpster")
            │   └── RightBucketSide (same structure)
            │       ├── RightBucketBox
            │       └── RightRuleLabel (Label, unique, min-h=52, font=18, autowrap)
            └── FeedbackLabel (Label, unique, font=60, α=0 initially)
        └── BottomSpacer (expands)
```

## Key Pitfalls

- `item_answered` flag prevents double-evaluation if fall tween and input fire close together.
- `fall_tween.kill()` is called at start of `_evaluate_answer()` to stop fall animation immediately.
- The dumpster (`correct_bucket = 1`) is bucket index 1 (center), not the right bucket.
- Category 2 (dumpster) uses `current_pair[0]["gen"].call(false)` — a "wrong" example from the left modality's generator.
