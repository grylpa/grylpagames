# Sorting Robots — Design Doc

## Overview

Two vertical conveyor belts side-by-side, each governed by a hidden rule. Items fill both belts simultaneously. One item per belt is highlighted. The player swipes right (pick up) or left (leave) to judge whether the highlighted item matches that belt's rule. Rules are shown as text labels at first, then hidden after `rounds_before_hide` rounds.

## File Structure

```
sortingrobots/
├── scripts/
│   ├── globals.gd        # Autoloaded as SortingRobotsG
│   ├── main.gd           # Orchestrator
│   ├── level.gd          # Core gameplay
│   └── level_config.gd     # Autoloaded as SortingRobotsLevelConfig
└── scenes/
    ├── main.tscn
    └── level.tscn
```

Independent game: it has its own `sortingrobots/art/` folder (just the chooser thumbnail) and uses only shared root assets from `res://art/` (e.g. `grass.png` background); the shape/digit/letter objects are drawn as **font glyphs** (Labels), not images. No files reference or depend on rlmadness. Sounds come from `res://art/sounds/`.

## Autoloads

- `SortingRobotsG` — `globals.gd`; owns `GenericGameUtil.new("Sorting Robots", "sortingrobots", 0, 10, 0, 0)`; manages level queue, settings (`starting_level_id`, `use_uppercase`)
- `SortingRobotsLevelConfig` — `level_config.gd`; provides `LEVELS`, `LEVEL_PROGRESSION_ORDER`, `get_level(id)`, `level_names()`, `id_to_index(id)`

## Gameplay Design

### Endless conveyor mechanic

Both belts **always scroll** simultaneously, items entering from the top and exiting through the bottom. A yellow **window** (highlight rectangle) randomly slides in from the right edge of one belt and tracks its assigned item all the way down. Input is accepted the **entire time the item is visible** — the window stays open until the player answers or the item exits the bottom (timeout). (Difficulty comes from belt speed, not a fixed answer timer; `window_duration`/`window_dur` is no longer used to gate input.)

The window tracks the specific item it was assigned to as that item scrolls down. If the item exits the bottom before the player answers, it counts as a timeout (wrong).

- **`_process(delta)`**: scrolls both belts, keeps the open window tracking its item and times out only when it exits the bottom, opens the next window when `next_window_timer` expires.
- **`_open_window()`**: picks a random belt; finds the item closest to 30% from the top (excluding items past 60%); slides a Panel in from the right with a 0.25s tween; records that item's truth value for the active belt.
- **`_close_window()`**: kills the slide-in tween if running; slides panel back out to the right in 0.2s then frees it.
- **`next_window_timer`**: randomised 1.2–2.5s between windows after each judgment.

### Two-object items

Each item shows **two objects side by side**. `truth_l` and `truth_r` are assigned independently at spawn time (whether the left/right modality's item matches its rule). Display order is **randomised per item**: `swapped=true` renders the right-modality object on the left and vice versa.

`truth_l`/`truth_r` always refer to the modality, not the display position. When the window is on the **left belt**, the ground truth is `entry["truth_l"]`; on the **right belt**, it's `entry["truth_r"]`.

### Input

- Swipe right (delta.x > 0) → pick up (true)
- Swipe left (delta.x < 0) → leave (false)
- Keyboard: `right`/`ui_right` → pick up, `left`/`ui_left` → leave
- Swipe threshold: 60px

### Scoring

- Correct: +10 + speed_bonus (max 20, 1 point per 100ms under 2s), adds to `times_to_answer`
- Wrong / timeout: −min(3, score)
- Level end popup shows accuracy % and mean response time

### Label hiding

After `rounds_before_hide` windows judged, both rule labels fade to alpha=0.

## Levels

5 levels, cycling via `LEVEL_PROGRESSION_ORDER = [1,2,3,4,5,3,4,5]`:

Each level defines a **`rules` pool**, not a fixed left/right pair. On every level load, `_pick_pair_from_pool()` shuffles the pool and takes the first two **distinct, non-confusable** keys, so which rules appear — and which belt each one lands on — varies from play to play. `_are_confusable()` (via `_CONFUSABLE_WITH`) keeps overlapping rules apart (see below).

An **empty** `rules` list means "use every rule". Overlapping rules may safely share a pool — `_find_rule_pair` only ever returns a legal combination. The pair used last time is also avoided whenever the pool offers an alternative, so replaying a level (or wrapping around the progression order) doesn't serve up the same two rules again.

**Stroop sizing.** The two objects of an item do **not** split the width 50/50 — a stroop word ("YELLOW") is many times wider than a glyph and used to spill over its half and collide with the other object. `_share_pair_widths` gives each object a share proportional to its natural text width (clamped to 18–82% so neither is starved), then `_fit_label_width` shrinks each font until its text fits the share it got. On a 220px belt the word keeps its full size; only narrower items shrink it.

**Rule overlap (`_CONFUSABLE_WITH`).** Two rules may only be shown together if **no single object can satisfy both**, otherwise an item legitimately belongs to both sides and the "correct" answer is arbitrary. Overlapping sets: `digit`/`even_odd`/`prime` ("4" is a digit and even; "3" is a digit, prime and odd), `vowel`/`lines` (A, E, I are vowels and straight-line letters), and `square`/`filled`/`color_shape` (a ■ is a square and filled; colored shapes are all filled glyphs). `hollow` is deliberately unconstrained — hollow glyphs are disjoint from square, filled and color_shape. `_pick_pair_from_pool` searches **all** pairs in the shuffled pool for a legal combination, so a pool may safely list overlapping rules as long as some legal pair exists.

| ID | Name   | Rules pool | Hide after | Rounds | Window dur | Belt speed |
|----|--------|-----------|-----------|--------|------------|------------|
| 1 | Green | digit, square | 6 | 10 | 3.0s | 65 px/s |
| 2 | Blue | even_odd, vowel, hollow | 5 | 12 | 2.6s | 70 px/s |
| 3 | Red | hollow, even_odd, vowel, square | 4 | 12 | 2.3s | 75 px/s |
| 4 | Cyan | prime, filled, vowel, lines, color_shape | 3 | 15 | 2.0s | 80 px/s |
| 5 | Orange | lines, hollow, prime, color_shape, stroop, vowel | 2 | 15 | 1.7s | 85 px/s |

**Repeating the last level.** `LEVEL_PROGRESSION_ORDER` normally cycles back to its first entry once exhausted. Ending it with `-1` (`REPEAT_LAST`) instead makes the run **hold on the last level forever** — e.g. `[1, 2, 3, 4, 5, -1]` plays 1..5 then stays on 5. With the sentinel present `reset_queue_from` does **not** wrap the tail around, so picking a mid-list starting level still ends on the final level rather than making an earlier one repeat. `-1` is only a sentinel and is never handed out as a level id. Since the rules are re-picked on every level load (and the previous pair is avoided), a repeated level still plays different rules each time.

If accuracy < 70%, level is replayed (inserted at position 1 in queue).

## Modalities

All modalities from rlmadness, plus each returns `"key"` in its dictionary (needed by MonkeyC):
`digit`, `square`, `even_odd`, `vowel`, `prime`, `filled`, `hollow`, `stroop`, `color_shape`, `lines`

## Scene Layout (`level.tscn`)

```
Level (CanvasLayer, script=level.gd)
├── Background (TextureRect, fullscreen)
└── MainLayout (MarginContainer, fullscreen, margins 12/0/12/0)
    └── VBox (VBoxContainer)
        ├── TopSpacer (expands)
        └── ContentVBox (VBoxContainer, sep=10)
            ├── AvgTimeLabel (Label, unique, centered, font=24)
            ├── BoxesRow (HBoxContainer, sep=16)
            │   ├── LeftSide (VBoxContainer, expand)
            │   │   ├── LeftRuleLabel (Label, unique, min-h=2 lines, font=22/32, bottom-aligned)
            │   │   └── LeftBox (PanelContainer, expands vertically, yellow border)
            │   │       └── LeftItemsContainer (Control, unique, clip_contents=true)
            │   └── RightSide (same structure as LeftSide)
            │       ├── RightRuleLabel
            │       └── RightBox
            │           └── RightItemsContainer
            └── FeedbackLabel (Label, unique, font=60, α=0 initially)
        └── BottomSpacer (expands)
```

## Key Pitfalls

- **Vertical layout is derived from available space, not hardcoded.** `_ready` sets `offset_top = header_height + 12` and `offset_bottom = -(footer + max(20, bar_h - footer + 10))` (bar_h ≈ 70 mobile / 44 desktop), the same on every platform; `_size_belts()` then gives the belts whatever height is left after the status line and rule labels, flooring at 200px. This replaced a fixed 150px desktop top pad plus a hardcoded 420/500px belt minimum, which together were taller than the space available and pushed the belt bottoms under the app bottom button bar. Do not reintroduce a fixed belt height — on a short window the content simply cannot fit.
- **The ✓/✗ sits between the belts.** `_ready` reparents `%FeedbackLabel` out of the `ContentVBox` flow onto the CanvasLayer (kept in `_feedback`) so it can be positioned freely; `_position_feedback()` then centers it horizontally in the gap between the two belts and vertically at their shared center, recomputed on every show so it survives resizes. Do not read it back via `%FeedbackLabel` after the reparent — use `_feedback`.

- Items are direct children of `LeftItemsContainer`/`RightItemsContainer` (no wrapper). The window Panel is also a direct child with `z_index = 2`.
- `clip_contents = true` on the containers clips items above and the window when it starts off-screen at `position.x = bw`.
- Window slides in from the right: starts at `position.x = bw`, tweens to `position.x = 0`. `clip_contents` hides it while off-screen.
- Window `position.y` is updated each `_process` frame to track the target item as it scrolls down.
- `_showing_feedback: bool` prevents new windows opening or double-scoring during the 0.4s feedback flash.
- `_window_slide_tween` is killed in `_close_window()` before starting the slide-out tween to avoid conflicts.
- Belts are narrow (140px min width, fixed — `size_flags_horizontal = 0`) and tall (420px min height). BoxesRow uses `alignment = 1` (CENTER) to keep them centered on wider screens.
- Rule labels use `vertical_alignment = 2` (bottom) plus a `custom_minimum_size.y` set in `level.gd` to a 2-line height computed from the active font (`f.get_height(rule_fs) * 2 + 12`, where `rule_fs` is 22 desktop / 32 mobile). This makes a 1-line rule and a 2-line rule occupy the same height so the two belts stay vertically aligned. Don't hardcode a pixel height — the system font's line height varies, and an under-sized value lets a 2-line rule overflow and push its belt down. The labels also set `line_spacing = -8` so two-line rules aren't spaced too far apart.
- `set_process(false)` in `_level_done()` stops belt scrolling after the level ends.
- **Layout**: `LeftSide`/`RightSide` now fill their screen halves (`size_flags_horizontal = 3`) so each rule label spans its half and rarely wraps past 2 lines; each belt keeps its fixed width but is `size_flags_horizontal = 4` (shrink-center) so its center sits at ~w/4 and ~3w/4. (Before, the sides shrank to belt width, so long rules wrapped to 3 lines and overflowed the 2-line reserve, pushing a belt down.)
- **Yes/no balance**: `_open_window` biases the entering item it highlights toward the under-represented truth (`_shown_yes`/`_shown_no`) so the judged items aren't almost all "no".
- **Claw pickup** (`_claw_pull`): on a correct pick-up (`user_picks_up and == window_target_truth`), the item is removed from `belt_items` and **reparented into a flyer** (`reparent(flyer, true)`, so it looks exactly as on the belt); a `claw.gd` arm grips it and yanks it off the **nearest** side. On pick-up the item is first **popped to 1.18× over 0.14s** (TRANS_BACK ease-out, so it slightly overshoots — reading as the claw closing and lifting it off the belt) and only **then** yanked off the side over 0.55s. The flyer's origin is set to the item's **centre** so the pop grows it in place; with the origin at (0,0) the scale-up would drag the item toward the canvas corner. Durations live in `_GRAB_TIME` / `_PULL_TIME` / `_GRAB_SCALE` (belt 0 → left, belt 1 → right). The highlight **rectangle is kept** around it (border reparented, fill transparent) and it **moves the whole time** (no freeze).
- Each belt has a `belt_edge.gd` overlay Control (added as a child of `LeftBox`/`RightBox` in `_add_belt_edges()`). The PanelContainer fits it to the belt rect, but it draws **outside** that rect — short (`STRIP_H = 5`) smooth gradient strips (`draw_polygon` with per-vertex colors) just above the top edge and just below the bottom edge, belt-colored where they meet the belt and fading to transparent into the background, so the belt reads as rolling over a roller at each end. `_add_belt_edges()` zeroes the panel's `content_margin_*` so the overlay spans the **full belt width** and meets the belt with **no overlap** (overlap would alpha-stack and look darker than the belt). The belt keeps its solid panel bg; the strips must not be clipped (no ancestor sets `clip_contents`). `mouse_filter = IGNORE` so it never eats input.
