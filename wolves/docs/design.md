# Wolves — Game Design

## Concept

A herding game. The player is a sheepdog patrolling a fenced farm. Sheep start inside a central compound; the compound fence degrades over time and sheep may wander out. Walking near a scared sheep triggers A*-pathfinding back to the compound. Wolves (hostile agents) can also appear. The player must keep the sheep alive until the level ends.

## Game Flow

1. Level starts: board is built with one compound room filled with sheep
2. The compound fence starts intact; pieces fall off on a timer
3. The outer farm fence also degrades separately on a slower timer
4. Sheep wander freely inside their room; if the player comes within `dist_to_scare` tiles they path back to the compound center
5. A sheep is "lost" if it wanders off the board or off the playable field (not a room and not a field tile)
6. Each lost sheep reduces `game.lives_left` by 1
7. If all sheep are lost → level fails
8. Level win condition: player reaches arrival point after all rooms visited and all coins collected

## Controls

- Arrow keys / touch: move the player (sheepdog)
- F / L: faster / slower
- N: new game
- M: main menu
- H: help

## Board Layout

- `board_margin = 3` tiles of non-playable border on each side
- One compound room centered on the board (room 0)
- Field tiles fill the inside of the farm border (all non-room tiles within the margin)
- Farm border = outermost ring of field tiles; carries fence flags on its edges
- The player starts at the top center of the field (above the compound)

## Fence Degradation

Two independent timers (real-time `game.game_time` ms):

| Fence | Config key | What breaks |
|-------|-----------|-------------|
| Compound | `compund_fence_interval` | Random fence piece on compound wall → sheep can wander out |
| Farm | `farm_fence_interval` | Random piece of outer farm border → wolves/enemies can enter |

Fence pieces are directional flags (`pipe.fences[0..3]`) on individual tiles. `show_hide_walls()` redraws wall visuals after each removal.

## Sheep Behavior

- Sheep are agents of `agent_type = 0`
- Speed: `agent_max_speed_scale × sheep_speed_cfg × rng(0.8, 2.0)`
- Default AI: keep current direction; turn at walls or when blocked
- **Scared state**: when player comes within `dist_to_scare` tiles while sheep is outside its room → A* path back to `rooms[0].get_center()`. Path cost: straight = 1, turn = 20, wall/brick/agent = blocked.
- `check_if_sheep_is_lost(agent)`: sheep is lost if it wanders off-board or off the playable area (`!is_field && room_id < 0`)
- `game.lives_left = number_of_sheep_alive`; HUD shows remaining sheep

## A* Pathfinding

- Used for scared sheep routing back to compound
- `calc_cost_to_move_to()` respects fence flags, bricks, and agent occupancy
- Straight-line movement costs 1; direction changes cost 20 (encourages minimal turning)
- If path fails: fall back to greedy step toward player direction

## Scoring

- Collecting a coin: `+coin_value` (1 or 2 depending on border vs interior coin position)
- Lost sheep: `−1`
- Level complete (win): `+min(5, 60 − elapsed_seconds)` score, `+min(10, 60 − elapsed_seconds)` time bonus
- Correct answer: `+1` score, `+5` time
- Wrong answer: `−1` score, `−5` time

## Lives

- `game.lives_left` = current sheep count (set in `add_sheep()`, decremented on each loss)
- Live icon = sheep sprite (`res://art/sheep2-4x.png`)
- No explicit "game over on lives = 0" — `check_if_no_sheep_left()` calls `level_is_done(false)` when all sheep are gone

## Level Config (`WolvesLevelConfig`)

Defined in `level_config.gd` as `class_name WolvesLevelConfig`.

| Level | Room | Compound fence (ms) | Farm fence (ms) | Sheep speed | Pct sheep | Wolves interval | Dist to scare |
|-------|------|---------------------|-----------------|-------------|-----------|-----------------|---------------|
| 1 | 9×9 | 4000 | 8000 | 0.3× | 30% | 20 | 3 |
| 2 | 11×11 | 2000 | 8000 | 0.3× | 30% | 10000 | 3 |
| 3 | 11×11 | 2000 | 7000 | 0.4× | 40% | 4000 | 3 |
| 4 | 11×11 | 1500 | 5000 | 0.5× | 50% | 3000 | 2 |
| 5 | 11×11 | 1000 | 1000 | 0.5× | 80% | 1000 | 2 |

`pct_sheep` × room area = number of sheep placed. Color per level is set in `_cfg["color"]`.

## Difficulty Scaling

`times_per_difficulty = 3` (3 stages per level). Stage progression tracked as `difficulty` integer.

- Board size: fixed 25×25
- `num_rooms = min(1, ...)` — currently only 1 room (compound)
- `agent_max_speed_scale = min(0.4 + 0.2 × (level − 1), 2.0)`
- On level-up (new level, not just new stage): `game.add_life()`

## Camera

Two camera modes switchable via `zoom_camera(zoom_in)`:
- **Zoom out** (`zoom_in = false`): game-level camera, fits entire board. Always used in Wolves.
- **Zoom in** (`zoom_in = true`): player-following camera, scaled to `room_max_size + 2` tiles wide. Available but not activated.

## Key Implementation Notes

- `_load_cfg()` maps current level to `WolvesLevelConfig.LEVELS[level - 1]`
- `board` is a 2D Array of `OneCell` objects; `OneCell.fences` delegates to `pipe.fences`
- Sheep use `board[p].has_agent = true` to block movement; player also sets `has_agent` on its cell
- `is_wall_between(p, q)` checks fence flags in both directions before allowing movement
- `can_player_go_to(q)` checks `is_field && room_id < 0 && !has_agent && !is_wall_between`
- `can_go_to(agent, q)` for sheep (type 0): checks `!has_agent && !is_wall_between` within the board
- Player starts at `(board_center.x, board_margin)` — top center of the field
- `game.initial_score = 100` — player starts with 100 points
- `BE.upsert_game_state` and `BE.send_event` — backend telemetry calls on new game and level done
- `game.progress_time_pos = 7` — time shown at HUD position 7

## Save Files

Uses standard `GenericGameUtil` file system with prefix `wolves`:
- `settings_v5_wolves.gpa`
- `scores_v5_wolves.gpa`
- `ongoing_score_v5_wolves.gpa`

## Scene / Script Structure

```
wolves/
├── art/                       (copied from mmm, wolves-specific graphics)
├── docs/
│   └── design.md
├── scenes/
│   ├── main.tscn              (root scene)
│   ├── level.tscn             (CanvasLayer with board + UI)
│   ├── agent.tscn             (sheep and wolf agents)
│   ├── player.tscn            (sheepdog player)
│   ├── pipe.tscn              (floor/field/compound tile)
│   ├── empty_space.tscn       (wall tile ring with fence rendering)
│   ├── target.tscn            (unused target markers)
│   └── tube_animation.tscn    (body segment animation)
└── scripts/
    ├── globals.gd             (WolvesG autoload)
    ├── level_config.gd        (class_name WolvesLevelConfig; 5 levels)
    ├── main.gd                (orchestrator; HUD, menu, input routing)
    ├── level.gd               (core gameplay: board, fences, sheep AI)
    ├── agent.gd               (agent/sheep movement and animation)
    ├── player.gd              (player movement, body animation)
    ├── pipe.gd                (tile logic; fences, coins, bricks)
    ├── empty_space.gd         (wall visibility logic)
    ├── target.gd              (unused)
    └── tube_animation.gd      (body segment, unused)
```

## Tutorial

Coached tutorial in `wolves/scripts/tutorial.gd`; see `docs/tutorials.md` for the framework.

- **Entry**: as for the other games; `WolvesG.starting_level` is saved/restored by hand.
- **Hooks in `level.gd`** (no-ops outside tutorial mode): `_on_path_drawn` emits `path_drawn`;
  scaring emits `scared_one` plus `scared_sheep` / `scared_wolf`; a wolf reaching a sheep emits
  `sheep_eaten`.
- **`tutorial_demo_route()`** builds the demo path from the game's own pathfinder (`game.astar`
  with `calc_cost_to_move_player_to`), then rounds the grid corners off. The first version was a
  hand-written zig-zag of fixed offsets: it took no account of the board, so it pointed straight
  through the farm fence, and three equal straight segments looked nothing like a finger drag.
- **`demo_path`**: the tutorial animates a hand tracing that route and then the dog following the
  same line, so the gesture is shown rather than described. "Trace a route" is an instruction players have had to act on
  nowhere else in the app, and words alone were not getting it across.
- **Keyboard is not step-by-step**: an arrow sets the dog walking that way until something stops
  it. The tutorial said "a step at a time", which was wrong.
- **Drawn-path movement**: wolves and storm are the only two games where
  `MainGlobals.draw_path_mode` is on. Everywhere else in the app a finger drag is a flick, a swipe
  answer, or a drag of an object — so this has to be taught explicitly, and the player draws one.
- **`_tutorial_setup()`** moves a single sheep out onto the open field via `_tutorial_field_spot()`.
  The tutorial asks the player to startle a stray back in, and at level start every sheep is still
  safely inside with the fence only just beginning to fail — so without this the player waits in
  front of an intact flock for a stray that may not come.

### Tutorial: the last step

Steps 7 and 8 are adjacent talking steps, so wolves lost its final caption to the shared runner's
double-advance (one tap arrived as both a touch and a synthesized mouse event). 5 of 8 steps
reached the screen. Fixed in `scripts/tutorial.gd` (`_tap_advance`); see `docs/tutorials.md`.
