# DIDI — Design Document

## Overview

DIDI is a dual-memory game: the player must remember both a shape and its peripheral location, then select the correct shape at the correct position in a single answer stage.

Based on DDOOO but with a simplified single-stage answer mechanic.

## Folder Structure

```
didi/
├── art/                  (copied from ddooo/art)
│   ├── grass.png, grass_dark.png, pipe.png, game_screen_200.png
│   ├── empty_corner.png
│   └── shape-circle*.png  (7 shape textures)
├── docs/
│   └── design.md         (this file)
├── scripts/
│   ├── globals.gd        (DidiG autoload — GenericGameUtil("DIDI","didi",0,2,0,0))
│   ├── level_config.gd   (DidiLevelConfig class — per-level params)
│   ├── half_color.gdshader
│   ├── agent.gd          (Area2D: shape sprite with shader, auto-hide, click signal)
│   ├── level.gd          (CanvasLayer: game orchestrator)
│   └── main.gd           (Node: scene lifecycle, HUD, menus)
└── scenes/
    ├── agent.tscn
    ├── level.tscn        (CanvasLayer + UILayer CanvasLayer for progress bar)
    └── main.tscn
```

## Game Flow

1. **Model phase**: A shape appears at the center for `center_ms` milliseconds.
2. **Periph phase**: 150ms after the model appears, a random-shaped dot flashes near one of 8 positions (up, down, left, right, TL, TR, BL, BR) for `periph_ms` milliseconds. The player must notice WHERE it appeared (not what it looks like).
3. **Blank**: 300ms after both are gone, the answer stage begins.
4. **Answer stage**: At each of the 8 directions, a cluster of `num_options` (2, 3, or 4) shapes appears.
   - In `num_same` direction clusters (always including the correct direction), one shape in the cluster is the correct model shape; the others in that cluster are decoys.
   - All other direction clusters are entirely decoys.
   - A progress bar at the top counts down `time_to_consider_fail` ms.
   - **Both memories are independently required**: direction alone doesn't identify the correct shape within a cluster; shape alone doesn't identify the correct cluster.
5. **Evaluation**:
   - **Full score** (+score, +level progress): correct shape in the correct direction cluster.
   - **Half score** (+1): correct shape but wrong direction cluster.
   - **Wrong** (-1): decoy picked.
   - **Timeout** (-1): no answer within `time_to_consider_fail` ms.
6. After `rounds` fully-correct answers, advance to next level.

## Level Config (`DidiLevelConfig.LEVELS`)

| id | center_ms | periph_ms | num_same | two_colors | same_color_alts | rounds | time_to_consider_fail |
|----|-----------|-----------|----------|------------|-----------------|--------|-----------------------|
| 1  | 700       | 300       | 1        | false      | false           | 5      | 6000                  |
| 2  | 600       | 250       | 2        | false      | false           | 6      | 5500                  |
| 3  | 500       | 200       | 2        | false      | true            | 6      | 5000                  |
| 4  | 400       | 150       | 3        | false      | true            | 8      | 4500                  |
| 5  | 350       | 120       | 4        | true       | true            | 8      | 4000                  |
| 6  | 300       | 100       | 5        | true       | true            | 8      | 3500                  |
| 7  | 250       | 80        | 6        | true       | true            | 10     | 3000                  |
| 8  | 200       | 60        | 7        | true       | true            | 10     | 2500                  |

- `num_options`: how many shape choices appear per direction cluster (2/3/4). Cluster layouts:
  - **2**: pair perpendicular to inward axis (cardinals spread wider to align with corner option positions)
  - **3**: triangle — one outer + two inner flanking it; agents scaled to 0.22
  - **4**: diamond (outer/inner/left/right); agents scaled to 0.20
- `num_same`: how many of the 8 direction clusters contain the correct shape (rest are all-decoy clusters)
- `same_color_alts`: when true, all agents share the model color — shape texture alone distinguishes correct from decoy

## Mac / HiDPI Compatibility

- `get_viewport().gui_release_focus()` called in `show_level()` so arrow keys reach `_input()`.
- Answer agents are Area2D (physics-based input), not Control nodes, so they work correctly even with Camera2D `follow_viewport_enabled = true`.
- Progress bar (ProgressBar Control node) lives in `$UILayer` (a CanvasLayer child without `follow_viewport_enabled`), avoiding the HiDPI coordinate mismatch.

## Scoring

- Uses `GenericGameUtil` with `game_over_on_zero_score = true`, `initial_score = 100`.
- Score row: `[didwin, wasaborted, level, avg_time_ms, pct_correct]`
- `progress_level_pos = 6`, `progress_time_pos = 7`, `progress_pct_pos = 8`
