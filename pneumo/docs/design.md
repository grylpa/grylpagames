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

## Capsule head

`scenes/agent.tscn` carries its own `SpriteFrames` named `HeadEyes` — pneumo does **not** use the
shared `scenes/head_anim.tscn`. The art is `art/agent_head_slot.png`, a 24-frame sheet of 30x25
cells generated from the original `agent_head1/2/3.png`.

The picture is a white capsule with a black line across it (the line is black, not a hole in the
sprite). The line is placed as if it were painted on a cylinder turning about its long axis: its
position follows `sin(theta)` and how squarely it faces us follows `cos(theta)`, so it sweeps
across, fades as it reaches the silhouette, and passes round the back. Two lines sit 180 degrees
apart, so as one rolls off an edge the other is already fading in on the far edge — the roll never
jumps and never reverses.

**The line is snapped to a whole row.** Placing it at sub-pixel positions and spreading one row's
worth of darkness across two rows by coverage looks correct on paper but flickers: the peak
darkness rises and falls frame to frame, so the line appears to change thickness. Snapping keeps
it exactly one pixel thick in every frame; the roll still reads as smooth because the *fade* is
what varies continuously, not the geometry.
Because the two lines are half a turn apart, **half** a turn already returns the capsule to the
same picture, so the 24 frames span `theta` from 0 to PI. A full turn would repeat every frame
twice and roll at double speed.

The extremes (rows 6 and 18) and the cycle length are the ones the original three frames had:
`speed = 40` against the `speed_scale = 0.5` that `agent.gd` sets gives one traverse per 1.2 s,
the same cadence as the old 3-frame version, but at 20 fps instead of 2.5.

**The bounce flip depends on this.** When a capsule reverses, `start_bounce()` turns the sprite
180 degrees, which would throw the line to the mirrored row — a jump exactly when the player is
watching. Frame `i` sits at angle `PI*i/n`, and the mirrored configuration is angle `-i`, so
`agent.gd` steps to `posmod(-frame, n)`. That formula is derived from this frame layout: change
the layout and the flip has to be re-derived.

## Colors and transaction ids

**Palette index 10 is never handed out here.** `#004d33`, deep yellowish green, measures
rgb(0.00,0.30,0.20) against this game's own background at rgb(0.00,0.32,0.11) -- a distance of 0.17
when the next nearest palette color is 0.88 away, so a capsule wearing it nearly vanishes.
`main.gd` sets `game.skip_color_idxs = [10]` and `GenericGameUtil.next_color()` steps over it,
leaving 12 colors.

Colors are comfortably sufficient: measured at level 9, the peak was **5 concurrent transactions**
against 13 colors, and no frame ever had two live receivers wearing the same color. Worth knowing
if dispatch rates are ever raised, though: level 9 has 48 targets, so up to 24 concurrent
transactions is possible in principle, which would exceed the palette.

**Transaction ids come from a counter that only ever goes up, and is deliberately not reset between
levels.** They used to be drawn from a shuffled pool of `ntargets` ids cycled by index, so an id
could in principle be live twice at once -- and `reset_sender_receiver(id)` clears EVERY target
holding that id, two seconds after a delivery. A capsule still in flight could then have its
receiver wiped by an unrelated delivery, after which the freed target was picked up by the next
transaction and changed color mid-flight. Note this is a *reasoned* mechanism, not one that has
been reproduced: a headless run at level 9 issued only 10 ids from a pool of 48, so the cursor
never wrapped. The counter is kept because a unique id cannot alias whatever the cause turns out to
be, and it removes at its root the crash that came from a stale cursor indexing a shorter pool
after level 9 then level 1.

## The capsule train

A capsule is a head plus one tube per packet it carries (five at level 9), with `Skeleton` drawn
through them. The tubes come from `scenes/tube_animation.tscn`.

**Z order — everything here is RELATIVE.** A child's effective z is the agent's plus its own, and
the agent sits at `Z_IN_GATE` 90 / `Z_ON_BOARD` 110, so a child written as `z_index - i - 1` came
out at 179, not 89. Measured effective values, which are the ones that matter:

| | effective z |
|---|---|
| `Skeleton` | 70 |
| tubes | 89, 88, 87, 86, 85 |
| head | 91 (from the scene's `z_index = 1`) |
| dispatcher | 100 |

The head keeps the 1 the scene gives it — that is what holds it under the dispatchers. `Skeleton`
is a flat `-20` (it used to be `z_index - 10`, effective 170, drawing over the head *and* the
dispatchers) and tube *i* is `-(i+1)` (it used to be `z_index - i - 1`, effective 179, drawing over
the dispatchers). Setting the head to `z_index` instead is wrong: it lands at 180 and the whole
train covers the dispatchers.

**The bounce squashes `$Head` along the head's OWN axis.** `scale` is applied in the head's
rotated frame and the head faces the way it is going, so its local +x is the direction of travel:
compress local x, bulge local y, and the squash lines up with the impact whichever way the tube
runs. Picking the axis from `_bounce_axis` -- a WORLD vector -- and applying it to a rotated child
was wrong, because at 90 degrees local x is world y, so the compression came out across the tube
instead of along it. Measured: 382 of 435 squash frames compressed the wrong world axis; now 0.

**It squashes `$Head`, never the agent.** `scale` on the agent scales every child's
*position* too, and the tubes are placed at offsets read off the trail -- so on each impact the
whole train telescoped in towards the head. Measured with five packets: 170 px of train collapsing
to about 21 px. An empty capsule looked fine, which is why it only showed up with packets.

**The tubes use the same 24-frame rolling animation as the head** (`art/agent_body_slot.png`),
staggered a third of a cycle apart with `((i+2) % 3) * 8`; a third of 24 frames is 8, which is what
the old `(i+2)%3` did over 3.

**The trail.** `time_back_positions` stores raw (unrounded) positions, and
`pos_back_along_trail(dist)` returns the point exactly `dist` back, interpolating inside the
segment it lands in. **It measures from the head's live `position`, not from the newest
recorded sample.** A sample is only appended when the tile target changes, so on the frames in
between the newest sample is stale and every follower lands at the wrong offset, snapping back
the next frame: the lead tube's gap was breathing between 33.5 and 34.0 px while the head
advanced smoothly. Anchored to the head it holds 34.0 exactly. `back_total_len` is only advanced when a sample is actually appended.

**`next_transaction_id_idx` is reset wherever `transaction_ids` is rebuilt.** The list is rebuilt
per level from `ntargets`; a cursor left at the previous level's position indexes past the end of a
shorter list, which crashed `add_agent_at()` on playing level 9 and then level 1.

**The dispatch stays on the `GameTick` timer.** Unlike delemfp and deliverem, `tick()` here does
**not** gate itself on `major_tick_time_ms` -- the check at the top is commented out -- so calling
it every frame runs the whole body three times as often and makes the capsules jerky even on
level 1. Do not move it to `_process` without restoring that gate first.

## Known, measured, unfixed

Measured at level 9 with five packets over ~1400 frames: the lead tube still steps backwards
**twice**, by up to 0.67 px (it was 6 times at up to 1.02 px before the lookup was anchored to the
head). The head never does. Whether the two that remain are genuine bounce reversals rather than
jitter is not settled.

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
the drawing, the same split the capsules use for their heads.

**The swing is deliberately much faster than the capsules' `TURN_SPEED`:** PI/2 per 0.035 s, about
two frames, against the heads' 0.12 s. It used to match the heads, which made it the odd one out,
because only one of the three taps animates at all — see below. Worse, it lagged its own logic: a
tap routes capsules the new way immediately, so a 0.12 s swing left a window where the door sent a
capsule one way while still drawn pointing the other. Measured at 60 fps: 133 ms then, 50 ms now,
against 0 ms for the other two taps.

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
