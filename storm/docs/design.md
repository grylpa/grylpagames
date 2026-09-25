# Storm — Game Design

## Concept

A time-pressure management game. A storm is battering your old house and the roof is leaking. You must protect your belongings by placing containers, towels and masking tape under leaks, emptying filled containers at drains, and keeping any room from flooding.

## The drawn path

The path the player drags is the shared `PathOverlay/PathLine` in `scenes/main.tscn`. Its own color
is a fixed orange, which disappeared over the warmer room floors.

The line also fades fast here: `storm/scripts/main.gd` sets `MainGlobals.path_fade_sec = 0.18`
against the 0.6 default. The path is laid out in SCREEN space, and storm's camera follows the
player, so the board slides out from under the line the moment the finger lifts and it stops
describing the route that was asked for. It is a confirmation of the gesture, not a marker.
Measured: gone 200 ms after release, against 617 ms at the default. Wolves keeps the default
deliberately -- it always uses the whole-board camera, never scrolls, so its line stays meaningful.

`storm/scripts/level.gd::path_color_at(bp)` reports what color a board cell is -- a room floor is
painted `color_by_index(room_id).lightened(0.5)` in `pipe.gd`, so the path is told exactly that --
and `main.gd` registers it as `MainGlobals.path_color_probe` when the level is shown. The overlay
then gives the line a `Gradient` whose stops are black or white, whichever the cell underneath is
further from by Rec.709 luma. Games that set no probe keep the plain orange, and the chooser clears
the probe on every game switch so one game's cannot leak into the next.

Measured, and worth knowing before changing the palette: every one of the 13 room colors comes out
light after `.lightened(0.5)` (luma 0.62 to 1.00), so today the ink is dark on all of them. Cells
with no room fall back to light, which is right for both things the path can cross -- the marble
corridor tile is luma 0.79 and the brick walls 0.40 to 0.58, and dark ink reads on all of it. The
per-cell machinery only starts doing visible work if a genuinely dark floor is ever introduced.

## Corridor floor

The corridor tile is the `PipeImageNoDir` sprite in `scenes/pipe.tscn`, shown by `pipe.gd` for a
cell with no directional pipe art. It uses the shared `res://art/marble_tile.png`, the same light
marble mind palace uses, rather than `art/pipe_no_dir.png`.

Only four games have this node at all -- mmm, storm, gorilla and wolves. The other ten games with a
`pipe.tscn` have no corridor floor: their pipe is a directional tube or road.

## Game Flow

1. An intro popup describes the round (room count, storm duration)
2. The storm starts: leaks appear periodically on random room tiles
3. The player walks to leaks, selects a tool from the action panel, and places it
4. Tools fill with water over time; when full, the leak pours onto the floor again
   - A tile that is itself full SPILLS into its neighbors -- see "Water spreads" below
5. The player carries full tools to a drain to empty them
6. Round is WON when the storm passes (`storm_duration_s = 60 × (1 + level)` seconds) with no room
   ruined.
7. Round is LOST the moment any room is ruined (the level's `room_ruin` share of its floor under water) -- see "Ruined
   furniture, ruined rooms" below.
8. 3 rounds complete a level; completing a level advances to the next

## The water: one growing circle per leak

**Every leak makes its own puddle, a circle centered on its drip that keeps growing.** Its area is
the water that leak has poured onto the floor -- `pipe.floored_total`, everything it dripped with no
tool under it or with a full one -- spread `PUDDLE_DEPTH` (0.3) deep: radius = √(floored / depth / π).
So it grows endlessly, and slower and slower, as the same trickle has more floor to cover: at level
1's 2× rate a lone leak is about 1.1 tiles across in radius after a minute. A tool or tape under the
leak stops its circle growing (`pipe.pour()`). Puddles do not interact: where two meet they overlap,
and a tile under both counts once. A puddle stays in its own room, and walls, bricks and drains cut it at their tile edges. A doorway is floor.

`level.puddles()` lists them -- `{center, r, room, drip, seed}` -- and it is the single source for
both the drawing and the rules, so what counts is exactly what is shown. `level.tile_coverage()`
says how much of one floor tile its room's puddles cover, from four sample points in it.

**What came before, so it is not rebuilt.** Water was simulated flowing between tiles: a full tile
spilled into its neighbors, then water leveled out between tiles down to a film, then diagonal flow
was added so a pool stopped growing as a "+", then the flow was sped up so a leak inside a pool did
not just fill its own tile. Each step fixed the last one's symptom, and the whole never did the one
thing wanted -- a leak left alone spread to about a 3x3 block and stopped, because water only moved
while a tile held more than the film. The drawing went through five versions on top of it. The
circle model replaced all of it: the flow, the spill, the leveling, the diagonals, tile water levels
and tile "overflows".

### Bricks and drains fill their tiles

Water stops at the edge of a tile it cannot enter, so anything drawn smaller than its tile left a
strip of floor between it and the water. The brick art (`res://art/bricks1-3.png`, shared with other
games and left alone) is 32 px in a 40 px tile: `pipe._fill_tile()` crops each brick sprite to the
part of its image actually drawn (`Image.get_used_rect()`, at runtime) and stretches it over the whole
tile. The drain was a round grate on the floor; it is now drawn by `StormToolArt.draw_drain()` as a
metal plate over the whole tile -- bevel, four screws, the round grate in the middle -- so the tile
itself reads as "not floor" and the water meets it edge to edge. `art/drain.png` is no longer drawn.

## How the water is drawn

**One layer, not divided into tiles** (`scripts/flood_layer.gd`, `StormFloodLayer`). Each leak's
puddle is drawn as a plain circle (`draw_circle`), every frame, at its current radius -- so it is exact
and grows smoothly by construction. Per room, the circles sit inside a `CanvasGroup`, which renders
them together into one layer before blending: overlapping puddles merge into one body of water
instead of stacking darker. `scenes/water.gdshader`, on each group, colors that layer (deeper away
from the shore) and lights its shoreline, found by looking a few pixels around for dry floor -- the
outline of all the puddles together, so an overlap shows no arc inside the water, and no line is drawn
along a wall.

**A doorway is floor.** Doors are drawn hidden, so a door tile looks like any other, and counting it
as "not floor" left one dry tile at the mouth of every corridor. Corridor tiles belong to no room, so
a room's water still never runs out into one.

**What water can never cover.** The same shader keeps each room's water to that room's floor: every
pixel looks up its tile in `floor_mask` (one texel per tile: the room id + 1 on floor, 0 wherever water
can never be -- walls, bricks and drains, `level._is_floor()`), and anything but this room's floor is
dropped. So the water stops exactly at their edges, which their art fills, and never reaches another
room. The pixel's tile comes from the group's own geometry in the vertex stage (`local_px`).

Measured in a real renderer: walls, bricks and drains inside a puddle and a neighboring room stayed
0% wet; the floor two pixels from each of their edges was water; three overlapping puddles had not one
dry pixel of 17,500 sampled inside them; a lone puddle of radius 3.2 tiles measured 3.198-3.213 in 36
directions; a puddle growing a tile a second grew on 59 of 60 frames, about a pixel at a time. A round
with 25 puddles of radius 3 ran at 60 fps on desktop (not measured on a phone).

**Drop rings** are drawn per room after the water (`_draw_rings`): single drops with pauses, each drip
on its own rhythm (`DROP_SLOT` 1.6 s slots, a third of them empty), kept to the leak's own tile.

**Draw order.** The layer is at z −1 and added after every tile, and each tile puts its floor sprites at
z −1 too (`pipe.gd` `_ready()`): the floors draw first by tree order, the water over them, and
everything standing on the floor (bricks, furniture, tools, coins at z 0; the player at 3; doors at 10)
above it.

**What came before, so it is not rebuilt.** A shader that tested circles per pixel through a per-tile
lookup texture (which puddles are near each half-tile square). Every problem the water had came from
that lookup and each fix added another layer to it: first interpolated distances, which drew every
circle as a polygon; then two listed puddles per square, which left a dry notch with a square corner
where three met; then growth only at each 0.2 s rebuild, in visible steps, patched with extrapolated
growth rates. Two traps on the way to this design: a room's floor drawn as a `clip_children` parent
around the `CanvasGroup` was copied INTO the group's layer, so the group read the floor as water and
filled its bounding square (a radius-3.2 circle reached 4.6 tiles on the diagonals) -- hence the mask in
the shader; and working out a pixel's tile from `SCREEN_UV` and the layer's screen transform put the
mask in the wrong place entirely (water on drains, none against walls) -- hence `local_px`.

`art/rect_water.png` and `art/rect_water_white.png` fed the first per-tile version and are no longer
used.

## Ruined furniture, ruined rooms -- how a round is lost

Both are judged by how much of each floor tile the puddles cover (`tile_coverage()`), from the same
circles that are drawn. `level._check_floods()` runs every major tick.

- **Furniture is ruined when puddles cover `FURNITURE_RUIN` (75%) of its tile**, not the moment the
  floor is damp: a leak can start right on a rug, and at level 1's fill rate that leaves about 12 s to
  get a tool under it. A ruined piece goes dark and dull (`pipe.ruin_furniture()`), costs its value,
  and counts in `round_items_lost` and the `items_ruined` count.
- **A room is ruined when the level's `room_ruin` share of its floor is covered** (0.4 on every level
  for now; `level.room_ruin()`, `room_flood()`; walls, bricks and drains are not floor and do not count), and **one ruined room loses the round** ("A room
  flooded!"). The worst room's share is in the HUD strip, "Worst: 23%", centered on the strip at the
  clock's size, white while safe and warming toward red as it nears the line (`main.gd`'s
  `_update_flood_label()`, from `level.worst_room_share()`). It was a small label in each room's corner
  first (easy to miss, and out of sight whenever that room was), then a line under the strip.
- **Getting through the storm without a ruined room wins** (`on_time_over()`).

Two rules came before and both stopped working. Furniture was lost, and the round failed at 30% of
tiles, when tiles OVERFLOWED -- which stopped happening once water spread out, and tiles no longer hold
water at all. Then a "rain caught" bar (a share of the leaked water that had to be kept
off the floor, against half of what the round's tools could have caught) existed only so that an
empty house would lose, since the 30% rule let one win; it does now anyway, by flooding a room, and
one rule is easier to say and to show. The share itself is still worked out -- every tile keeps
`leaked_total` and `floored_total`, and `rain_stats()` gives caught = 1 − floor water / leaked water --
and is shown on the round card as "Rain caught", with "Worst room: N% flooded".

**The cards say how close it was.** The round card ("Well done!" / "Oh no!") and the level summary show
"Worst room: N% flooded" directly above "Room is lost at: M%" (the level's `room_ruin`), then rain
caught, score, time, furniture saved and ruined. The level summary used to show no numbers at all; it
now gets the same lines.

`probe_storm_rain.gd` checks: a puddle's area is the water it was given, it keeps growing past the
old 3x3, a tool stops it, overlaps count once, a puddle never covers another room, the drawing is
water under a puddle, runs on under a wall and never onto another room; a leak starting on furniture
does not ruin it at once, it is ruined once covered and costs its value, a room knows its covered
share, and a room past the line ends the round.

## Controls

- Click/tap a leak (when close) → action panel opens; select a tool or pick up a filled one
- Click/tap a drain (when close) → select a tool to empty
- F / L: faster / slower game speed
- N: new game
- M: main menu

## Scoring

- **initial_score = 100** per game session (carries across rounds and levels)
- **−value** when a piece of furniture is ruined (`_check_floods`)
- **−1** when a tool's container fills up (`action_full` flag in `pipe.gd`)
- **+2** when a tool is placed on a leak
- **+5** when a tool is emptied at a drain
- **+1/+5** for correct / **−1/−5** for incorrect answers (via `answered()`)
- **End-of-round bonus**: `min(5, 60 − elapsed_seconds)` score and time (can be negative for slow rounds)
- Score is clamped at 0 (never goes negative)

## Score Saving

`score_was_changed` is set when `add_score_and_time` is called with `is_actual_score=true` (the default). The countdown timer passes `is_actual_score=false` so mere time-passing does not count as "having played." A score is only saved if the player actually placed a tool or lost something to the water.

## Levels

12 levels in `scripts/level_config.gd` (`StormLevelConfig.LEVELS`), and **every difficulty setting is
a column of that table** -- `level.gd`'s `_apply_level()` reads the level's row (`get_level()`, which
holds at the last row past the end) and works nothing out from the level number. The columns, each
documented at the top of the file:

`rounds`, `fill_rate`, `room_ruin`, `rooms`, `board`, `room_size`, `storm_sec`, `leak_every_ms`,
`bricks_per_room`, `drains_per_room`, `furniture_per_room`, `tools` (bucket / rag / fix / cup / plate
counts), `player_speed`, `corridor_run`, `blackout_every_sec`.

They were formulas in `level.gd` -- rooms `min(12, level)`, board `51 + 2 × level`, storm
`60 × (1 + level)` s, bucket / towel / tape `min(3, 1 + level)` each -- and constants (leaks every 2-4 s,
2 bricks and 1 drain per room, 4 cups and 4 saucers, player speed 1.5, rooms 9-12 tiles, blackouts
every 10-20 s, 3 rounds a level; the table's `rounds` column existed and was never read). The table
reproduces all of them, except furniture: that was 3 pieces for the whole board, handed out a room at
a time, and is now `furniture_per_room` (3 / 2 / 1 over the first three levels, close to the old total).

**`fill_rate`** is how fast a leak pours, as a multiple of `pipe.BASE_WATER_RATE` (0.01 of a tile-full a
second). The floor and the tools pour at it, so it also sets how fast puddles grow and rooms flood.

**Rooms that do not fit.** `create_rooms()` gives up on a room after 900 tries, so a board too small for
its `rooms` gets fewer: level 12 asks for 12 rooms on 75 × 75 and gets 9 (it did before the table too).
The briefing card shows the real count. Raise `board` to get them all.

`probe_storm_rain.gd` checks that every row has every column; a real run of levels 1, 3 and 12 built
boards matching their rows exactly, apart from level 12's rooms.

## Tuning with a bot (`devtools/measure_storm.gd`)

A bot plays rounds like a person -- sees only the camera's view, notices a leak after 0.9 s, walks at
the player's speed, a second per menu choice -- ten times faster than real time (see
`devtools/README.md`). First measurements, 3-4 rounds each (2026-09-25):

Level 1 (1 room, 120 s, 14 tools):

| fill | leaks every | ruin | won | worst room (avg) |
|---|---|---|---|---|
| 1.5 | 2-4 s | 40% | 0 of 4 | 40% |
| 1.5 | 3-6 s | 40% | 2 of 3 | 37% |
| 1.5 | 4-8 s | 40% | 4 of 4 | 23% |
| 1.0 | 3-6 s | 40% | 4 of 4 | 18% |
| 2.0 | 4-8 s | 40% | 3 of 3 | 30% |

Level 2 (2 rooms, 180 s, 17 tools):

| fill | leaks every | ruin | won | worst room (avg) |
|---|---|---|---|---|
| 2.1 | 2-4 s | 40% | 0 of 4 | 40% |
| 2.1 | 4-8 s | 40% | 1 of 4 | 39% |
| 1.5 | 4-8 s | 40% | 0 of 4 | 40% |
| 1.5 | 5-10 s | 40% | 2 of 4 | 37% |
| 1.0 | 4-8 s | 40% | 4 of 4 | 31% |
| 1.5 | 4-8 s | 50% | 4 of 4 | 40% |
| 1.0 | 5-10 s | 40% | 4 of 4 | 25% |

**The whole ladder, as applied** (every level: rooms lost at 40%; checked from the table itself):

| level | rooms | storm | tools | fill | leaks every | won | worst room (avg) |
|---|---|---|---|---|---|---|---|
| 1 | 1 | 2 min | 14 | 1.5 | 4-8 s | 4 of 4 | 24% |
| 2 | 2 | 3 min | 17 | 1.0 | 4-8 s | 4 of 4 | 29% |
| 3 | 3 | 4 min | 17 | 1.0 | 4-8 s | 3 of 3 | 35% |
| 4 | 4 | 5 min | 17 | 1.0 | 5-10 s | 3 of 3 | 33% |
| 5 | 5 | 6 min | 17 | 1.0 | 8-16 s | 3 of 3 | 34% |
| 6 | 6 | 5 min | 29 | 1.0 | 6-12 s | 4 of 4 | 31% |
| 7 | 7 | 5 min | 32 | 1.0 | 5-10 s | 4 of 4 | 33% |
| 8 | 8 | 5 min | 35 | 1.0 | 5-10 s | 2 of 4 | 34% |
| 9 | 9 | 5 min | 38 | 1.0 | 5-10 s | 4 of 4 | 32% |
| 10 | 9 | 5 min | 38 | 1.0 | 4-8 s | 4 of 4 | 33% |
| 11 | 9 | 5 min | 38 | 1.5 | 6-12 s | 3 of 4 | 32% |
| 12 | 9 | 5 min | 38 | 1.5 | 5-10 s | 1 of 4 | 39% |

The shape, decided on the way (also at the top of `level_config.gd`):

- **The flood line never moves.** Difficulty does not come from a more forgiving room.
- **The storm stops growing at 5 minutes.** At a minute a level with a fixed 17 tools, the tools were
  all placed within the first few minutes and every leak after that poured freely: from level 6 up
  nothing was winnable at any leak rate tried (8-16 s included; level 12 lost even at an 80% line).
- **From level 6, 3 more tools per room past two** (a bucket, a towel and a cup), so a leak in any room
  can be covered. The tool menu shows at most 24 at a time, and the bot plays under that cap too.
- **No more than 9 rooms**, all four of levels 9-12 on the same 75 x 75 board, harder by leaks and fill
  alone. Pooled over those four identical levels, 12 rounds per setting: fill 1.0 at 6-12 s won 12,
  5-10 s 11, 4-8 s 9; fill 1.5 at 6-12 s 9, 5-10 s 6; fill 1.0 at 3-6 s 4. (A level-9 board sometimes
  fits 8.)

Three rounds a setting is a rough read -- level 8's 2 of 4 sits between two 4-of-4 levels and is most
likely noise.

How often leaks come matters more than how fast they pour: with the tools all placed by the
middle of the round, every leak after that pours freely. Rounds vary a lot on level 2 (rooms of
different sizes), so a setting near the edge can read 2 of 2 in one run and 0 of 4 in the next.

## Tools

Tools are defined as `CAction` objects with a `name`, `id`, `level` (current fill), and `overflow_level`
(its capacity). `level.gd` deals them per level from one table: `bucket`, `rag` (the towel) and `fix`
(masking tape) `min(3, 1 + level)` each, and four each of `cup` and `plate` (the saucer). Capacities:
bucket and towel 1.0, cup 0.55, saucer 0.225; tape 0, because tape does not hold water -- it stops the
leak outright.

Every tool keeps its OWN level, and a part-full one goes back to the inventory still part full. That is
why the inventory shows each tool separately with its level drawn on it, and not a count per kind.

### How the tools are drawn

`scripts/tool_art.gd` (`StormToolArt`) draws all five in code. The inventory box (`action_panel.gd`)
and the tool standing on a tile (`pipe.gd`'s `_tool_draw`) call the same `draw_tool(ci, name, mid, s,
fill)`, where `fill` is 0..1 of that tool's **own** capacity (`level / overflow_level`). They used to be
40 px PNGs (`art/bucket.png` and the rest, with `*_mask.png`) tinted by `bucket_fill.gdshader` below a
straight cut line at the raw level, so every tool filled as a band rising through its picture -- a
saucer included -- and a full cup showed a line at 55% of its height. Those PNGs are no longer drawn,
and neither is `drain.png` (see "Bricks and drains fill their tiles").

- **Bucket** -- a steel pail cut away, water rising inside its tapered walls, with a lit surface line.
- **Cup** -- a red enamel mug with a white lip, cut away the same way.
- **Saucer** -- in three-quarter view. It is shallow, so its water SPREADS instead of rising: a pool
  from the middle that widens, by area, until at full it reaches the gilt line at the rim. The first
  version stopped the pool at the inner well, leaving a ring of dry china, so a full saucer spilling
  onto its tile still looked as if it had room.
- **Towel** -- a coral towel hanging over a rail, the way a hotel sign draws one: the rail showing on
  both sides, a shorter front layer, a longer back layer below it, two bands near the hem. It soaks up
  rather than fills: the wet part darkens from the hem up, and a soaked one drips. Two flat versions
  (a striped slab with a fringe, then a folded towel from above) read as a rug and a book.
- **Masking tape** -- two strips laid in an X with torn ends: the patch over the hole, which is what
  tape DOES here. A roll of tape was tried first and said only "you have tape". No level.

Nothing on a tool is blue: blue is the water, and a blue cup would read as a full one.

## Pipes (Leaks)

- `pipe.gd` handles one tile's leak: `pour(amount)` sends it into the tool under it or onto the floor
  (`floored_total`, which sizes the leak's puddle -- see "The water: one growing circle per leak")
- Tiles hold no water of their own, and the water is not drawn by the tile.
- `action_level` (0→overflow_level): how full the placed tool is
- When `action_level >= overflow_level`: tool is full, `action_full = true`, −1 score penalty fired once; the leak then pours onto the floor again
- `set_action()` resets `action_full` so placing a new tool or draining clears the state

## Drains

Drain tiles are special pipes (`is_drain = true`). When a filled tool is placed on a drain, `action_level` is reset to 0 each frame — the container empties. The player gets +5 for a successful drain.

## Rooms & Board

- Board divided into rectangular rooms connected by corridors
- Player is a walking character that must be close to a leak or drain to interact
- **The player runs in a corridor**: each step into a corridor tile is taken at the level's
  `corridor_run` (2 on every level) times `player_speed`, each step into a room at `player_speed`
  (`level._set_player_pace()`, from `move_player_on_tick()`). Nothing happens in a corridor -- no leak,
  tool or furniture -- so it is only the way to the next room, and walking it at room pace was dead
  time. The ladder in "Tuning with a bot" was measured before this, walking; running only makes a
  level easier.
- **A corridor's tiles are listed in walking order** (`_try_corridor_L()`). A straight run going up
  or left used to be listed low to high whatever its direction, so its path jumped from its start to
  its far end and back; the door put one step back from the first two tiles then landed off the board
  -- "Invalid access of index 75" on a 63-tile board, from `add_door_at()`, about one run in five of
  `probe_storm_rebuild`. That probe now checks the order in all four directions.
- Furniture (flower, screen, rug) placed in rooms is what there is to lose: ruined when the water covers it

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
│   ├── target.tscn
│   ├── blackout.tscn
│   ├── help_label.tscn
│   ├── action_panel.tscn
│   ├── water.gdshader       (colors each room's merged puddles; keeps them to its floor)
│   └── bucket_fill.gdshader (the old tint; no tool uses it any more)
└── scripts/
    ├── globals.gd         (StormG autoload)
    ├── main.gd            (orchestrator)
    ├── level.gd           (core gameplay, board, rooms, leaks)
    ├── level_config.gd    (StormLevelConfig — 12 levels)
    ├── pipe.gd            (one tile's leak: pours into its tool or onto the floor)
    ├── tool_art.gd        (StormToolArt — the five tools, drawn)
    ├── flood_layer.gd     (StormFloodLayer — the water on the floor: one circle per leak)
    ├── action_panel.gd    (one inventory box)
    ├── empty_space.gd
    ├── door.gd
    ├── target.gd
    ├── agent.gd
    ├── player.gd
    └── tutorial.gd
```

## Tutorial

Coached tutorial in `storm/scripts/tutorial.gd`; see `docs/tutorials.md` for the framework.

- **Entry**: as for the other games; `StormG.starting_level` is saved/restored by hand.
- **Hooks in `level.gd`** (no-ops outside tutorial mode): `_on_path_drawn` emits `path_drawn`;
  `add_leak` emits `leak_started`; `create_actions_popup` emits `tapped_too_far` when the tap is
  out of reach; placing a tool emits `tool_placed`.
- `tapped_too_far` exists because tapping a leak you are not standing next to does *nothing* — no
  message, no sound. That silence is the most confusing thing in the game, and the hook lets the
  coach explain it at the moment it happens rather than in the abstract.
- **`demo_path`**: the tutorial animates a pointing hand tracing a route from the player, the same as
  wolves, so the drawn-path gesture is shown rather than described.
- **Drawn-path movement**: storm and wolves are the only two games where
  `MainGlobals.draw_path_mode` is on, so nothing a player has learned elsewhere suggests it. It is
  taught early and the player has to draw one, because reaching a leak in time is the whole game.
- The tutorial also states outright that the score starts at 100 and only falls — a number counting
  down with no explanation reads as a bug or a timer.
- The level's intro popup is skipped in tutorial mode.

## The level intro

The briefing is the shared card (`GenericGameUtil.show_game_popup` -> `scripts/result_card.gd`),
the same one every other game uses, on its BRIEFING tone (cool header, "Start" on the button). It
replaced `show_text_popup` / `PopupText`, a fixed-size yellow panel that sized itself to its text
and so needed every line hand-wrapped with `\n`.

Two things follow from that and both matter when editing the text:

- **Prose is written as sentences.** The card wraps it. Hand-broken lines now come out as separate
  centered fragments.
- **A fact is written `Label: value`** and is set as a table row, label left and value right, with
  a hairline between adjacent facts. So the facts are grouped together, not scattered between the
  prose lines, or they end up as separate one-row tables.

**The card goes up at once, held, while the board is built behind it.** `level.new_game()` shows the
briefing immediately and holds it (`game_popup.hold()`): the card reads only "Building world" and has
no Start button, over the card's usual DIM background (`hold(message, false)`), so the mansion is
seen going up behind it -- and nothing closes it -- not the button, a tap outside, Enter, Escape or
`sig_need_to_close_info_popups`. (For a while the held card had an opaque background, because the
build behind it read as one room turning into another. That was the camera, not the build: see "The
build is watched" below.) It is laid out at its final size from the start: the real text (with
the planned room count) is already in it, hidden, and the text it is released with has the same lines.
The briefing says three things (`_brief_text()`): how many rooms there are to protect, and, as a
table, "Storm lasts" and "A room is lost at: N% under water" -- the level's `room_ruin`, which differs
per level. When the board is ready AND the card has been up at least `BRIEF_HOLD_MS` (1 s, so the hold never
flickers past as a glitch), `_release_brief()` fills in the real text -- with the rooms the board
actually got, since `create_rooms()` can place fewer than planned -- and shows Start. The round starts
when the card closes (its own `closed` signal).

It replaced a yellow "Building level" notice (the `BuildingLabel` node, now removed) that flashed up
on its own while the board was made, followed by a card whose room count corrected itself once the
board existed. Measured in a real run: the card stays 303 px tall from the moment it appears through
the release. Two things had made it jump by 20 px -- a disabled button is drawn in a shorter style (the
held button now only stops taking the mouse), and `ResultCard.set_body()` set a second time kept its
old lines until the end of the frame and put a gap above the new first line (they are now removed at
once).

**The build is watched, in the view it will be played in.** The rooms are placed first, unseen
(`add_pipe()` leaves a tile hidden until `_build_framed`): every room is down within the first few
slices -- about 10 frames on level 9 -- and the camera cannot frame the mansion before it knows where
the rooms are. Then `_frame_build()` puts the camera on the mansion view (`zoom_camera(false)`) and
shows them all at once, and the rest of the build is drawn live in that one view: the corridors, one
connection at a time (about 100 frames on level 9), then the walls sweeping down the board a slice of
rows at a time. Each tile takes its final look as it is added -- a tile's look is its own, its room's
color or corridor floor, so `set_rot()` needs no neighbors -- and each wall tile is walled as it goes
down (every tile is floor or not by then), where there used to be a separate pass over all of them.
Framing each room as it was placed was tried first: the first room filled the screen and the view then
zoomed far out, since all the rooms are down in a fraction of a second and the rest is corridors.
Measured on level 9: the camera's zoom is 0.274 from the frame the rooms appear to the end of the
build; on level 1 it never changes.

**The board is built in the whole-mansion view, and a mansion is previewed before play.** Storm is
not an exploration game. The build calls `zoom_camera(false)`, so what is behind the briefing is the
whole mansion -- it used to be the player's room, then a zoom out for the preview, then a zoom back
in. Once Start is pressed:

- **Several rooms:** that view stays for `PREVIEW_SEC` (5) with the HUD's countdown -- the one Lights
  Out uses -- then the camera glides into the room the player starts in over `ZOOM_IN_SEC` (0.7 s;
  `_glide_to_player()` moves and zooms the mansion camera to where the player's will be, then hands
  over, so nothing jumps). Nothing happens during it: the game is unpaused so the countdown runs, but
  `level_is_ready` stays false, so no leak starts and the player cannot move, and `_start_playing()`
  resets the storm clock afterwards. A round left or replaced during the preview drops its countdown
  (`_preview_round`).
- **One room:** the mansion view already shows all of it, so there is no countdown and no zoom: the
  round starts at once and is played in that view.
- **The tutorial** goes straight in, in the player's view, as it always has.

Measured: level 1 -- mansion view behind the briefing, playing 51 ms after Start, no countdown, the
camera never changing; level 2 -- mansion view, countdown 5-4-3-2-1, glide, playing on the player's
camera 5.8 s after Start, no leak during it, the storm clock full.

**The board is built in slices** (`_breathe()`, called in every loop of the build: placing rooms,
finding corridors, laying walls and tiles). Built in one go, it froze the game, and the card could not
take the Start press until the build was over: about 0.13 s on level 1 and 2.2 s on level 12 on a
desktop, mostly placing rooms and searching for their corridors, and longer on a slower machine.
`_breathe()` hands the frame back once `BUILD_SLICE_US` (8 ms) of work has gone by, so input is taken
between slices, and the held card stays drawn and animated. (Level 12 now
takes about 3.5 s to build, since slices share their frames; the longest single frame left is about
130 ms, in a step not yet sliced). While a build is running, `_building` is set: a new round waits for
it to finish (two builds interleaving would share one board), and a tap on the half-built board is
ignored (`_on_pipe_pressed` checks `_board_ready`).

**The build flag is raised the moment `new_game()` stops waiting**, not when `create_board()` starts.
There are two awaited frames between the two (for the briefing card to draw), and a second
`new_game()` in them -- a quick N, a level change -- found the flag down and went on, `reset()` the board
a build was still filling, and two builds shared one board: Godot crashed on a freed tile, or read a
cell past the edge of a board of another size. `devtools/probe_storm_rebuild.gd` starts rounds at
random levels, often mid-build, and checks the board is whole; with the flag raised late it crashes.

## The camera frames the room you are in

One camera (`game_cam`) does everything. During play it frames the room the player is in, as large as
it fits: the room's tiles plus `FRAME_MARGIN` (a quarter tile) each side -- enough for the walls, which
are drawn on the room's side of the tile ring around it, 4 px of 40 -- across the screen's width, or
between the HUD strip and the button bar if the room is too tall for that, centred in that band
(`_frame_for()`). Walking into another room glides the frame over (`ROOM_GLIDE_SEC`); in a corridor it
follows the player at the zoom it had (`_follow_player_room()`). Before play it frames every room the
same way -- the mansion view, which is also the play view of a one-room level.

It used to follow the player with a fixed 14-tile-wide view: about two tiles of margin round a small
room, and a 13-wide room (room sides are 9..12 made odd, so 9, 11 or 13) did not fit with its walls.
On a phone a tile, and so a tool box, is now about 7.2-7.8 mm for a 9-wide room, 6.0-6.5 mm for 11 and
5.2-5.6 mm for 13, against 5.0-5.4 mm for all rooms before (estimated for a 6.5-7 cm-wide screen).
Measured on desktop: an 11 x 11 room spans x 15..665 of 680, y 77..727 between the HUD and the bar.

## The tool menu

A grid of boxes around the tapped tile, each box a board tile's on-screen size plus 4, sized to hold
every tool in hand plus one see-through slot: 3 x 3, 5 x 5 or 5 x 7 (`MENU_GRIDS`, taller than wide for
a portrait screen; the largest holds 34 tools, and past that the first 34 in dealt order).

**The tapped tile stays visible.** It sits under whichever slot keeps the whole menu on screen,
nearest the middle of the menu, and that slot is the see-through one. The menu moves by whole slots,
so the tile always sits squarely in one; it may cover the HUD and the button bar. It used to be
centred on the tile with its middle slot see-through and pushed back onto the screen by however many
pixels it overhung, which put a tool over the tile and the player. The tools take the slots nearest
the tapped one; the slots left over, like the see-through one, put back the tool on the tile.
Measured at level 10 (38 tools): a 5 x 7 menu of 34 tools, wholly on screen for a tile in a room's
corner, its see-through slot exactly over the tile.

## Arrows toward new leaks out of view

On a level with several rooms a leak can start anywhere while the camera shows only the player's room.
For a new leak out of view, `scripts/leak_arrows.gd` (`StormLeakArrows`, its own CanvasLayer) draws a
blue arrow near the screen's edge pointing at it: on the line from the player to the leak, where that
line meets the edge of the arrow area (`edge_point()` -- the screen inset 30 units, and clear of the
HUD strip and the button bar). It follows as the player moves, and pulses gently.

- **It goes** after the level's `arrow_ms` (1000 on every level; negative: never times out), or when
  its leak comes on screen, or when a tool is catching it.
- **One at a time.** A new leak out of view takes the arrow over: several arrows each pointing
  somewhere else would say nothing. A new leak already on screen gets none and leaves the current
  arrow alone.
- **Only a new leak.** `add_leak()` can pick a tile that is already leaking; that starts nothing and
  gets no arrow. One-room levels have no arrows at all.
- Its clock is game time, so it waits while the game is paused. Cleared at a round's end and on reset,
  hidden with the level.

Measured in a real run at level 2: an off-screen leak in the other room got an arrow whose tip sat
exactly on the arrow area's edge along the player-to-leak line, drawn blue there; taping the leak
removed it. `probe_storm_rain.gd` checks the edge geometry, one arrow at a time, removal on catching,
and the time-out.

## The inventory closes whenever something else takes over

The tool inventory is a `PopupPanel` -- a separate window drawn above everything -- so nothing that
happens around it hides it: it stayed open on top of "Oh no!", the level summary and the next round.
`level.close_inventory()` (safe with nothing open) now runs on any card (`game.sig_card_shown`, which
`GenericGameUtil` emits from `show_game_popup()`, `show_level_done_popup()` and `show_instructions()`),
at the end of a round (`level_is_done()`), on a new board (`reset()`), when the level is hidden (main
menu), when help opens (`main.gd`), and on `MainGlobals.sig_need_to_close_info_popups`.
`probe_storm_rain.gd` checks the round's end and a card both close it.

## Each card is followed by its own signal, and a round ends once

Storm shows up to three cards around a round: the level briefing at the start, the "Well done!" /
"Oh no!" card at the end, and the shared "Level N complete" card after a level's last round. They
used to report through the app-wide `MainGlobals.sig_game_popup_closed` /
`sig_level_done_popup_closed`, which fire for EVERY card, routed by an `_intro_is_open` flag. And
`level_is_done()` could run more than once per round: the HUD re-sends `sig_time_over` on every score
change once the clock is at zero, and a won round frees the board and waits a frame before its card
goes up, so a countdown tick in that frame ended the round again. The two together were the stacked
dialogs: two cards up, closing the top one started the next round, and its "Level N" briefing opened
over the card still showing.

Now:

- `level_is_done()` returns at once if `game.level_is_done` is already set, and `on_time_over()` does
  nothing before the board is ready or after the round is over.
- `GenericGameUtil.show_game_popup()` and `show_level_done_popup()` return the card, and both card
  scripts (`scripts/game_popup.gd`, `scripts/level_done_popup.gd`) emit their own `closed` before the
  app-wide signal. Storm connects the briefing's `closed` to `_on_closed_intro_popup()` and each round
  or level card's `closed` to `_on_round_card_closed()`; it no longer listens to the app-wide
  signals at all.

`probe_storm_rain.gd` checks it: three calls to end a round put up one card, another card closing
does not start the next round, and closing Storm's own card does, once.

## The ground and the camera

The Level is a `CanvasLayer` with `follow_viewport_enabled`, so everything in it moves WITH the
camera. This game's camera is parented to a moving node and PANS, so a screen-anchored ground in
that layer covers the screen once, at the start, and is then walked off the edge of — bare screen
at the sides.

The ground therefore sits in a nested `BgLayer` (`CanvasLayer`, `layer = -1`, NOT following the
viewport), which is the arrangement gorilla already used. Games whose camera is pinned to the board
centre (lightsout, taxi, wolves) do not need it and do not have it.

`probe_look.gd` fails if this game's ground goes back into the following layer.

## The lawn

The ground is ONE continuous field of drawn grass over the whole board — `scripts/grass_field.gd`,
shared by the eleven grass games — not a tile. `level.gd`'s `_fit_ground_to_board()` is the whole
installation:

```gdscript
GrassField.fit(get_node_or_null("BgLayer"), get_node_or_null("BgLayer/TextureRect") as CanvasItem, game, 19)
```

It hides the tiled `TextureRect` it replaces, attaches a `GrassField` control to `BgLayer` (a nested `CanvasLayer`, `layer = -1`, `follow_viewport_enabled`) so it
draws behind everything, sizes it to the board plus a four-tile margin (merged with the full canvas,
so a board smaller than the screen still has grass to the edges), and sows it. The seed is this
game's own — 19 — so no two games show the same field.

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
`agent_body2.png` / `agent_body3.png` — but this game never instantiates `agent_scene` at all — it is
declared in `level.gd` and used nowhere — and the player was always given an EMPTY `body_ids`, so
the build loop never ran and not one segment was ever created. Measured by running the game and counting
the nodes, not by reading it.

All of it is gone: both scripts, the `Skeleton` node in `agent.tscn` and `player.tscn`, the
`tube_animation` scene and script, and the two PNGs. `angles` keeps a single entry, the head's
heading, which is all `set_rots()` ever read.

**parkem is the one game that really does grow a body** (four segments on level 1, two on level 2),
so its rig stays. Do not copy this game's `agent.gd` there, or the reverse.

While it existed, this game's build loop called `anim.play("EnemyBody")` — an animation its
`SpriteFrames` never defined; only `"main"` was there. It never raised anything because the loop
never ran, but a single segment would have sat frozen on frame 0. storm had the identical bug.

## What this game measures

Session records are the v6 named-dictionary format (see `scripts/generic_game_util.gd`
and `scripts/session_stats.gd`). Metrics reset centrally in `reset(from_scratch)`.

Leaks appearing and leaks reaching the floor are both counted; the share that reached the floor says how well the player kept up, which the 100-point score cannot. `overflows` (the key is older than its meaning) is now counted once per leak, the first time its puddle shows (`PUDDLE_SEEN` of water on the floor). `items_ruined` counts furniture lost.

**Its counts are now metrics.** `overflows` is registered in `StatsOverview.METRICS`, lower being better. Before that this game recorded two counts that nothing could read, and had no Summary rows.

A raw count is only comparable against the same task, which is exactly what a baseline is built from — the same reasoning that already let Crack the Safe's `cycles_opened` work.


## The chooser tile

`art/game_screen_200.png` is **drawn** (`devtools/make_thumbs.py`), not grabbed. The old tile was a
screenshot of one room — a pink floor with a few small objects on it, which at 200 px says neither
"storm" nor "your things are getting wet", and whose most prominent feature was the colour pink.

It is now the weather and nothing else: cloud, slanting rain and a lightning bolt. A pail catching
the drips was drawn first, on the reasoning that weather alone is not a game — but it dragged a
second subject and a second palette into a 200 px tile and made the storm share the frame. The
chooser only has to say which game this is.

**One cloud, with an outline of its own.** It used to be a row of overlapping discs laid edge to edge
across the top, in greys a step off the night sky, and it read as a grey band. A cloud is a SHAPE: it
now stops short of the tile's sides, bulges on top and sits on a flatter base, is lit from above and
dark underneath (a vertical ramp inside the silhouette, with a rim of light along the top of each
bump), is several steps brighter than the sky, and has a soft dark edge where the two meet.

**The bolt leaves from inside the cloud.** It is drawn first and the cloud over its root: a bolt that
began in clear air below the cloud read as a sticker pasted on the sky. The underside warms slightly
where it leaves, because the light has to land on something -- kept small and faint, since a larger
flash read as a yellow stain. The rain falls from under the cloud, not from the whole sky, and a band
of it starts right at the cloud's base at ragged heights: with clear air between the two it read as
rain near a cloud rather than falling from it. Lower down it fills the tile edge to edge -- held to
0.14-0.98 across, it left a strip of dry sky down the left side only, widened by the leftward slant.
It is brighter near the flash.

`devtools/install_thumbs.py` copies it in; the published thumbnail under `docs/src/thumbs/` is
derived from it by the games-doc build and must not be written by hand.
