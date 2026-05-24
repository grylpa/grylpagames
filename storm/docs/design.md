# Storm — Game Design

## Concept

A time-pressure management game. A storm is battering your old house and the roof is leaking. You must protect your belongings by placing containers and duct tape under leaks, emptying filled containers at drains, and preventing water from overflowing onto the floor.

## Game Flow

1. An intro popup describes the round (room count, storm duration)
2. The storm starts: leaks appear periodically on random room tiles
3. The player walks to leaks, selects a tool from the action panel, and places it
4. Tools fill with water over time; when full, water starts overflowing the tile
5. The player carries full tools to a drain to empty them
6. Round ends when the storm passes (120-second timer)
7. Round fails when too many tiles have overflowed (score hits 0)
8. 3 rounds complete a level; completing a level advances to the next

## Controls

- Click/tap a leak (when close) → action panel opens; select a tool or pick up a filled one
- Click/tap a drain (when close) → select a tool to empty
- F / L: faster / slower game speed
- N: new game
- M: main menu

## Scoring

- **initial_score = 100** per game session (carries across rounds and levels)
- **−val** when a tile overflows (`_on_pipe_leak_overflow`; `val` = furniture value or 1)
- **−1** when a tool's container fills up (`action_full` flag in `pipe.gd`)
- **+2** when a tool is placed on a leak
- **+5** when a tool is emptied at a drain
- **+1/+5** for correct / **−1/−5** for incorrect answers (via `answered()`)
- **End-of-round bonus**: `min(5, 60 − elapsed_seconds)` score and time (can be negative for slow rounds)
- Score is clamped at 0 (never goes negative)

## Score Saving

`score_was_changed` is set when `add_score_and_time` is called with `is_actual_score=true` (the default). The countdown timer passes `is_actual_score=false` so mere time-passing does not count as "having played." A score is only saved if the player actually placed a tool or had an overflow.

## Levels

12 levels defined in `StormLevelConfig.LEVELS`, each with 3 rounds. Difficulty (room count, leak rate, etc.) increases with level. The game loops silently at the last level.

## Tools

Tools are defined as `CAction` objects with a `name`, `id`, `level` (current fill), and `overflow_level`. At game start only `bucket` is available; higher levels unlock more tool types (rag, cup, plate, fix). Each tool type has a different `overflow_level` controlling how quickly it fills.

## Pipes (Leaks)

- `pipe.gd` handles per-tile water logic
- `water_level` (0→1): how full the tile floor is; hits 1.0 → `sig_leak_overflow` → score penalty
- `action_level` (0→overflow_level): how full the placed tool is
- When `action_level >= overflow_level`: tool is full, `action_full = true`, −1 score penalty fired once; water then starts filling the tile
- `set_action()` resets `action_full` so placing a new tool or draining clears the state

## Drains

Drain tiles are special pipes (`is_drain = true`). When a filled tool is placed on a drain, `action_level` is reset to 0 each frame — the container empties. The player gets +5 for a successful drain.

## Rooms & Board

- Board divided into rectangular rooms connected by corridors
- Player is a walking character that must be close to a leak or drain to interact
- Furniture (flower, screen, rug) placed in rooms adds visual variety and raises the overflow penalty for that tile

## Save Files

Uses standard `GenericGameUtil` with prefix `storm`:
- `settings_v5_{key}_storm.gpa` — `[starting_level]`
- `scores_v5_{key}_storm.gpa` — score rows: `[unixtime, score, time_left_sec, times_run, didwin, wasaborted, level]`
- `ongoing_score_v5_{key}_storm.gpa`

## Scene / Script Structure

```
storm/
├── art/           (graphics only)
├── docs/
│   └── design.md
├── scenes/
│   ├── main.tscn
│   ├── level.tscn
│   ├── pipe.tscn
│   ├── empty_space.tscn
│   ├── agent.tscn
│   ├── player.tscn
│   ├── door.tscn
│   └── action_panel.tscn
└── scripts/
    ├── globals.gd         (StormG autoload)
    ├── main.gd            (orchestrator)
    ├── level.gd           (core gameplay, board, rooms, leaks)
    ├── level_config.gd    (StormLevelConfig — 12 levels)
    ├── pipe.gd            (per-tile water logic, overflow detection)
    ├── agent.gd
    ├── player.gd
    └── hud.gd
```
