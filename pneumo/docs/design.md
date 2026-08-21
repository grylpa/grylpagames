# Pneumo — design

"Manage your pneumatic tubes deliveries." Capsules travel a network of tubes by themselves. Each
belongs at one particular receiver, and the player routes them there by turning **doors** at the
junctions. Two capsules that touch destroy each other.

Same skeleton as `deliverem` and `parkem`; the distinguishing rule is the collision.

## Files

```
pneumo/
├── scripts/
│   ├── globals.gd       PneumoG autoload: num_packets, starting_level
│   ├── level_config.gd  PneumoLevelConfig: 9 levels (rounds only; difficulty is computed)
│   ├── main.gd          orchestrator, HUD wiring, scoring
│   ├── level.gd         board generation, dispatch, doors, delivery, collisions
│   ├── agent.gd         a capsule: glides tile to tile, carries a transaction_id
│   ├── door.gd          one junction door: three rotations
│   ├── target.gd        a sender or receiver
│   └── pipe.gd / empty_space.gd   board tiles
└── scenes/  main, level, agent, player, pipe, empty_space, target, door
```

## Doors

`on_clicked_door()` cycles a door 0 → 1 → 2 → 0. In `tick()`, a capsule entering a tile with a
turned door has its heading rotated ninety degrees — which way depends on the rotation and on the
heading it arrived with. With no door, or an open one, the capsule carries straight on, turning at
a dead end and reversing if boxed in.

Unlike parkem's hatches these do **not** time out; a door stays as the player left it.

## Capsules

`add_agent_at()` sends a capsule with a `transaction_id`; `find_closest_target()` marks a sender,
and a receiver carrying the same id is the destination. `get_adjacent_target_id()` only returns a
match when `agent.transaction_id == target.transaction_id`, so passing any other receiver does
nothing at all.

Two outcomes:

- **Delivered** — adjacent to its own receiver: `game.dec_packet()`, and the level is won when
  `packets_left` reaches 0.
- **Collided** — `check_agent_collisions()` marks both capsules hit, plays the explosion, and two
  seconds later resets both transactions so they have to be sent again.

## Difficulty

`increase_difficulty()`: level 1 is 3 packets on an 11x11 board, one capsule every 5s, speed 1.0.
Level 9 reaches 9+ packets on a larger board with more capsules in flight at once.

## Pause

`agent.gd::_process` runs its auto-start delay and its tile-to-tile interpolation against the
**wall clock**, not a Tween — so it does not stop when the game pauses. `_process` therefore pushes
both baselines forward by the paused duration: a capsule holds still mid-tile while a caption, the
help screen or a popup is up, and resumes without jumping.

## Tutorial

`pneumo/scripts/tutorial.gd` (9 steps), entry `pneumo/scripts/main.gd::start_tutorial()`.
See `docs/tutorials.md` for the step schema.

What a first-timer gets wrong:

- **They try to steer the capsule.** It rides the tubes by itself; the doors are the only control.
- **They do not know capsules are matched.** Several receivers sit on the board and a capsule only
  counts at the one carrying its own color — passing any other does nothing.
- **They ignore the collision rule entirely**, which is the whole reason you cannot simply open
  every door and walk away. With one capsule on screen there is nothing to hint at it, so the
  tutorial states it outright near the end.

Specific to this game:

- **Capsules are frozen for the door steps** (`tutorial_freeze_capsules`). Those are ACTION steps,
  so the game is unpaused and a capsule would glide off the very door being pointed at while the
  player hunts for it. The freeze suspends the capsule's clocks too, so nothing ages while it
  waits; it is released for the delivery step.
- **`tutorial_hold_new_capsules()`** holds the dispatcher while the coach talks about the capsule
  already in the tubes — which also stops a second one colliding with it before the player has
  been told what a collision costs.
- **Frames are 1.5 tiles across, derived from `tile_size`**, with `spot_pad` zeroed: the runner
  adds its default 10px pad ON TOP of the radius, which is what turns an intended 1.5 tiles into 2.
  A larger frame swallows a cluster of junctions and stops naming one thing.
- **`_tutorial_board` guards level completion, not `tutorial_mode`**, so a win reported after the
  coach has finished cannot drop a level-done popup on the closing caption.
- The delivery step's caption is **reactive** (a `text` Callable), so a collision is named the
  moment it happens rather than in the abstract.
- `BE.upsert_game_state` and `BE.send_event` are skipped in tutorial_mode.
- Events reported to the coach: `capsule_sent`, `door_turned`, `delivered`, `capsules_collided` —
  all `game.tutorial_notify`, no-ops outside tutorial mode.
- Points for the coach, all in screen coordinates: `tutorial_capsule_pos`,
  `tutorial_receiver_pos`, `tutorial_next_door_pos`.

## Doors swing

`door.gd::set_rot()` changes `rot_idx` — which is what routes a capsule — at once, and eases only
the drawing, the same split the capsules use for their heads. It turns at the same `TURN_SPEED`
(PI/2 per 0.12 s), so a door and a capsule move at one rate.

**Only the diagonal-to-diagonal transition is animated.** The three states are open, one diagonal,
the other; open uses `$DoorOpen` and both diagonals use `$DoorDiag` at rotation 0 or PI/2. Swinging
between the two diagonals is the same flap moving, so it is worth animating; arriving from open
swaps to a different sprite, where rotating would read as a glitch rather than as a movement.

## Turning

The capsule's head is drawn from `_head_angle`, which chases the logical heading rather than
matching it. `angles[0]` stays the heading everything else derives from — the body segments trail
off it — and is re-derived every frame from the direction of travel; at a corner that flips between
one frame and the next, and a head drawn straight off it snapped round in a single frame (measured:
188 rad/s, the whole turn in one frame).

`_ease_head_angle()` moves the drawn angle at a **constant** `TURN_SPEED` of PI/2 per 0.12 s — the
same swing taxi gets from its 0.12 s tween, so the two games look alike. Constant rate rather than
a proportional ease, because a proportional one takes a share of the remaining angle per frame and
so takes the whole turn at once when a frame runs long; this one cannot exceed its rate whatever
the frame time. Always the short way round (`wrapf(diff, -PI, PI)`), so a right turn from "up" does
not unwind three quarters of a circle.

Two details that were wrong first time:

- **Ease every frame, not only while the body is sliding.** Called from inside the movement branch,
  a heading change while the capsule was at rest still snapped.
- **The first heading of a capsule's life is not a turn.** `_head_angle_set` seeds the drawn angle
  outright the first time it is known, in `set_rot()` as well as on the first eased frame — otherwise it swings into place in full view as it
  appears.
