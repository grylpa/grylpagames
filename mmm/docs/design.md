# Mind Palace (folder `mmm`) — design

You wander a castle of rooms joined by corridors, picking up one coin per room. When every room has
been visited and every coin taken, the view zooms out to the whole floor plan and you are asked,
room by room, **what color that room's floor was**. Right answers score, wrong ones cost.

The name in the chooser and in game is "Mind Palace"; the folder and `file_names_prefix` stay `mmm`,
because every scores/settings file on disk is named after that prefix.

## Files

```
mmm/scripts/
├── globals.gd       MmmG autoload: starting_level, save/load settings
├── level_config.gd  MmmLevelConfig.LEVELS — 12 levels, 3 rounds each
├── main.gd          orchestrator: menu, HUD, instructions, score rows
├── level.gd         the castle: rooms, corridors, coins, bricks, hazards, the answer popups
├── player.gd        you; continuous movement, `mark_arrived()` ends the exploring phase
├── agent.gd         the things that move in the rooms and the bombs
├── pipe.gd          one floor tile: holds `has_coin`, `has_brick`, and the room color
```

## A round

1. `create_board()` lays out `num_rooms` rooms (`create_rooms`), joins them (`add_corridors`), then
   `add_player`, `add_coins` (one per room), `add_bricks`, `add_bomb_agents`, `add_moving_agents`.
2. You walk with swipes or arrow keys — `move_dir()` sets a direction and you keep going until you
   turn or hit something, like Gorilla. Entering a tile calls `mark_visited_room()`.
3. Stepping on a coin tile takes it (`move_player_on_tick`), worth 1 or 2 depending on whether it
   sat on the room's edge.
4. When `did_visit_all_rooms() and len(coins) == 0`, the player spins away (`mark_arrived()`), which
   fires `remove_player(true)` → `on_player_remove_player()`: agents are cleared, `in_answring_mode`
   goes on, the camera zooms out, and one color-selection popup is created per room.
5. Each answer calls `answered(correct)`: +1 score / +5 s, or −1 / −5. When every room has been
   answered, `_check_if_all_rooms_answered()` ends the round a second later.

Touching a moving agent or a bomb kills the round outright: `check_agent_collisions()` →
`player.mark_hit()` → `remove_player(false)` → `level_is_done(false)`.

## Difficulty

`_apply_level()` is the whole curve: `num_rooms = 1 + level` (capped at 12), and
`num_distracting_colors = level - 1 + round_in_level` — extra colors that appear in the answer
palette but were never on any floor. So level 1 round 1 is two rooms and no decoys; by level 6 it is
seven rooms and a palette with several colors that are pure noise. Board size grows with the level
and agents speed up.

## Tutorial

`mmm/scripts/tutorial.gd`, entry `mmm/scripts/main.gd::start_tutorial()`.

The thing this game needs taught is not a control, it is a **deferred goal**: nothing on screen
while you explore says you are being tested on the floor colors, so a first-timer collects the coins
happily and is then asked a question they had no reason to prepare for. The tutorial therefore says
what the test will be *before* the first coin, and points at the floor while saying it.

Specific to this game:

- **Hazards are switched off** (`num_bomb_agents_to_add = 0`, `tutorial_no_movers`). Being killed
  mid-lesson would end the round and teach nothing.
- **The smallest possible castle**: level 1's two rooms, and `num_distracting_colors` forced to 0,
  so the palette at the end holds exactly the two colors that were actually on the floors.
- **Answering is two taps**, which is easy to miss when reading the code: the strip drawn on a room
  (`small_version`) only OPENS that room's palette; the swatch inside it, carrying `is_correct`, is
  what answers. A wrong pick costs a point and leaves the room open to try again, so
  `room_answered` is reported only for a correct one — otherwise the coach moves on while the room
  is still unnamed.
- **Single-cell spotlights frame a whole tile.** Tile positions are points, so
  `_screen_rect_for_cells(p, p)` produced a zero-size rect and the frame round the coin came out at
  20 px — smaller than the coin inside it, which reads as a rendering glitch rather than as a
  pointer. It now grows by half a tile each side (plus the step's `spot_pad`), giving 69 px against
  a 57 px tile. The tile size comes from the camera (`game.tile_size * canvas_scale`), not from
  the neighbouring tile: `add_coins()` puts some coins on a room's EDGE, where the tile to the
  right is a wall with no pipe to measure, and the frame collapsed to a fixed inset there — the
  same marker was about two tiles wide mid-room and about one on an edge.
- **A wrong pick flashes.** `_flash_wrong()` reddens and shakes the swatch that was tapped. Before
  it, the only signs were a point coming off the counter at the top of the screen and a sound —
  both easy to miss entirely, so a wrong answer looked like the game ignoring you. This applies in
  normal play too, not only in the tutorial.
- **The answer step marks nothing.** Three attempts at pointing the player at one specific room
  all failed: refusing taps on the others left dead-looking strips; hiding the other strips still
  left the ROOMS tappable, which brings their strip back. The step now frames no room and says
  "tap a room's strip, then choose the color that room's floor was" — every room is equally
  answerable, in any order, exactly as in normal play.
- **Hazards, accurately**: `add_agent_at` sets `is_moving` only when `agent_type != 0`, so bombs
  (type 0) sit still and enemies (type 1) patrol. The closing step says exactly that.
- Events reported to the coach: `coin_taken`, `room_entered`, `map_shown`, `room_answered` — all
  `game.tutorial_notify`, no-ops outside tutorial mode.
