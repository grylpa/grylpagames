# Gorilla — Game Design

## Concept

A dual-attention game. The player is in a single room collecting coins while monsters chase them. Around the room's periphery, gorillas walk past in straight lines. When all coins are collected (or time runs out), the player is asked: **how many gorillas did you see?**

Trains peripheral awareness while maintaining a central task under pressure.

## Game Flow

1. Level starts: player is placed at center of a room
2. All non-brick room tiles are filled with coins at the start
3. Inside monsters roam the room (kill on contact → lose a life)
4. Gorillas walk across the screen edges (above/below/left/right of the room)
5. When all coins are collected **or** timer hits 0: answer popup appears
6. Player picks how many gorillas they counted
7. Correct → +20 bonus, difficulty increases next round
8. Wrong → no bonus
9. New round begins (score carries over, timer resets)

If all lives are lost before collecting all coins: game over.

## Controls

- Arrow keys / touch drag: move player
- N: new game (with confirmation)
- M: main menu (with confirmation)
- H: help

## Scoring

- **+1** per coin collected
- **+20** for correct gorilla count answer at end of round (error = 0 only)

## Gorilla Count Accuracy (Avg Error)

After each round the player guesses how many gorillas crossed. The **error** is `|chosen − true_count|`. Errors accumulate via `game.add_correct_or_mistake(error, 1)` — `game.corrects` holds the total error sum, `game.mistakes` holds the question count. The **"Error" tab** (progress_tab_name = "Error", progress_time_pos = 7) shows per-session average error (`corrects / mistakes`), with no level grouping (`progress_level_pos = -1`).

Feedback shown to player after each answer:
- Error 0: "Correct! +20 bonus"
- Error 1: "Off by 1 — There were N gorillas"
- Error 2+: "Off by N — There were N gorillas"

## Lives

- 3 lives (set in `globals.gd` via `GenericGameUtil` constructor)
- Lose a life when touching an inside monster
- No lives remaining → game over

## Peripheral Gorillas

- Appear from one edge, move in a straight line, exit the opposite edge
- All spawned gorillas count (including those still on screen when time ends)
- Move in pixel space (not on the board grid)
- Brown color only (fixed; not randomized)
- Scale 0.25 to match inner monster size
- Face movement direction (flip_h for left, ±90° rotation for up/down)
- Speed and spawn rate increase with difficulty

## Inside Monsters

- Move on the board grid within the room
- Cannot overlap each other (one monster per cell at all times)
- Cannot enter brick cells
- Low difficulty: random walk (only changes direction when blocked)
- Higher difficulty: directed toward player
- Player color (blue) is excluded from possible monster colors

## Room Visuals

- Room floor tiles colored with a random color (from `AGENT_COLOR_INDICES`, same palette as mmm)
- Player color: `Color(0.1, 0.5, 0.99)` — same blue as mmm player
- Bricks: one at each wall's center (±1 random shift along wall axis) + `num_bricks` random interior ones; neither player nor monsters can enter brick cells; `_ensure_room_connected()` flood-fills from player start after placement and removes blocking bricks until the room is fully reachable
- All non-brick room tiles start with a coin; `_fill_coins()` places coins after bricks are laid
- Outside walls rendered on the 1-cell ring around the room (using `empty_space.tscn`, same as mmm)
- `game.zoomed_in = true` always set (single room, always fully visible)

## Speed

- **Player**: `speed_scale = 1.3` (fixed); moves 30% faster than the base tick rate
- **Level timer**: 1 minute per round (or ends early when all coins are collected)
- **Monster speed tiers**: each monster gets a speed spread evenly from `agent_speed_min` to `agent_speed_max` by spawn index. At level 1 with 3 monsters: 0.7×, 1.05×, 1.4× player speed. The max grows by 0.2 per level (capped at 2.5×); min stays at 0.7×.

## Monster Spawn Safety

- `MIN_ESCAPE_DIST = 4` cells: a monster may spawn facing the player only if it is ≥ 4 cells away. If closer, its initial direction must not point toward the player. This guarantees the player always has time to react before an approaching monster reaches them.

## Difficulty Scaling

| Level | Room  | Monsters | Monster AI         | Monster speed tiers | Gorillas (random) | Gorilla speed |
|-------|-------|----------|--------------------|---------------------|-------------------|---------------|
| 1     | 9×9   | 3        | random             | 0.7×–1.4×           | 3–6               | 205 px/s      |
| 2     | 9×9   | 3        | random             | 0.7×–1.6×           | 4–7               | 230 px/s      |
| 3     | 9×9   | 4        | random             | 0.7×–1.8×           | 5–8               | 255 px/s      |
| 4     | 11×11 | 4        | 50% directed       | 0.7×–2.0×           | 6–9               | 280 px/s      |
| 5     | 11×11 | 4        | 65% directed       | 0.7×–2.2×           | 7–10              | 305 px/s      |
| 6+    | 11×11 | 5        | directed           | 0.7×–2.4×+          | increasing        | increasing    |

- Room size: 9×9 for levels ≤3, 11×11 for level 4+
- Monster count: 3 (levels ≤2), 4 (level 3–5), 5 (level 6+)
- Gorilla count pre-planned at level start: `randi_range(2+level, 5+level)` gorillas with irregular spawn times distributed over `[3s, level_duration − max_travel_time]`; only spawned if time remains to cross the screen
- `game.game_over_on_time_out = false` — time-over triggers answer popup, not auto game-over

## Settings

- `starting_difficulty` (1–10): slider in main menu

## Save Files

Uses standard `GenericGameUtil` file system with prefix `gorilla`:
- `settings_v5_gorilla.gpa`
- `scores_v5_gorilla.gpa`
- `ongoing_score_v5_gorilla.gpa`

## Key Implementation Notes

- `has_player` and `has_agent` are separate fields on `OneCell` — monsters can enter the player's cell (collision by pixel distance), but cannot enter cells already occupied by other monsters
- `_can_agent_go_to()` checks `has_agent` only; `can_go_to()` (player) checks neither
- Random walk monsters: keep current direction unless blocked by wall/brick/agent; only pick new direction when blocked
- Directed monsters: steers toward player; falls back to random if path blocked; final `has_agent` guard prevents two directed monsters claiming same cell in same tick
- `game.init_sizes()` must be called inside `increase_difficulty()` before `create_board()` so `board_size` is valid
- Bricks shown via `pipe.gd set_rot()` inside the `game.zoomed_in` branch
- `_ensure_room_connected()` runs after all bricks placed; BFS flood-fill from player start; removes border bricks iteratively until all non-brick room cells are reachable
- `coins[p]` stores `true`; erased on pickup; `coins.is_empty()` triggers the gorilla question
- `_fill_coins()` iterates all room tiles after bricks are placed; only puts coins on `is_fillable()` cells
- All sounds loaded from `res://art/sounds/` (shared root folder); gorilla-specific art in `gorilla/art/` (graphics only)
- Coin pickup sound: `Retro PickUp Coin 07.ogg`

## Scene / Script Structure

```
gorilla/
├── art/
│   ├── agent_body1-3.png  (copied from mmm)
│   ├── floor1-2.png       (copied from mmm)
│   └── grass.png          (copied from mmm)
├── docs/
│   └── design.md
├── scenes/
│   ├── main.tscn               (root scene)
│   ├── level.tscn              (CanvasLayer with room + overlay)
│   ├── agent.tscn              (inside monster)
│   ├── player.tscn             (player character)
│   ├── pipe.tscn               (room floor tile)
│   ├── empty_space.tscn        (wall tile ring outside room)
│   ├── tube_animation.tscn     (snake body segment, unused)
│   └── peripheral_gorilla.tscn (edge-crossing gorilla)
└── scripts/
    ├── globals.gd              (GorillaG autoload)
    ├── main.gd                 (orchestrator)
    ├── level.gd                (core gameplay)
    ├── agent.gd                (inside monster logic)
    ├── player.gd               (player movement)
    ├── pipe.gd                 (room tile logic)
    ├── empty_space.gd          (wall visibility logic)
    ├── tube_animation.gd       (body segment, unused)
    └── peripheral_gorilla.gd   (pixel-space gorilla mover)
```
