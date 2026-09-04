# Parkem — design

"Don't allow the monsters to reach their goals." Creatures drive themselves around a pipe maze
toward their own parking spots. The player never steers anything — they shut **doors** at the
junctions to turn creatures aside, and win by keeping every creature from ever parking.

It is the inverse of `deliverem`, which shares the same skeleton: there you route a truck *to* its
docks, here you keep creatures *away* from their spots.

## Movement, the trail and the skeleton

The head drives itself tile to tile; the followers (packets/cars) and the tail trail behind it, and
`Skeleton` is a `Line2D` drawn through all of them. Three things here are deliberate, and undoing
any of them brings back a visible stutter.

**The trail stores raw positions.** `time_back_positions` used to store `position.round()`. Whole
pixel samples make the segment lengths alternate, so a follower reading a distance off the trail
wobbles about half a pixel every frame. At low speed that quantization was the whole of the jitter.

**`pos_back_along_trail(dist)` interpolates.** It returns the point exactly `dist` back along the
trail, interpolating inside the segment it lands in, and `null` while the trail is shorter than
`dist`. It replaced `find_closest_dist()`, which returned the *index* of the first sample at least
`dist` back; the caller parked the follower on that sample, so between index steps the sample stood
still while the head drove on and then jumped a whole sample forward -- a sawtooth as large as the
distance covered in a frame (5.5 px at speed).

**`SkeletonBK`** is a second, thicker, black `Line2D` behind `Skeleton` giving the train an outline.
It carries `res://scripts/line_backing.gd` and mirrors `Skeleton`'s points and `z_index` every
frame, so **no game code touches it**. It is the earlier sibling, which is what puts it behind at
equal `z_index`. Do not add, move or remove its points by hand: that duplicates every skeleton call
and drifts out of sync the moment one is missed.

## Files

```
parkem/
├── scripts/
│   ├── globals.gd       ParkemG autoload: num_packets, starting_level
│   ├── level_config.gd  ParkemLevelConfig: 5 levels (rounds only; difficulty is computed)
│   ├── main.gd          orchestrator, HUD wiring, scoring
│   ├── level.gd         board generation, dispatch, pathfinding, doors, hazards
│   ├── agent.gd         a creature: drives its own path, has a life timer
│   ├── door.gd          one junction door: rotation + a self-resetting timer
│   ├── target.gd        a numbered parking spot
│   └── pipe.gd / empty_space.gd   board tiles
└── scenes/  main, level, agent, player, pipe, empty_space, target, door
```

## Doors — the only control

`create_board()` places a door on every junction (a tile with more than two pipe neighbours); most
start **open**, a few start closed. `on_clicked_door()` cycles a door's rotation and — importantly
— **never back to open**: `if newdir == 0: newdir = 1`. Instead `set_rot(newdir, 4000)` arms a
timer, and `door.gd::_process` reopens it after four seconds, fading it out over the last second as
a warning.

So a door is a four-second obstacle, not a permanent wall. `on_door_type_changed()` recomputes
every creature's path when one reopens, and `on_clicked_door` does not — the creature discovers
the new door by walking into it.

## Creatures

`add_agent_at()` dispatches a creature with a `transaction_id` matching one parking spot.
`find_agent_path()` gives it a route (`calc_cost_to_move_to` is the cost function), and `tick()`
walks it one tile at a time. `agent.gd` carries `life_time_ms = 10000`.

Three ways a creature leaves the board, and only the first is bad for the player:

| what happens | `remove_agent(id, arrived)` | effect |
|---|---|---|
| reaches its spot (`mark_arrived`) | `true` | nothing — the player lost that one |
| crashes: onto a hazard cell, or into another creature (`mark_hit`) | `false` | counts for the player |
| gives up after 10s (`mark_timeout`) | `false` | counts for the player |

`on_agent_remove_agent()` turns a `false` into `game.dec_packet()`, and the level is won when
`packets_left` reaches 0.

**The quiet win is the thing to know about this game.** Keeping a creature away produces no event
at all until its ten seconds are up; a player waiting for feedback sees nothing happening and
assumes they are doing it wrong.

## Difficulty

Every per-level number lives in `parkem/scripts/level_config.gd` (`ParkemLevelConfig.LEVELS`), read
by `increase_difficulty()` through `get_level()`. It used to be a `match level:` ladder inside
`level.gd`, with a `LEVELS` array next to it that stated `rounds: 1` five times and was read by
nothing but the menu slider's range.

| key | meaning |
|-----|---------|
| `time_between_dispatches_ms` | gap between creatures being sent in |
| `num_more_packets` | extra tube segments on each creature — how LONG it is |
| `max_speed_scale` | fastest a creature may move |
| `num_bombs_to_use` | hazards placed on the board |
| `allowed_arrivals` | creatures that may reach a parking spot before the game is over |
| `level_time` | seconds the level lasts |

The board is a fixed 23x23 (less on mobile), which is not per level.

## Winning a level is surviving it

There is no quota to finish. The level runs for `level_time` seconds, and **reaching the end of the
clock IS passing it** — `on_time_over()` calls `level_is_done(true)`.

That is why `main.gd` sets `game.game_over_on_time_out = false`: with it on, the shared HUD ends
the whole SESSION at zero (`generic_game_hud.gd::check_time_run_out`), which is the opposite of
what the clock means here.

Two guards sit on `on_time_over()` and both are load-bearing:

- **`game.level_is_done`** — with `game_over_on_time_out` off, the HUD does not stop its timer; it
  re-emits `sig_time_over` on every tick while the clock sits at zero. Without the guard the level
  would end again, and again, stacking level cards.
- **`game.tutorial_mode or _tutorial_board`** — a tutorial easily outlasts a 90 s level, and a
  level-done card landing on the coach's caption is the failure mmm taught us to guard against.

## The counter at the top is an allowance

`game.packets_left` — drawn by the shared HUD's `PacketsContainer` — is how many creatures may
still reach their parking spot. It starts at the level's `allowed_arrivals` and ticks DOWN with
each one that parks; at zero, `sig_no_more_packets` reaches `main.gd::on_game_no_more_packets()`,
which stops play and calls `game.game_is_done(false, false)`. The session is over — the allowance
cannot be earned back.

Three things were wrong before, and they compounded:

1. The counter ran the other way. It counted creatures the player still had to STOP, `dec_packet()`
   on each stop, and the level was won at zero — while a creature that *parked* called
   `inc_packet()` and put the number UP. So the one event the player is trying to prevent made the
   counter look better.
2. It wore `res://art/head2-4x.png`, the shared HUD's default icon — the same picture the LIVES
   counter uses. A number counting creatures read as a number counting lives.
3. Nothing enforced the failure at all: a creature parking cost 5 points and 10 seconds, and that
   was the whole of it.

It now wears the creature's own head, taken from frame 0 of the `Enemy` animation in
`res://scenes/head_anim.tscn` (`main.gd::_creature_head_icon()`) so the icon and the sprite cannot
drift apart. Stopping a creature still pays (`delivered_one` → +10 score, +10 s) but no longer
touches the counter.

**A creature that parks during the TUTORIAL spends nothing.** The allowance is the real game's, and
spending it under the coach would end the session mid-caption.

`_creatures_stopped` counts what the player turned back in this level. It is not a quota — nothing
ends on it — but it is the first row on the level card, next to how much of the allowance the
creatures took.

## Tutorial

`parkem/scripts/tutorial.gd` (9 steps), entry `parkem/scripts/main.gd::start_tutorial()`.
See `docs/tutorials.md` for the step schema.

Three things a first-timer gets wrong, in order:

- **They play it as a delivery game.** Every sibling game is about getting something somewhere;
  here the goal is inverted and nothing on screen says so. The first caption says it outright.
- **They do not know the doors are the controls**, nor that a door is a four-second obstacle that
  reopens on its own.
- **They wait for something to happen.** Turning a creature aside is the win, and it is silent
  until the give-up timer fires.

Specific to this game:

- **Every clock in `agent.gd::_process` is the wall clock** — the 10-second give-up timer, the
  auto-start delay and the tile-to-tile interpolation. None of them stopped when the game paused,
  so a creature kept ticking through a caption and gave up and vanished while the player was still
  reading about it. That also took the parking-spot and hatch frames off the screen, because both
  are looked up FROM the creature: one bug, three symptoms. `_process` now pushes all three
  baselines forward by the paused duration. This helps the real game too — the help screen and
  popups had the same problem.
- **`tutorial_spot_pos()` requires `is_receiver`.** `add_agent_at()` stamps the creature's
  `transaction_id` on TWO targets: its parking spot, and — via `find_closest_target()` — the
  target nearest the spawn, which it marks the SENDER. Matching on the id alone returned whichever
  sat earlier in `targets`, so "that is the spot it is heading for" often pointed at where it had
  come FROM.
- **The framed hatch is one AHEAD of the creature.** Taking the first door on its path returned the
  cell the creature is standing on, so the creature covered the very thing being pointed at.
- **Almost every hatch starts open** (measured: 149 doors, ~140 open), and an open one is flat tube
  furniture rather than anything door-shaped. The captions therefore name what is inside the frame
  instead of assuming the player can see a "door".
- `_tutorial_setup()` cuts the level to **2 packets** — level 1 asks for ten creatures turned away,
  which is a long lesson.
- **`tutorial_hold_new_creatures()`** holds the dispatcher while the coach talks about the creature
  already on screen, and releases it for the final step.
- **`_tutorial_board` guards level completion, not `tutorial_mode`.** A creature is removed from a
  tween callback, so the win lands after the coach has finished and `tutorial_mode` has already
  gone false — checking that flag there is too late and the level-done popup gets through.
- **The last caption is reactive** (a `text` Callable, re-read each frame): the quiet win needs
  acknowledging the moment it happens, or the player does not learn what they just did.
- `BE.upsert_game_state` and `BE.send_event` are skipped in tutorial_mode.
- Events reported to the coach: `agent_dispatched`, `door_turned`, `creature_stopped`,
  `creature_parked` — all `game.tutorial_notify`, no-ops outside tutorial mode.
- Points for the coach, all in screen coordinates: `tutorial_creature_pos`, `tutorial_spot_pos`,
  `tutorial_next_door_pos`.

## The lawn

The ground is ONE continuous field of drawn grass over the whole board — `scripts/grass_field.gd`,
shared by the eleven grass games — not a tile. `level.gd`'s `_fit_ground_to_board()` is the whole
installation:

```gdscript
GrassField.fit(self, get_node_or_null("TextureRect") as CanvasItem, game, 16)
```

It hides the tiled `TextureRect` it replaces, attaches a `GrassField` control to the Level layer itself, as its first child so it
draws behind everything, sizes it to the board plus a four-tile margin (merged with the full canvas,
so a board smaller than the screen still has grass to the edges), and sows it. The seed is this
game's own — 16 — so no two games show the same field.

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

## What this game measures

Session records are the v6 named-dictionary format (see `scripts/generic_game_util.gd`
and `scripts/session_stats.gd`). Metrics reset centrally in `reset(from_scratch)`.

Creatures stopped against creatures parked, plus door actions.
