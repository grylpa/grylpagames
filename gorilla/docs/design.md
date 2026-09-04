# Gorilla — Game Design

## Concept

A dual-attention game. The player is in a single room collecting coins while monsters chase them. Around the room's periphery, gorillas walk past in straight lines. When all coins are collected (or time runs out), the player is asked: **how many gorillas did you see?**

Trains peripheral awareness while maintaining a central task under pressure.

## Game Flow

1. Level starts: player is placed at center of a room
2. All non-brick room tiles are filled with coins at the start
3. Inside monsters roam the room (kill on contact → lose a life)
4. Gorillas walk across the screen edges (above/below/left/right of the room)
5. When all coins are collected **or** the timer hits 0: the answer popup appears
6. Player picks how many gorillas they counted
7. Exactly right → +20 bonus and the round counts as correct; anything else counts as wrong
8. A new round begins on the same level (score carries over, timer resets) — a round is one
   BUILDING, and the level's difficulty does not change between them
9. After `rounds_per_level` buildings the level is judged: at or above `pass_pct` the next level
   follows, below it the same level is played again (see "Passing a level")

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

After each round the player guesses how many gorillas crossed. The **error** is
`|chosen - true_count|`. `Level._error_sum` and `Level._rounds_answered` accumulate it, and
`Level.mean_error()` is what `main.gd::get_game_score()` writes into the score row. The **"Error"
tab** (`progress_tab_name = "Error"`, `progress_time_pos = 7`) plots that per-session average, with
no level grouping (`progress_level_pos = -1`) — which is why those two counters are cleared only on
a fresh game, not at a level boundary.

Feedback shown to the player after each answer:

- Error 0: "Correct! +20 bonus"
- Error 1: "Off by 1 — There were N gorillas"
- Error 2+: "Off by N — There were N gorillas"

**The error stat used to ride on the shared counters.** `game.add_correct_or_mistake(error, 1)`
banked the SIZE of the error as `game.corrects` and a mistake on every round, right or wrong — so
`corrects` held the error sum and `mistakes` held the question count, and the average was read back
out as `corrects / mistakes`. It worked as a stat and was impossible as anything else: a perfect
answer recorded zero correct and one wrong, an answer off by three recorded three correct, and any
accuracy the level gate might read was noise. The counters now mean what their names say — one
round, one verdict, `add_correct_or_mistake(1, 0)` or `(0, 1)` — and the error stat has its own two
fields.

**Only an exact count is right.** That was already the rule the +20 bonus followed, and "nearly" is
not a thing a player can be asked to count.

## Passing a level

A round is one building. A **level is `rounds_per_level` buildings** (`rounds` in
`GorillaLevelConfig`), and it is passed on the share of them counted exactly right:

```
passed = game.session_pct_correct() >= GorillaLevelConfig.pass_pct_for(level)
```

Below the bar the SAME level is played again; at or above it, the next one. `_finish_level()` runs
when `round_in_level` reaches `rounds_per_level`, and `_advance_if_needed()` — called from
`new_game()` — acts on its verdict.

Before this, **a level could not be failed, only postponed.** `round_in_level` advanced only when
`need_to_increase_level` had been set, and that happened on an exact count — so a wrong answer did
not count toward the level at all. A player could be off by five every time and simply keep being
handed the same level with no summary and nothing said.

**The percentages have to land on a rung.** A level is a fixed number of rounds, so out of 3 the
only scores that exist are 0, 33, 66 and 100; out of 4, 0, 25, 50, 75 and 100. `pass_pct` is chosen
to sit exactly on one: 60 means 2 of 3, 70 means 3 of 4. Recheck them whenever `rounds` changes.

| levels | rounds | pass_pct | really |
|--------|--------|----------|--------|
| 1-5 | 3 | 60 | 2 of 3 |
| 6-10 | 4 | 70 | 3 of 4 |

The last level (10) is judged the same way but never promotes: `is_last` keeps
`need_to_increase_level` false and the card says so.

## "complete!" only when it was

The end of a level now shows the shared level card (`show_level_done_popup`) with the gate result
as its `passed` argument, so it reads "Level N complete!" with a check badge or **"Level N not
passed"** with none. Under it: the last round's own verdict ("Off by 1 / There were 5 gorillas"),
then `Counted right: 2 of 3`, `Accuracy: 66%`, and a line saying what happens next —

- passed -> `Level passed — on to level N.`
- failed -> `You need at least 60% of the buildings counted right to pass to the next level.`

Mid-level rounds keep the small `show_game_popup` "Time's up!" panel they always had.
`MainGlobals.global_level_is_done()` takes the gate result, so the fanfare does not play over a
level that was not passed.

**The tutorial is exempt.** Its session is one building, not a level: `_on_answer_selected` returns
after the round popup when `game.tutorial_mode` is set, so the coach's rounds never add up to a
level end and no card lands on a caption.

## A replay starts clean

`new_game()` is called after EVERY round (main's `_on_level_sig_level_is_done`), so it cannot clear
the level's counters unconditionally. `_level_is_over` is set by `_finish_level()` and is what tells
the next `new_game()` that it is starting a LEVEL: only then does it reset `round_in_level`,
`game.corrects` and `game.mistakes`. Otherwise a retry would inherit the misses that failed the
level and could not pass it even played perfectly.

`_error_sum` / `_rounds_answered` deliberately survive, because the Error stat is per session.

## A failed level earns nothing

`_score_at_level_start` is stamped when a level begins and a level that misses the gate goes back to
it (`_rollback_score_on_next_level`, applied in `new_game()` when Continue is pressed). Otherwise
the gate is a scoring exploit: the score is cumulative across a session, so every failed attempt
banked its coins and the retry cost nothing.

The rollback lands on Continue rather than at the moment the level ends, because watching the score
drop out from under a summary you are still reading is alarming. gorilla does not emit
`game.sig_level_is_done`, so unlike the games that save a score row per level there is nothing to
swap the kept value in for.

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


## The power coin

`powers: 3` per level (`level_config.gd`) places three coins that carry
`res://art/coin-orange-w-power.png`. Eating one calls `player.ate_power()` and opens a
**five-second window** (`DURATION_TO_STOP_POWER`) in which touching a monster kills the MONSTER for
+10 instead of killing you.

**Only the clock closes the window.** Eating a monster used to spend the power — one kill and it was
over — which made the coin worth exactly one monster. It no longer does, so a well-timed run through
a crowd is worth several, and that is the reason to go out of your way for the coin.

**The clock stands still inside a wormhole.** `warp_to()` calls `pause_power_clock()` and the far
end calls `resume_power_clock()`, which pushes `time_started_power` forward by however long the trip
took. Entering a wormhole has to be free: a player who dives in with two seconds left has to come
out with two, or they take the trip meaning to reach a monster on the far side and find the power
gone on arrival. Read elapsed time through `power_elapsed_ms()` / `power_left_ms()` /
`power_left_fraction()`, never by subtracting `time_started_power` by hand — that is what the pause
accounting exists for.

### Telling how much is left

The powered head used to be a looping tween — a one-second breath, scale 1.0↔1.2 with a green tint —
identical in the fifth second and the first. It said "powered" and never "powered for how much
longer", and with a monster's touch fatal the moment it lapses, that difference decides the round.

Two failed attempts are worth not repeating:

- **Ramping the breath from slow to fast, alone.** Rhythm is the only thing that changes, and a
  rhythm is not a quantity — the honest report was "I don't see any effect other than the change in
  rhythm". A state cue cannot double as a gauge.
- **Ending the power with a 6 Hz square-wave flash of the whole head.** It reads as a strobe and is
  genuinely unpleasant to look at, quite apart from what high-contrast flashing does to
  photosensitive players. **Do not flash this game's art.**

So the two jobs are split across two things:

| | |
|---|---|
| the head **breathes** | a smooth sine ramping `PULSE_HZ_START` 1.0 → `PULSE_HZ_END` 2.2 Hz across the five seconds, scale ×1.2 and a green tint over the player's blue. The STATE cue: powered, and running down. Nothing flashes, and the rate tops out well below anything strobe-like |
| the ring **empties** | `PowerRing`, an arc **on the gorilla's own contour** — radius 16, the head's half-size — draining a full circle → nothing and colouring green → amber → red. The QUANTITY: a glance says how much is left without counting breaths, and the colour is a second reading of the same number for a glance too short to judge length |

`PowerRing` is an inner class of `player.gd`, drawn at `z_index = z_index - 1` so it is a halo behind
the head rather than a hoop over its face, with 64 segments — checked against the *zoomed* radius,
which is the mistake Witness's 12-gon direction dots made. It is a copy of the same widget didi has,
not a shared one: games here do not reach into each other's scripts.

**Its radius is the head's, and it breathes by the same factor.** The head is a 128px frame at scale
0.25 — 32 units across, radius 16 — and `_update_power_look()` sets `_power_ring.scale` to the same
`swell` it gives `$Head.scale`. Both numbers come from the Head node, not from this game's player
scene: the 0.25 lives inside `scenes/head_anim.tscn`. A wider ring (it was 22) reads as a separate
hoop the gorilla is standing in, and one that does not breathe lets the head swell out through it.

`_update_power_look()` runs from `_process` off the power **clock**, not from a tween, for two
reasons. A looping tween cannot change its own duration, so the ramp is not expressible in one. And
tween progress does not stop in a wormhole while the clock does — the old pulse froze during a warp
while the power really was draining, so it lied at exactly the moment the player was deciding
whether to dive in.

The ring keeps updating through a warp (it is drawn at the player's origin and the warp only scales
the head), so it simply stands still, which is what the frozen clock means. The head's half of the
update is skipped while `_power_paused_at_ms > 0`, because the warp animation owns its scale then,
and while `was_hit`, because `mark_hit()`'s death tween does. `stop_power()` hides the ring and
restores `orig_head_scale` / `orig_head_color` exactly.

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
- `rounds` / `pass_pct` per level: see "Passing a level"

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
│   └── peripheral_gorilla.tscn (edge-crossing gorilla — bare Node2D, no sprite)
└── scripts/
    ├── globals.gd              (GorillaG autoload)
    ├── main.gd                 (orchestrator)
    ├── level.gd                (core gameplay)
    ├── agent.gd                (inside monster logic)
    ├── player.gd               (player movement)
    ├── pipe.gd                 (room tile logic)
    ├── empty_space.gd          (wall visibility logic)
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
  center of the screen edge) but falls back to any available side — insisting on horizontal on a
  screen where the top/bottom bands do not fit produced no gorilla at all.
- The **`player_steered`** hook exists because `GorillaG.always_moving` starts the player walking by
  itself: a "collect a coin" step is satisfied by the game wandering into one, so the coach
  congratulated the player for doing nothing. The movement step waits on a real steer, which is
  only ever reachable from `_input`.
- **`tutorial_show_a_monster()`** spawns one monster, far from the player, on the last teaching
  step. Monsters are off for the whole tutorial (`num_inside_monsters = 0`) so nobody is killed
  mid-lesson — but a player who is never shown one meets their first at full speed with no
  warning, so the tutorial names and points at one while the game is frozen, then ends.
- **`tutorial_hold_gorilla_midscreen()`** slides the live gorilla to the center of its own lane.
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

### Tutorial: the last step

gorilla's tutorial ends with four talking steps in a row (4-7), which made it the loudest victim of
a bug in the shared runner: one tap was delivered as both a touch and a synthesized mouse event, so
each tap advanced two steps and the tutorial ended on the tap meant to reveal its final caption.
Only 4 of 7 steps ever reached the screen. Fixed in `scripts/tutorial.gd` (`_tap_advance`,
debounced); see `docs/tutorials.md`. Nothing in this game changed — but adjacent talking steps are
what expose that class of bug, so keep the harness check that every step is displayed.

## The lawn

The ground is ONE continuous field of drawn grass over the whole board — `scripts/grass_field.gd`,
shared by the eleven grass games — not a tile. `level.gd`'s `_fit_ground_to_board()` is the whole
installation:

```gdscript
GrassField.fit(get_node_or_null("BgLayer"), get_node_or_null("BgLayer/BackgroundRect") as CanvasItem, game, 13)
```

It hides the tiled `TextureRect` it replaces, attaches a `GrassField` control to `BgLayer` (a nested `CanvasLayer`, `layer = -1`, `follow_viewport_enabled`) so it
draws behind everything, sizes it to the board plus a four-tile margin (merged with the full canvas,
so a board smaller than the screen still has grass to the edges), and sows it. The seed is this
game's own — 13 — so no two games show the same field.

It is called twice: at the end of `_ready()`, so the lawn is already there before the first board is
built, and at the START of `create_board()`, for a level that changes the board's size. `fit()`
re-sows only when the rect actually changed, because the field is a `MultiMeshInstance2D` of tens to
hundreds of thousands of blades and building it is not something to redo between rounds.

Every empty cell used to carry its own 40x40 `grass.png`; `empty_space.gd`'s `_ready()` now hides it.
That per-cell sprite was the real reason the board looked tiled — the background alone was never
it — and the per-cell random rotation some of these games applied made it worse, because the tile
wraps seamlessly and turning a cell breaks the wrap.

`probe_lawn.gd` checks all eleven: the field exists, is the first child of its layer, is sown before
any board is built, covers the board and the canvas, retires the tiled ground only once it has
something in it, and that no cell shows its own grass again.

## No snake body

This game's agents are a head and nothing else. `agent.gd` and `player.gd` used to carry the whole
trailing-body rig copied from the delivery games — `body_ids`, `bodies`, `nbody_parts`, a
`time_back_positions` trail, `find_closest_dist()`, `add_body`/`remove_body`/`final_remove_body`, a
`Skeleton` `Line2D` to string the segments on, and a `tube_animation.tscn` built from
`agent_body2.png` / `agent_body3.png` — but the level always assigned an EMPTY `body_ids`, so the
build loop never ran and not one segment was ever created. Measured by running the game and counting
the nodes, not by reading it.

All of it is gone: both scripts, the `Skeleton` node in `agent.tscn` and `player.tscn`, the
`tube_animation` scene and script, and the two PNGs. `angles` keeps a single entry, the head's
heading, which is all `set_rots()` ever read.

**parkem is the one game that really does grow a body** (four segments on level 1, two on level 2),
so its rig stays. Do not copy this game's `agent.gd` there, or the reverse.

## What this game measures

Session records are the v6 named-dictionary format (see `scripts/generic_game_util.gd`
and `scripts/session_stats.gd`). Metrics reset centrally in `reset(from_scratch)`.

Each answer logs the true count and the signed error, so the Counting panel can show whether accuracy falls away as the load grows.

The full dual-task cost is NOT implemented: it needs occasional rounds with no counting to subtract against, which changes how the game plays and is left as its own decision.

The Counting tab is always present. It needs 3 sessions and answers at two or more gorilla counts, 4+ each.
