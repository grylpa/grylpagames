# Gorilla — Game Design

## Concept

A dual-attention game (redesigned 2026-11-09). The player eats apples in a maze that fills the
screen while monsters chase them. While they do, things happen in OTHER parts of the maze that they
have to notice and go and deal with:

- **A lost baby gorilla** appears quietly somewhere far away and wanders. A few seconds later the
  nearest monster starts hunting it. Get there first and it is rescued; let the monster reach it and
  it is lost. The level is judged on the share of babies rescued.
- **The baby's mother**: each rescue brings a grown gorilla out somewhere ELSE, holding a sword, for
  a few seconds (`gift_ms`). Taking it is exactly eating the old super-food (which no longer
  exists): the same timer ring and colors, the monsters run and can be eaten until it runs out.
- **A bunch of bananas** lies somewhere for a few seconds: a bonus, gone if nobody gets there.

There is no question at the end. Noticing is measured by what the player DOES: whether they get to
the baby, and how soon.

The previous design (gorillas walking past OUTSIDE a small room, and "how many did you count?" at the
end) was dropped: nothing made the player look at the room rather than the edges, the walking
gorillas were slow enough to be watched directly, and one number a minute was a weak, late check.

**The floor holds FOOD, not coins** -- the *code* still says `coin` everywhere (`has_coin`,
`_fill_coins()`, `coins[]`, `PipeCoin1`).

## Game Flow

1. A round starts: the player in the center of a full-screen maze, `apples` apples scattered over it
2. Monsters roam the maze (contact = a life lost, and the round with it)
3. From about 5 s in, lost babies appear one at a time (`babies` per round), each far from the player
   (`baby_far` of the farthest walking distance); after `hunt_ms` the nearest monster hunts it
4. Banana bunches turn up now and then (`bananas` per round), each for `banana_ms`
5. The round ends when every apple is eaten AND every baby has appeared and been dealt with, or when
   the clock (`round_sec`) runs out -- a baby still out then counts as lost
6. After `rounds` rounds the level is judged on babies rescued (see "Passing a level")

If all lives are lost: game over.

## Controls

- Arrow keys / touch drag: move player
- N: new game (with confirmation)
- M: main menu (with confirmation)
- H: help

## Scoring

- **+1** per apple
- **+15** per baby rescued; a lost baby scores nothing
- **+5** per banana bunch
- **+10** per monster eaten while the sword's power is on
- **-15** per life lost

## The lost baby (level.gd "the events")

- `_spawn_baby()` picks an empty floor cell at least `baby_far` x the farthest walking distance from
  the player (`_bfs_from`, through the walls), at least 3 cells from any monster, not a portal.
- It **arrives silently**: no sound, a 0.6 s fade-in (`baby_gorilla.gd`). The game is about noticing
  it out of the corner of the eye; a sound would tell the player when to look.
- It toddles to a neighboring cell every `BABY_STEP_MS` (sometimes not), never into a monster, and
  once hunted never toward the hunter.
- After `hunt_ms` the nearest monster by walking distance becomes `hunter`; on each of its steps it
  takes the shortest way to the baby with probability `hunt_chance` (`_step_toward`), otherwise it
  moves as usual. The baby trembles once hunted (`scared`).
- **Rescued** when the player comes within 0.6 of a tile: +15, `rescue` sound, "Rescued! +15" rises
  from the spot, `game.add_correct_or_mistake(1, 0)`, and the time since it appeared goes into
  `rescue_times`. **Lost** when any monster comes within half a tile: `lost` sound, "Lost!",
  `add_correct_or_mistake(0, 1)`. A baby still out when the round ends (clock, or a life lost) is
  lost too, silently.
- Each baby is logged as a trial `{dist, rescued, ms}` (walking distance when it appeared).
- The next baby comes 4-8 s after the last is resolved. The round cannot end on the last apple while
  a baby is out or still to come, so a baby is never lost to the round simply ending under it.

**The figure** (`baby_gorilla.gd`) is DRAWN AS A BABY: a big round head with a pale face, large
dark eyes with a highlight, small ears, a round belly, short legs, little arms; trembling and
wide-eyed once hunted. The first version reused the adult figure (silverback and all) at a smaller
size and was taken for a grown gorilla. It still extends `peripheral_gorilla.gd` for the views
(side / front / rear, from the way it walks) and the walk cycle, at `BABY_TILES` (0.80) of a tile,
moving cell to cell on the level's say-so (`head_to`). A rescue needs the player to touch it
(within 0.75 of a tile) or reach its cell.

## The mother and her sword

`mother_gorilla.gd`: the adult figure (`peripheral_gorilla.gd`, front view, silverback) standing and
breathing, a sword held up beside her with a glint running up the blade; she fades in, starts to
fade in her last second, and fades out when the sword is taken or her time is up. `_spawn_mother()`
puts her at least 0.40 of the farthest walking distance from the player (`_far_free_cell`), 0.7 s
after a rescue; `MOTHER_TILES` 1.25, so she is plainly bigger than a baby. Reaching her (within 0.8
of a tile, or her cell) calls `player.ate_power()` -- the super-food's own power, ring and colors --
and plays `gift` (a metallic ring). Counted as `gifts_taken` / `gifts_missed`; not judged. There are
no super-food apples any more (`powers_in_level` is forced to 0).

## Bananas

`banana_art.gd`: three bananas hanging from a stem, drawn in code, fading in, blinking in their last
second. `_spawn_banana()` puts a bunch at least a third of the farthest walking distance away, on an
empty cell without an apple. Walking onto it: +5 and the apple crunch. Counted as `bananas_taken` /
`bananas_missed`; not judged.

## Passing a level

A round is one board. A **level is `rounds_per_level` rounds** (`rounds` in `GorillaLevelConfig`),
and it is passed on the share of its BABIES rescued (`game.corrects` / `game.mistakes` count babies):

```
passed = game.session_pct_correct() >= GorillaLevelConfig.pass_pct_for(level)
```

Below the bar the SAME level is played again; at or above it, the next one. `_finish_level()` runs
when `round_in_level` reaches `rounds_per_level`, and `_advance_if_needed()` -- called from
`new_game()` -- acts on its verdict.

**The percentages have to land on a rung.** Levels 1-3 have 3 rounds of 2 babies (6 in all), so
66 = 4 of 6; levels 4-8 have 4 rounds of 2 (8), so 75 = 6 of 8. A round cut short by a lost life
has fewer babies, which only moves the rungs between whole babies. Recheck whenever `rounds` or
`babies` changes.

The last level (8) is judged the same way but never promotes: `is_last` keeps
`need_to_increase_level` false and the card says so.

## "complete!" only when it was

The end of a level now shows the shared level card (`show_level_done_popup`) with the gate result
as its `passed` argument, so it reads "Level N complete!" with a check badge or **"Level N not
passed"** with none. Under it: the last round's own verdict ("Babies rescued: 1 of 2"), then
`Babies rescued: 4 of 6`, `Average time to a rescue: 6.3 s`, and a line saying what happens next --

- passed -> `Level passed. On to level N.`
- failed -> `You need to rescue at least 66% of the babies to pass to the next level.`

Mid-level rounds end on a small `show_game_popup` "Round over" panel with the round's babies.
`MainGlobals.global_level_is_done()` takes the gate result, so the fanfare does not play over a
level that was not passed.

**The tutorial is exempt.** Its session is one board, not a level: `on_time_over` returns after
the round popup when `game.tutorial_mode` is set, so the coach's rounds never add up to a
level end and no card lands on a caption.

## A replay starts clean

`new_game()` is called after EVERY round (main's `_on_level_sig_level_is_done`), so it cannot clear
the level's counters unconditionally. `_level_is_over` is set by `_finish_level()` and is what tells
the next `new_game()` that it is starting a LEVEL: only then does it reset `round_in_level`,
`game.corrects` and `game.mistakes`. Otherwise a retry would inherit the misses that failed the
level and could not pass it even played perfectly.

`rescue_times` is cleared at a level boundary too: the score row's rescue time is the level's.

## A failed level earns nothing

`_score_at_level_start` is stamped when a level begins and a level that misses the gate goes back to
it (`_rollback_score_on_next_level`, applied in `new_game()` when Continue is pressed). Otherwise
the gate is a scoring exploit: the score is cumulative across a session, so every failed attempt
banked its food and the retry cost nothing.

The rollback lands on Continue rather than at the moment the level ends, because watching the score
drop out from under a summary you are still reading is alarming. gorilla does not emit
`game.sig_level_is_done`, so unlike the games that save a score row per level there is nothing to
swap the kept value in for.

## Lives

- 3 lives (set in `globals.gd` via the `GenericGameUtil` constructor)
- A life goes when a monster catches you or you starve (see "Hunger"); nothing gives one back

## The old peripheral gorillas

Removed with the 2026-11-09 redesign, along with the lanes round the room, `_playfield_world_rect()`
and the count question (`AnswerOverlay` stays in the scene, unused). `peripheral_gorilla.gd` stays:
the baby gorilla is drawn by it.

## Inside Monsters

- Move on the board grid within the room
- Cannot overlap each other (one monster per cell at all times)
- Cannot enter brick cells
- Low difficulty: random walk (only changes direction when blocked)
- Higher difficulty: directed toward player
- Player color (blue) is excluded from possible monster colors

## Maze Visuals

- **The maze is the whole board** (`room_rect` = the board), and the board fills the screen: `cols`
  across and as many rows as the screen's shape gives (`_apply_level`; desktop keeps a 34 px strip
  for the level label). There is no ring of empty cells round it any more.
- Floor colored with a random color (from `AGENT_COLOR_INDICES`); player `Color(0.1, 0.5, 0.99)`
- The maze is carved by a randomized DFS from the center, then `extra_passages` extra walls removed
  (never opening a 2x2 block). Bricks are not used (`_add_bricks` is not called).
- `_fill_coins()` puts apples on `apples` random empty cells (plus the super-foods and two portals),
  not on every cell: a full-screen board could not be eaten in a round.
- `game.zoomed_in = true` always set (the whole maze always visible)

## Speed

- **Player**: `speed_scale = 1.5` (fixed)
- **Round timer**: `round_sec` (75-95 s), or the round ends early (see Game Flow)
- **Monster speed tiers**: each monster gets a speed spread evenly from `agent_speed_min` to
  `agent_speed_max` by spawn index, capped below the player's speed.

## The super-food

**There are no super-food apples since 2026-11-09**: their power now comes from the mother's sword
(see above), which calls the same `player.ate_power()`. What follows is about that power -- its ring,
its timer, its colors -- which is unchanged.

`powers: 3` per level (`level_config.gd`) places three super-foods, the one collectible that keeps
a texture rather than being drawn: `res://art/coin-orange-w-power.png`. Eating one calls
`player.ate_power()` and opens a
**five-second window** (`DURATION_TO_STOP_POWER`) in which touching a monster kills the MONSTER for
+10 instead of killing you.

**Only the clock closes the window.** Eating a monster used to spend the power — one kill and it was
over — which made it worth exactly one monster. It no longer does, so a well-timed run through
a crowd is worth several, and that is the reason to go out of your way for one.

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

| Level | Cols | Apples | Monsters | Directed | Baby far | Hunt after | Hunt chance | Bananas (ms) |
|-------|------|--------|----------|----------|----------|------------|-------------|--------------|
| 1 | 11 | 34 | 3 | 30% | 0.45 | 7.0 s | 55% | 2 (7000) |
| 2 | 11 | 38 | 3 | 35% | 0.50 | 6.0 s | 65% | 2 (6500) |
| 3 | 13 | 44 | 4 | 40% | 0.55 | 5.5 s | 70% | 3 (6000) |
| 4 | 13 | 48 | 4 | 50% | 0.60 | 5.0 s | 75% | 3 (5500) |
| 5 | 13 | 50 | 5 | 60% | 0.65 | 4.5 s | 80% | 3 (5000) |
| 6 | 15 | 56 | 5 | 70% | 0.70 | 4.2 s | 85% | 4 (4500) |
| 7 | 15 | 60 | 6 | 80% | 0.75 | 3.8 s | 90% | 4 (4000) |
| 8 | 15 | 64 | 6 | 90% | 0.80 | 3.5 s | 95% | 4 (3500) |

Two babies per round throughout. `game.game_over_on_time_out = false`: time-over ends the round.

## Settings

- `starting_difficulty` (1–10): slider in main menu

## Save Files

Uses standard `GenericGameUtil` file system with prefix `gorilla`:
- `settings_v5_gorilla.gpa`
- `scores_v5_gorilla.gpa`
- `ongoing_score_v5_gorilla.gpa`

## Camera, Zoom and the Background

`create_camera()` fits the board to the screen:
`zoom = min(tiles_in_screen_w / board_size.x, tiles_in_screen_h / board_size.y)`. The board is
`cols` wide (11, 13 or 15) and as tall as the screen's shape allows, so the zoom **changes with the
level** (it used to with the room size).

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
at zoom < 1. (`_playfield_world_rect()`, which converted the visible band into world coordinates for
the old peripheral gorilla lanes, went with them.)

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
- Pickup sound: `Retro PickUp Coin 07.ogg` (the file keeps its name; the object is food)

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
│   ├── level.tscn              (CanvasLayer with the maze; its AnswerOverlay is unused since 2026-11-09)
│   ├── agent.tscn              (inside monster)
│   ├── player.tscn             (player character)
│   ├── pipe.tscn               (room floor tile)
│   ├── empty_space.tscn        (wall tile ring outside the maze; none since the maze is the board)
│   └── peripheral_gorilla.tscn (the old edge-crossing gorilla; no longer spawned)
└── scripts/
    ├── globals.gd              (GorillaG autoload)
    ├── main.gd                 (orchestrator)
    ├── level.gd                (core gameplay)
    ├── agent.gd                (inside monster logic)
    ├── player.gd               (player movement)
    ├── pipe.gd                 (room tile logic)
    ├── empty_space.gd          (wall visibility logic)
    ├── peripheral_gorilla.gd   (the drawn gorilla figure; the baby is drawn by it)
    ├── baby_gorilla.gd         (the lost baby: the figure, small, walking cell to cell)
    └── banana_art.gd           (a bunch of bananas, drawn)
```

## Tutorial

Coached tutorial in `gorilla/scripts/tutorial.gd`; see `docs/tutorials.md` for the framework.
Rewritten for the 2026-11-09 redesign:

1. the maze and the apples; 2. this is you; 3. swipe to turn (waits for a real steer,
   `player_steered`, because the player walks by itself);
4. **a lost baby**: its setup places one (`tutorial_spawn_baby`) and the step spotlights it with the
   game frozen; 5. **rescue it**: waits for `baby_rescued`;
6. **its mother** (`tutorial_spawn_mother`, who waits as long as it takes in the lesson), spotlit;
7. **the sword**: waits for `gift_taken`; 8. keep eating (the hunger ring); 9. monsters
   (`tutorial_show_a_monster` puts one far away, named and pointed at); 10. bananas and the gate.

`_tutorial_setup()` switches off the automatic babies and bananas and sets one baby per round, so
the coach's board can end once the baby it placed is saved. `new_game` sets
`num_inside_monsters = 0` in tutorial mode: being killed halfway through a lesson teaches nothing,
and with no monsters the placed baby is never hunted.

**Movement wording**: this game does NOT have the drawn-path movement wolves and storm use. A swipe
sets a direction and the player keeps walking that way until they turn.

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
hundreds of thousands of blades and room it is not something to redo between rounds.

Every empty cell used to carry its own 40x40 `grass.png`; `empty_space.gd`'s `_ready()` now hides it.
That per-cell sprite was the real reason the board looked tiled — the background alone was never
it — and the per-cell random rotation some of these games applied made it worse, because the tile
wraps seamlessly and turning a cell breaks the wrap.

`probe_lawn.gd` checks all eleven: the field exists, is the first child of its layer, is sown before
any board is built, covers the board and the canvas, retires the tiled ground only once it has
something in it, and that no cell shows its own grass again.

**Gorilla covers that lawn with a RAINFOREST FLOOR** (2026-10-30, `gorilla/scripts/forest_floor.gd`;
the user asked for a background that suits gorillas and picked this direction). The GrassField stays
exactly as above -- node, size, sowing, so the probe still holds -- but its blades are hidden and two
children are laid over it:
- `Forest`, a rect with `forest_floor.gdshader`: dark soil, soft patches of rich moss, a litter of small
  fallen leaves, and dappled canopy light, continuous in the field's coordinates. Its noise is hashed
  from coordinates kept small (`mod 289`): a plain fract-hash ran out of float precision at board
  coordinates and came out in hard-edged squares. `ForestFloor.lay()` from `_fit_ground_to_board()`.
- `Plants`, drawn once the board is built (`ForestFloor.plant()`, end of `create_board()`): a few ferns
  and big fallen leaves at random spots on ground cells, never on the room's floor nor next to it,
  and big tropical leaves overhanging from OUTSIDE the board's rect (a leaf that would reach into it
  is not drawn). Under everything, so nothing the player watches is covered.

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

## The tutorial button, and the spotlight

This game passes `$Level` to `game.handle_event(event, parent)`, and the instructions screen used
to test THAT node for `start_tutorial()` — so the "Interactive tutorial" button never appeared
here, nor in Lights Out, Mind Palace, Storm or Wolves, which pass the same thing. The offer walks
up to the main scene now; see the note in the root `CLAUDE.md`.

**The spotlights are measured, not authored.** `spot_radius` is a number of SCREEN units, and
everything in this game is drawn through a camera that zooms
(`create_camera(min(2.0, 1.0 / board_part_of_width))`) — so no literal can be right: the same 70
is snug at one zoom and a halo the size of the wall at another. Every frame in this tutorial was
too big for that reason, and tuning the numbers one at a time only moved the problem.

`spot` also accepts a Callable returning a Rect2, which `_rect_for()` hands straight back, so
`_tight()` builds the rect from the node's own sprites put through the same canvas transform the
player sees. The zoom cancels out and the authored radii are gone, so there is no dead number
left to tune. The spots came out 46x46 screen units against the 140x140 a radius of 70 produced.

`_visual_half()` cannot just read a node's size, because the player is an Area2D whose picture
lives in a child. It tries three things in order, and each was added because the one before it
left a step with **no frame at all** — which looks exactly like a step that was never written:

1. **The node's own `visual_half()`**, if it has one. The peripheral gorilla is a bare Node2D that
   DRAWS ITSELF: no sprite child exists to measure, so nothing else in this list can see it, and
   the "second job" step showed a bare screen. `peripheral_gorilla.gd` now answers for its own
   extent (`Vector2(body_height * 0.62, body_height * 0.55)`, from the shape it draws). Any
   self-drawing node a spotlight points at has to do the same.
2. **`_sprite_half(n)` on the node ITSELF** — not only its children, so a Sprite2D handed over
   directly (the super-food's `PipeCoin1`) is measurable.
3. **Its children**, for the player and the monsters.

Sprite2D and AnimatedSprite2D get DIFFERENT questions: only the first has `get_rect()`, and
asking both the same one is what made every spot silently fall back to nothing on the first
attempt.

The **Super-foods** step had a different fault with the same symptom — it carried no `spot` key
whatsoever. `superfood_spot` scans `level.board` for the first pipe with `has_coin == 1000` and
points at its sprite.

Because the failure is invisible, `probe_gorilla` now asserts that **every** step carrying a
`spot` resolves to a Rect2, and places a baby first (`tutorial_spawn_baby`) so the baby's spot
has something real to measure instead of passing vacuously. Checking "at least
two resolved" is what let two broken frames ship.

Sixteen games' tutorials still use authored `spot_radius` values, and eleven of them also zoom or
pan a camera, so the same mismatch is latent there. Left alone deliberately: nobody has reported
them, and `_tight()` is here to be copied when someone does.

## Hunger: the centre task is mandatory

The point of this game is what you notice at the EDGE of your attention while your hands are
busy. Nothing used to keep them busy — a player could park in a corner, watch the gorillas and
answer perfectly, and the count stopped measuring divided attention at all. Eating is now a
deadline.

**The allowance comes from the BOARD, not from a clock.** `_restart_hunger()` sets it to
`HUNGER_BASE_MS` plus the walking time to the nearest remaining food
(`_steps_to_nearest_coin() * _step_ms() * HUNGER_SLACK`). The board empties as a round goes
on, so a fixed timer would turn the last four apples in four corners into four death sentences;
sized this way they are four generous windows. Set when something is eaten and when the round
opens, and never shortened afterwards — walking away from the nearest food is the player's own
choice, not a moving goalpost. Manhattan distance under-counts a path around a wall, which is
what the slack is for.

**The clock only runs while the player can actually eat.** Two things stop it, and both are
cases where no food is reachable:

- **power** — you are chasing monsters, not eating, and a super-food that starved you would
  be a trap rather than a reward.
- **warping** — `_move_player_on_tick()` returns immediately while `player.warping`, so food
  cannot be eaten at all. This one was a real bug: a wormhole near the end of a round starved
  the player mid-flight, and because a warp shrinks the player to a point it looked as though
  they had simply vanished and then died of nothing. The count question never arrived. The POWER
  clock had always been paused across a warp for exactly this reason (`pause_power_clock`);
  hunger was not.

**ONE EMPTIED RING IS A DEATH.** An expired clock briefly got a second chance, re-measured from
where the player stood — which meant the ring filled TWICE before a death, and that makes the
whole graphic mean nothing: a gauge that quietly restarts is worse than a tight one. Marking the
second pass red did not save it either; the honest way to be kind is a generous allowance, not a
gauge that lies once.

`HUNGER_BASE_MS` is 5000 and `HUNGER_SLACK` is 3.0, against a walking speed of one tile per
400ms. Anyone heading for food reaches it; standing still for six seconds does not.

**The floor holds FOOD, not coins.** Coins are treasure: you pick them up because they are worth
something, and leaving one behind costs you a prize. The rule is now "keep eating or starve", and
nobody starves for want of a coin — so the objects match the rule. They are DRAWN
(`scripts/food_bit.gd`), for the same reason the lawn and the sorting shapes are drawn: there is
no food art in the project, and a shape made of a few circles is more adjustable than a PNG per
size. `pipe.gd` hides `PipeCoin1` for food.

**What makes it an apple is the SILHOUETTE, not the colour.** The first attempt tried to earn
contrast by choosing a hue that stood off every floor, which meant giving up the stalk and the
leaf — and what was left was a yellow disc, barely different from the coin it replaced and food
only if you were told so. The identifying marks are back: two lobes with a dip between them, a
stalk, and a leaf.

**Contrast is the OUTLINE's job, which is why the colour can be free.** The room floor is
`color_by_index(room_id).darkened(0.3)` with the index drawn at random from
`AGENT_COLOR_INDICES`: dark red, green, yellow, blue, orange, purple, cyan, magenta, pink, olive,
deep green, brown. No hue is safe — red vanishes on the dark red floor, green on the green and
olive ones. A TWO-TONE outline, dark outside and light inside, separates the shape from all of
them, because a mid-dark floor cannot be close to both. Measured across the palette the weaker of
the two still manages **4.48** contrast at worst (the dark ring alone drops to 1.42 on the deep
green floor, the light ring to 2.47 on the dark yellow one), and `probe_gorilla` walks every
index and requires 3.0, so a change to either the apple or the shared palette cannot quietly
break it.

`_lobes()` inflates each circle by the same number of PIXELS rather than scaling the shape, which
is what keeps the outline an even width at any radius. The stalk and leaf are laid down with the
dark rim behind them first, so the outline wraps the whole silhouette and not just the body.

**THE SUPER-FOODS keep their own texture.** `coin-orange-w-power.png` at 1.5x with the pulse tween,
as it always was. They were never big coins and must not become big apples either: size
says "more of the same", and this one does something different. What size cannot say — that they still have to be
eaten before the room is clear, so the round will not end while one is left — the instructions
and the tutorial say in words.

They are never called coins to the player, in either of them. They are FOOD: eating one resets
the hunger clock through the same branch as any apple, so the word has to match the rule.
"Super-food" because it is a term people already know; "pill" was avoided on purpose, since this
app keeps clear of medical framing everywhere else and there is nothing to gain by inviting it
here. PLURAL throughout: `level_config` gives every level `"powers": 2`, so a player never meets
just one. A player who took it for scenery cleared every
ordinary piece, stood about waiting for the count question, and starved, which is the likeliest
explanation for the one starving report the wormhole fix does not cover.

`_tick_hunger()` accumulates the paused time rather than restarting, so the clock resumes where
it stopped — and on the falling edge of a warp it takes a FRESH allowance, because `board_pos` is
still the near end while `warp_to` is running and the food nearest the far end is a different
apple. It also stands down entirely for `in_answering_mode`, a paused game, and a player that has
been hit or removed.

**One ring, two clocks.** Power and hunger never run at once — eating a super-food stops the
hunger clock — so they share the contour instead of fighting over the body. `PowerRing` takes a
`hunger_mode` flag and draws the same arc from a cooler palette, so the ring always means one
thing, "time left on whatever is running", and a glance still says which clock it is. Both
palettes end red, because at the end both mean the same thing.

A wedge drawn inside the gorilla was the first attempt and it was wrong: two gauges on one small
sprite, when the two quantities can never be shown at the same moment anyway.

Power owns the ring while it lasts — `set_hunger()` returns early if `has_power` — and
`stop_power()` deliberately does NOT hide it, because `_tick_hunger()` takes it back the next
frame and a ring that blanks for a frame between the two reads as a glitch.

The blink in the last sixth is held back on purpose: urgency that arrives as a NEW behaviour cuts
through, urgency that is just more of the same gets tuned out.

## Lives are the currency of a round

- A life goes on being caught or on starving, through `_lose_life()`. That round ends, a baby out at
  the time is lost, and `LIFE_PENALTY` comes off the score. The run ends only when the last life
  goes, through `sig_lives_depleted`.
- Nothing hands a life back any more (it used to be an exact count).

`devtools/probe_gorilla.gd` drives the real scene: the tutorial's spotlights (the baby's included),
the hunger allowance, that starving spends a life and ends the round, and the cap on lives.

## What this game measures

- **The score row**: `[didwin, aborted, level, count_error, rescue_ms, rescue_pct]`. `count_error`
  is -1 in every row since 2026-11-09 (the column belonged to the count question; older rows keep
  their values). `rescue_ms` is the level's mean time from a baby appearing to its rescue (9999 when
  none was rescued); `rescue_pct` the share rescued. The scores screen's "Rescue" tab plots
  `rescue_ms` (`progress_time_pos` 8, older rows are skipped as too short) with `rescue_pct` beside it.
- **Trials**: one per baby, `{dist, rescued, ms}`. Rescue time against distance is the natural chart
  for the instrument panel once there are sessions to draw it from. The old "Counting" chart was
  dropped from `game_instrument.gd` `CHART_GAMES`; the "Counting" Summary row (`count_error`) stays
  registered for the older sessions.
- `game.record_times(rescue_times, "rt")` and `record_count("rounds_lost")` as before.

## Sounds

Taking the mother's sword plays `gift` (a short swish and a bright metallic ring). A baby rescued plays `rescue` (a bright rising marimba figure), a baby lost plays `lost` (two soft
falling notes): `devtools/make_gorilla_baby_sounds.py`. A baby's ARRIVAL has no sound, on purpose.

Caught by a monster plays `oof` (a bonk and a comic falling "wah"); eating a monster while the power is on plays `gulp` (a chomp, a rising bloop, a sparkle -- it used to pass in silence). Both from `devtools/make_action_sounds.py`. 

Made for this game by `devtools/make_action_sounds.py` (synthesized, seeded; names in code kept): `explosion` caught (a soft thump; was a car crash), `delivery` an apple eaten (a crunch; was an arcade coin), `start` a short whistle, `swoosh` the warp through a portal (a rising sweep), `feet` the gorilla knuckle-walking on leaf litter (`gorilla_steps.ogg`, a 1.4 s loop of foot, hand, foot, hand, each a dull thud and a dry crackle of leaves; it replaced a Kenney grass footstep on 2026-11-01, to suit the rainforest floor and drop the app's last third-party sound effect).

**Ambient** (2026-10-30; the footsteps were all it had): `gorilla_ambient.ogg`
(`devtools/make_ambient_sounds.py` `gorilla`), a sunny park -- a kalimba and a marimba trading a
bouncy figure in G, a frame drum, a flute tune now and then, birds -- at -6 dB under the footsteps
while the board is up (`main.gd` `_show_level`), stopped at the menu.

**The board's edge casts a soft shadow inward** (`level._add_wall_shade()`, `WALL_SHADE` 0.35 of a
tile, faint), so the room reads as enclosed rather than a flat tile sheet on the lawn. The floor
sprites are at z -1 (`pipe.gd` `_ready`) so the band lies over the floor and under the apples, bricks
and fences. It loops over the board array, not `game.board_size`.

## Look (2026-10)

- Monsters, bombs and the player are drawn by `scripts/monster_art.gd` (a menacing bug; a glossy black
  bomb with a colored band, brass collar, curling fuse and spark, upright and centered; the player a
  glossy round creature with feet, eyes that blink); turns and corners eased by
  `scripts/head_anim.gd` + `scripts/path_smoother.gd`.
- Bricks are drawn by `scripts/block_art.gd`: three types (deep red long bricks; pale pink narrow
  bricks; red with sandy ones mixed in) in one mortar.
- The wormhole is a drawn violet vortex with spiral arms and motes (`gorilla/scripts/wormhole_art.gd`).
