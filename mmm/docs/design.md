# Mind Palace (folder `mmm`) — design

You wander a castle of rooms joined by corridors, picking up one coin per room. When every room has
been visited and every coin taken, the view zooms out to the whole floor plan and you are asked,
room by room, **what color that room's floor was**. Right answers score, wrong ones cost.

The name in the chooser and in game is "Mind Palace"; the folder and `file_names_prefix` stay `mmm`,
because every scores/settings file on disk is named after that prefix.

## Bomb art

Bombs use the `Bomb` animation in the shared `scenes/head_anim.tscn`, which mmm, lightsout, storm,
wolves and gorilla all draw from — a change here shows up in all of them.

The art is `art/bomb_crackle.png`, 12 frames of 128x128 generated from `bomb1-vig-4x.png`. It is
deliberately **grayscale**, because each game tints it (`modulate = Color(0.5, 0, 0)` for target
bombs), so the fuse can only be told apart from the ball by brightness and shape, never by hue.

The original art read as "a worm coming out of a ball": the cord was a fat, evenly wide tube that
was actually *brighter* (peak 247) than the flame blob on its end (143), and the only part the
three frames animated was a large, dim, round puff detached to the upper right. The replacement
drops the puff, redraws the cord as a tapered fuse that is dimmer than the flame, and puts a
necked, flickering teardrop flame with crackle sparks at the cord's real tip.

Everything is contoured. The ball carries a near-black outline all the way round (10..40
luminance on its edge) so it reads on light and dark backgrounds alike, and the fuse, the flame
and the sparks are outlined to match — about 2 px, against the ball's 4-6 px, since they are much
thinner shapes. The fuse stops at the dome rather than being drawn into it, so its two side
outlines meet the ball's own contour instead of cutting a channel through the bright dome. Sparks
sitting right at the top edge of the frame are the one place the ring cannot close (about three
pixels per frame).

The frame is fixed at 128x128 and every game positions the sprite by that footprint, so the only
way to make the fuse and flame read at play size was to give them more of the frame: the ball is
scaled to 84% and sat on the bottom, which takes the headroom above it from 38% of the ball's
height to 66%. The sprite's footprint is unchanged, so nothing moves in any game.

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

- **The step that sends the player to the second room marks nothing.** The other room is off camera
  (the view is zoomed to the player), so a marker on it lands off screen. Marking the corridor mouth
  instead was tried and reverted: the doorway is often not visible either, so a marker floating at
  the edge of the room is more confusing than the plain instruction to follow the corridor.
- **The tutorial answers BOTH rooms.** The round is not over until every room has been named, so
  stopping after one would leave the player having seen most of a process rather than all of it.
  The caption keeps clear of the room still to be answered — the whole ROOM, not just its color
  strip: with the rooms stacked vertically, dodging the strip alone put the caption straight onto
  its room, 67% of it covered, and the player could not see which room was being asked about. Only
  while `in_answring_mode`, and only once ONE room is left — while several are open the player can
  start with whichever they can see, and a full-width caption cannot clear two rooms at once.
- **No end-of-round panel.** Two guards, because one is not enough. `level_is_done()` returns early
  in tutorial_mode — every branch of it ends in a popup ("Level 1 completed", "Well done!", "Oh
  no!"). But `_check_if_all_rooms_answered()` schedules that call with `do_after(1)`, and a second
  later the player has usually tapped through the closing caption, the tutorial has ended and
  tutorial_mode is false again — so the guard inside sees nothing to suppress and the panel appears
  anyway. The flag is therefore also captured at SCHEDULE time, while the tutorial is still up.
  Scoring and level progression are suppressed in tutorial mode regardless.
- **Nothing on the floor is marked.** Markers here are screen-space rects over a camera-followed
  world, so anything captured at the wrong instant is off screen and anything recomputed every
  instant wanders after the player. The rule that works: pin the first value that lands on screen,
  then hold it — and only use a marker where the thing is reliably in view. Only two things are ever
  marked: the player on the movement step, and the coin in the first room. Floor markers were tried
  in both rooms and removed — a marker on the tile underfoot reads as the "this is you" frame
  shrinking, one beside the player points at nothing being asked for, and the floor being discussed
  is the whole room anyway.
- **The tutorial castle is empty apart from the coins.** No bombs, no enemies, no bricks. Note that
  `num_bomb_agents_to_add = 0` is NOT enough on its own: `add_bomb_agents()` divides by it and only
  checks "have I placed enough?" AFTER placing one, so a count of zero is a division by zero on a
  path that can still leave a bomb. The function returns early instead.
  There are three places an agent could come from: `add_bomb_agents()` and `add_moving_agents()`
  at board build, both guarded, and `_on_agent_dispatch_timer_timeout()` during play — which cannot
  fire here, because `start_dispatch` is never set true in this game (only ever false). No guard is
  needed there, and adding one would imply a path that does not exist.
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
