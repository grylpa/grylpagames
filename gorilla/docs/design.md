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
- Speed and spawn rate increase with difficulty

### Appearance

The gorilla is **drawn in code** by `peripheral_gorilla.gd` `_draw()` — there is no sprite. It used
to reuse the shared `art/enemy_head1-3.png` monster head tinted brown, which read as "some
creature", not as a gorilla.

The whole design constraint is that this figure is **never looked at directly**: the player is
collecting coins in the room while it crosses the edge of the screen. So the silhouette has to
carry the entire read at about one tile tall, out of the corner of the eye:

- heavy hunched mass, shoulders clearly **higher** than the hips (a rump ellipse, a barrel ellipse
  tilted along hip→shoulder, and a separate shoulder-hump ellipse — the hump is what arches the back)
- small head sunk into the shoulders with **no neck**, plus a sagittal crest, a heavy dark brow and
  a lighter muzzle
- long arms reaching the ground ending in fists, short bent legs — the knuckle-walk stance
- a **silverback saddle**: the most recognizable gorilla marking, and the contrast that keeps a
  near-black animal visible against the dark grass

Walk cycle: arms and legs swing on `sin(_phase)`, opposite sides in antiphase. `_phase` advances
with actual travel speed, so a faster gorilla steps faster. The body bobs on every second step
while the ground contacts stay put — that is what makes it feel heavy.

#### Three views

A side-on figure translating up or down the screen reads as **sliding**, not walking, so the
vertical lanes get their own drawing rather than a rotation. `_ready()` picks the view from the
velocity:

| travel | view | notes |
|--------|------|-------|
| horizontal | side | mirrored via `draw_set_transform` to face the way it is going; far-side limbs drawn first in a darker fur for depth |
| downward | front | walking toward the player — brow, two eyes, muzzle, mouth |
| upward | rear | walking away — no face, and the silverback saddle fills the whole back |

Both upright views lean side to side (`sway`), because a front-on walk has no forward motion to
show; the lean plus the alternating raised fist is the entire cue. Head height, shoulder width and
ground line are matched to the side view so a gorilla does not appear to change size depending on
which lane it happens to cross.

Two rules that are easy to break by accident:

- **Never `modulate` the node.** It draws its own fur, saddle, brow and muzzle; any tint flattens
  the silverback back into the body color and costs the figure its main contrast.
- **The figure never rotates.** Rotating it ±90° to "face" up or down — which the old sprite did —
  reads as a gorilla lying on its side. That is what the front/rear views are for.

### Lane placement (clearance from the board)

Every dimension is a fraction of `body_height`, which `level.gd` sets to
`tile_size * GORILLA_TILES` (1.05 — a touch over one tile).

The gorilla's **outline** must clear the room floor by `GORILLA_BOARD_GAP_TILES` (1.0) on every
side, so it never walks over the board or its wall ring. `_spawn_peripheral_gorilla()` therefore
does not pick a tile row any more: it builds, for each of the four sides, the band its **center**
may occupy — bounded by the room plus the gap on the inner edge and by the playfield on the outer —
and picks a random float position inside it. A side whose band is empty is simply not offered, and
if no side has room, nothing spawns. The half-extents come from `HALF_ACROSS_SIDE` / `HALF_ACROSS_FRONT`
in `peripheral_gorilla.gd`, so the placement math and the drawing cannot drift apart.

**This is an exact fit, not a comfortable one.** On a 680×748 playfield with `tile_size` 40 the
board is 15×15; an 11×11 room (level 4+) leaves only ~2.5 tiles between the room floor and the
screen edge, which is one tile of gap plus the gorilla and nothing more. Measured worst-case
clearance is 40.06 px against a 40 px tile. Consequences:

- Enlarging the gorilla, enlarging the gap, or growing the room past 11×11 will start emptying
  bands, and levels will quietly spawn **no gorillas at all** — which silently breaks the game's
  only question. Re-measure if any of those three change.
- The gap is measured from the **room floor**, not from the wall ring. Requiring a full tile beyond
  the ring is geometrically impossible at 11×11.

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

## Camera, Zoom and the Background

`create_camera()` fits the board to the screen:
`zoom = min(tiles_in_screen_w / board_size.x, tiles_in_screen_h / board_size.y)`. `board_size` is
`room_size + 6` (desktop), so the zoom **changes with the level**:

| level | room | board | zoom |
|-------|------|-------|------|
| 1–3 | 9×9 | 15×15 | 1.0667 (magnified) |
| 4+ | 11×11 | 17×17 | 0.9412 (shrunk) |

Two consequences that have each caused a bug:

- **One camera, reused.** `create_camera()` must update the existing `game_cam`, never make a new
  one. Godot only auto-promotes a `Camera2D` to current when the viewport has none, so creating one
  per board leaked a camera each level *and* left the very first one current — the zoom stayed
  frozen at whatever the starting level needed. Starting on level 10 and walking back to level 1
  kept the level-10 view forever, while starting on level 1 looked right the whole way up.
- **The background is screen-space.** `BackgroundRect` lives under `BgLayer` (a `CanvasLayer` at
  `layer = -1` with `follow_viewport_enabled` off), *not* under `Level`, which does follow the
  viewport. At zoom 0.9412 the visible world is 722 px wide against a 680 px viewport, so a
  world-space background leaves ~21 px of bare screen down each side. In screen space it covers at
  any zoom.

**World pixels are not screen pixels here.** Anything positioned from `MainGlobals.screen_size` but
placed in world coordinates is wrong by the zoom factor — off-screen at zoom > 1, short of the edge
at zoom < 1. `_playfield_world_rect()` converts the visible band between the header and the bottom
bar into world coordinates; peripheral gorilla lanes and travel distances are both measured through
it. Use it for anything new that has to reach the screen edge.

## Maze Wall Corners

Each interior wall is a `fence_inner_wall.png` sprite drawn **inside** its owning cell along one
edge — `_create_maze()` only ever uses fence dirs 0 (right) and 1 (bottom), so a right fence covers
the 2 px strip just left of the cell boundary and a bottom fence the strip just above it.

That inset means the four L-junction orientations are not equivalent. Where a wall runs **right**
from a corner and another runs **down** from it, the two bars meet only at a point and the corner
square itself is covered by neither. The other three orientations are covered by one bar or the
other, which is why only the top-left L ever looked wrong:

```
top-left (was broken)   top-right      bottom-left     bottom-right
   ?----                   ----+           +              +----
   |                           |           |----       ----|
```

`pipe.gd show_corner_patch()` fills that square with the matching corner of the wall texture, so
the wall's own shading carries through. A cell owns the patch for its **own** top-left corner.
`_patch_wall_corners()` runs at the very end of `_create_maze()`, after every fence is final —
running it earlier would patch corners that the extra-passage pass then opens up.

**Only a bare elbow gets a patch.** Needing a bottom fence above and a right fence to the left is
not sufficient: if a wall *continues* past the corner the square is already covered, and repainting
those 2 px lands slightly off and shows as a seam — a T looked like its stem poked above the head.
Both continuations belong to the **diagonal** cell (x-1, y-1): its bottom fence is the wall running
left of the corner, its right fence the wall running up from it. If either exists, no patch.

| junction | diag bottom | diag right | patched |
|----------|-------------|------------|---------|
| bare elbow ⌐ | – | – | **yes** |
| T, head runs left | ✓ | – | no |
| T, stem runs up | – | ✓ | no |
| cross + | ✓ | ✓ | no |

The bar thickness is **measured from the texture's alpha once at runtime** (`_wall_thickness()`,
cached in a `static var`) rather than hardcoded, so the patch stays correct if the wall art is
redrawn. It currently measures 2 px, against a 40×40 texture drawn 1:1 over a 40 px tile.

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
│   └── peripheral_gorilla.tscn (edge-crossing gorilla — bare Node2D, no sprite)
└── scripts/
    ├── globals.gd              (GorillaG autoload)
    ├── main.gd                 (orchestrator)
    ├── level.gd                (core gameplay)
    ├── agent.gd                (inside monster logic)
    ├── player.gd               (player movement)
    ├── pipe.gd                 (room tile logic)
    ├── empty_space.gd          (wall visibility logic)
    ├── tube_animation.gd       (body segment, unused)
    └── peripheral_gorilla.gd   (pixel-space gorilla mover + the drawn gorilla itself)
```

## Tutorial

Coached tutorial in `gorilla/scripts/tutorial.gd`; see `docs/tutorials.md` for the framework.

- **Entry**: as for the other games; `GorillaG.starting_level` is saved/restored by hand.
- **Hooks in `level.gd`** (no-ops outside tutorial mode): coin pickup emits `coin_taken`; a
  peripheral spawn emits `gorilla_appeared`; `on_time_over` emits `answer_time`; `_on_answer_selected`
  emits `answered`.
- **`peripheral_gorilla.gd` now takes a `game` reference and returns early from `_process` when
  `game.paused()`.** It ran on its own `_process` and ignored the pause entirely, so it kept
  walking during any pause, popup or tutorial caption — walking clean off the edge, where
  `exited_screen` deletes it. That made the tutorial point at a gorilla that was no longer there.
  This was a real bug outside the tutorial too: the pause screen never stopped these figures.
- The spawn step has **no `await`**. It used to be two steps — one that spawned and waited for
  `gorilla_appeared`, one that talked about it — but the spawn fires that event synchronously, so
  the waiting step advanced from inside its own `_enter_step` and was displayed for zero frames.
  That is what made the tutorial's stage numbers skip. Spawning and holding now happen in the
  setup of the step that talks about the gorilla.
- Gorillas are spawned **on demand** by the tutorial (`tutorial_spawn_gorilla`), not on the level's
  timed schedule: on the schedule one ran past while the coach was still talking about coins, and a
  different one was held up later, which read as a gorilla appearing from nowhere. It prefers a
  horizontal lane (the only kind phones get, and a vertical one held mid-lane sits oddly in the
  middle of the screen edge) but falls back to any available side — insisting on horizontal on a
  screen where the top/bottom bands do not fit produced no gorilla at all.
- The **`player_steered`** hook exists because `GorillaG.always_moving` starts the player walking by
  itself: a "collect a coin" step is satisfied by the game wandering into one, so the coach
  congratulated the player for doing nothing. The movement step waits on a real steer, which is
  only ever reachable from `_input`.
- **`tutorial_show_a_monster()`** spawns one monster, far from the player, on the last teaching
  step. Monsters are off for the whole tutorial (`num_inside_monsters = 0`) so nobody is killed
  mid-lesson — but a player who is never shown one meets their first at full speed with no
  warning, so the tutorial names and points at one while the game is frozen, then ends.
- **`tutorial_hold_gorilla_midscreen()`** slides the live gorilla to the middle of its own lane.
  A gorilla spawns fully off screen and crosses in a few seconds, so a player reading a caption
  misses it entirely and never learns what to look for. The tutorial holds one still, frozen, and
  spotlights it. This was the single biggest gap in the first version.
- **`_tutorial_setup()`** forces `gorilla_spawn_times = [2.5, 9.0]`, and `new_game` sets
  `num_inside_monsters = 0` in tutorial mode. The real schedule can leave the first gorilla until
  well into the level, and being killed by a monster halfway through a lesson teaches nothing.
- **Movement wording**: this game does NOT have the drawn-path movement wolves and storm use
  (`MainGlobals.draw_path_mode` is never set here). A flick is converted to a single direction and
  the player then keeps walking that way, so the tutorial says "flick in a direction", not
  "draw a path". "Flick" on its own means nothing to most people either, so the caption says
  "swipe quickly in the direction you want to go" and adds that you keep walking until you turn.
- The step that waits for `gorilla_appeared` deliberately carries **no** spotlight — at the moment
  it opens the gorilla does not exist yet, so it would point at bare ground. The spotlight is on
  the following step, and the freeze holds the gorilla in place while the coach talks about it.
