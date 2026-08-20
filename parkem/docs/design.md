# Parkem — design

"Don't allow the monsters to reach their goals." Creatures drive themselves around a pipe maze
toward their own parking spots. The player never steers anything — they shut **doors** at the
junctions to turn creatures aside, and win by keeping every creature from ever parking.

It is the inverse of `deliverem`, which shares the same skeleton: there you route a truck *to* its
docks, here you keep creatures *away* from their spots.

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

`increase_difficulty()`: level 1 is 10 packets, a creature every 5s, 3 hazards, speed up to 2.0×;
level 5 tightens all four. Board is a fixed 23×23.

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
