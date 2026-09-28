# Valet (folder `guidem`) — design

"Deliver all the cars to the parking spots." Cars drive themselves out of the orange docks round the
edge of a street grid; the player never steers them. What the player controls is the **junctions**:
tapping one turns its door, and a car driving through a turned door is deflected ninety degrees.
A car that reaches a teal parking dock is parked. Two cars that meet crash.

Display name **Valet** since 2026-09-28; it was "Guidem", which the folder, the autoloads
(`GuidemG`, `GuidemLevelConfig`), the save files and the backend keys (`"Guidem"` in `BE` calls)
still carry -- renaming those would orphan players' saved scores.

## Files

```
guidem/
├── scripts/
│   ├── globals.gd        GuidemG autoload: num_packets, starting_level, the GenericGameUtil
│   ├── level_config.gd   GuidemLevelConfig: the per-level table (see below)
│   ├── main.gd           orchestrator: menu, HUD, instructions, score rows
│   ├── level.gd          board, doors, dispatch, driving (tick), parking, collisions, camera
│   ├── agent.gd          one car: head, body segments, trail
│   ├── door.gd           a junction's door (3 positions)
│   ├── target.gd         a dock: orange = where cars come from, teal = parking
│   ├── pipe.gd / empty_space.gd   a road tile / a non-road tile (draws walls against roads)
│   ├── player.gd
│   └── tutorial.gd       the coached tutorial (see main/docs/tutorials.md)
└── scenes/
```

## The board

`create_board()` in `level.gd`:

- **Roads** are every interior cell on an even row or an even column, so the board is a grid of
  streets with a road-less square between every four junctions.
- **Docks** sit on the four edges, one at every even row / column: left and top docks are all
  orange (cars start there); on the right side the docks below the middle, and on the bottom those
  right of the middle, are **teal** (`destination_type` 1, parking); the rest are orange. Each dock's
  **lobby** is the road cell just inside it.
- **Doors** go on every cell with three or more road neighbors. One in the outer two rings of
  cells, or in a corner zone, is fixed straight (`door_type` 0); the rest start at a random one of
  the three positions.

**The board size must be ODD in both directions.** With roads on the even rows and columns, an odd
size ends every side on a row of short stubs, with the docks beyond them. An even size puts the
last full road right against that side's docks -- which is what the bottom row looked like on
desktop from level 5 until 2026-09-28: the desktop screen holds 16 rows, and levels 5+ (17 and up)
were cut to 16. `_fit_board_to_screen()` now applies the level's size, lets `init_sizes()` cap it
by the screen, and if the result is even in either direction takes one off and fits again (so it
stays centered). Desktop levels 5-9 are therefore all 17x15; a phone holds 17 columns and up to
25 rows, so there the board keeps growing in height.

## Driving

`tick()` moves every car one cell per major tick. At a door it turns by the door's position
(`door_type` 1 or 2 deflect ninety degrees, left or right depending on the direction of travel);
elsewhere it goes straight, or turns where the road turns, or turns back at a dead end. A car next
to a teal dock of its own type parks (`game.dec_packet()`); when `packets_left` reaches 0 the level
is won. `check_agent_collisions()` crashes any two moving cars closer than a quarter tile.

A new car is sent out every `dispatch_ms` from a random orange dock; with a short interval
(3000 ms or less) the next dock must be more than 4 cells from the last, so two cars do not
leave side by side.

## Levels -- `level_config.gd`

Every per-level value is in `GuidemLevelConfig.LEVELS`, read through `get_level()` (past the last
level, the last level). It used to be an `if level == n:` ladder in `increase_difficulty()`, with
the board size computed beside it as `7 + 2 * level`.

| key | meaning |
|---|---|
| `board_size` | width/height before the screen caps it; odd (9, 11, ... 25) |
| `dispatch_ms` | time between two cars being sent out |
| `num_more_packets` | extra body segments on each car |
| `max_speed_scale` | each car's speed is picked from 0.8 up to this |
| `cars_to_park` | cars to park to finish the level; 200 on level 9, which does not end |
| `rounds` | 1 everywhere; not read by the game -- a level is one board |

## Scoring

A score row is `[didwin, wasaborted, level, mean time to answer]`, and the full distribution of
times goes to `game.record_times(..., "rt")`. The score list shows the level
(`progress_level_pos = 6`). Winning a level adds a life and moves to the next.

## The chooser tile

`art/game_screen_200.png` (200 x 200) is **drawn** (`devtools/make_thumbs.py`, `valet()`), not grabbed. The old tile was a screen grab of the whole board, each car a few pixels.

It is now one junction above a teal parking bay: the door there has a tap ring round it and a white
arrow points down into the bay, as the red car comes along the road to it; a yellow car follows
from the other side, since there is always more than one car to watch.

The three route games share one drawing kit in `make_thumbs.py` (`_road`, `_door`, `_dock`, `_vehicle`): the game's own head, cargo and axle sprites (`art/head2-4x.png`, `art/agent_body1.png`, `art/agent_tail1.png`) tinted to a vehicle color and joined by the dark line with its black backing, the pale green door bar, and the trapezoid docks (`art/target-no-arrow-4x.png`, `art/receiver_torquise-no-arrow-4x.png`), on `GrassField`'s lawn. No numbers: digits are text, and tiles carry none. At 200 px there is room for one junction, one or two docks and one or two vehicles, drawn big.
