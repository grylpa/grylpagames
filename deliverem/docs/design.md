# Deliverem — design

"Remember the delivery order." A delivery truck drives itself around a pipe maze; the player never
steers it. What the player controls is the **doors** — tapping one rotates it, and a truck passing
through a rotated door is deflected ninety degrees. The whole yard is visible the whole time.

`delemfp` is the same idea played through a zoomed camera locked on the truck; this is the
full-board version. The two games share a skeleton but not a single file — each has its own copy.

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

**The board's dispatch runs from `_process`, not the `GameTick` timer.** `tick()` gates itself on
`major_tick_time_ms * time_scale`, so calling it every frame changes no cadence. On the 0.05 s
timer it did change one: a fire landing just short of the deadline (599.6 ms into a 600 ms leg)
failed the gate, and the next chance was a whole 50 ms later, so the agent finished its tile and
stood still for three frames at 60 fps before being handed the next one. That was the intermittent
jump on a straight run. Measured in delemfp: 12-13 frozen frames per 228 in bursts of 3, down to 5
in bursts of 1.

**`SkeletonBK`** is a second, thicker, black `Line2D` behind `Skeleton` giving the train an outline.
It carries `res://scripts/line_backing.gd` and mirrors `Skeleton`'s points and `z_index` every
frame, so **no game code touches it**. It is the earlier sibling, which is what puts it behind at
equal `z_index`. Do not add, move or remove its points by hand: that duplicates every skeleton call
and drifts out of sync the moment one is missed.

## Files

```
deliverem/
├── scripts/
│   ├── globals.gd        DeliveremG autoload: speed, num_packets, num_agents, starting_level
│   ├── level_config.gd   DeliveremLevelConfig: 9 levels (rounds only; difficulty is computed)
│   ├── main.gd           orchestrator, HUD wiring, scoring
│   ├── level.gd          board generation, dispatch, driving, doors, delivery
│   ├── agent.gd          the truck: head, body segments (one per packet), tail
│   ├── door.gd           one junction door: 3 rotations, emits door_pressed on click
│   ├── pipe.gd           one road tile (picks its sprite rotation from its neighbors)
│   ├── empty_space.gd    one non-road tile (draws walls against adjacent roads)
│   └── target.gd         a numbered loading dock
└── scenes/  main, level, agent, player, pipe, empty_space, target, door, game_over
```

## The board

`create_board()` builds a fresh maze each level:

- `ntargets` (7) numbered docks are placed **on the board edges**, never in a corner and never
  adjacent to another dock.
- Each dock gets a **lobby**: the road tile just inside it. Docks are not enterable — `can_go_to()`
  rejects `istarget` — so the truck delivers by passing *alongside* one.
- A loop-erased random walk from the depot to each lobby carves the road tiles, constrained to
  `q.x % 2 == 0 or q.y % 2 == 0`, which is what makes it read as a street grid.
- **Doors** are placed at junctions and are the player's only control.

## Doors — the whole game

A door has three rotations (`DoorTypes`): `open`, `backslash`, `slash`. `on_clicked_door()` cycles
it 0 → 1 → 2 → 0 and plays a sound. In `tick()`, a truck entering a tile with a rotated door has
its heading turned ninety degrees — which way depends on the rotation and on the heading it
arrived with. With no door (or an open one) the truck carries straight on, turning only at a dead
end, and reversing if it is boxed in.

So the player never issues a direction. They pre-set the maze so the truck's own momentum carries
it where they want, and they may keep changing doors while it drives.

## A round

1. `_on_agent_dispatch_timer_timeout()` dispatches a truck at the depot once `start_dispatch` is set.
2. `add_agent_at()` gives it `num_packets + num_more_packets` body segments, each labelled with a
   dock number, and announces them: **"Deliver to 3,1,5"**.
3. `tick()` moves each truck one tile per major tick, applying any door it meets.
4. Passing a dock delivers a packet **only if that dock is first in the list** —
   `remove_body_if_first()`. Wrong-order passes do nothing at all, silently.
5. When every truck is empty, `all_agents_done()` ends the level.

## Order is the lesson

The list is a queue, not a set. A player who routes to the nearest number on the list and sees
nothing happen has met the game's only real rule the hard way.

## Clue

`display_reminder()` shows what each truck still carries, in order, color-coded per truck. It
costs 2 points and 10 seconds via `_on_level_show_reminder`.

## Scoring

`game.delivered_one()` per delivered packet. Score row is
`[didwin, wasaborted, level, mean_time_to_answer_ms]`.

## Difficulty

Every per-level number lives in `deliverem/scripts/level_config.gd`
(`DeliveremLevelConfig.LEVELS`), read by `increase_difficulty()` through `get_level()`:
`board_size`, `num_more_packets`, `num_more_agents` and `rounds`. Later levels run several trucks at
once, each with its own list.

It used to be an `if level == n:` ladder in `level.gd`, and the ladder carried a bug that only an
explicit table makes obvious: it set `num_more_agents` at levels 1, 6, 7, 8 and 9 and left it alone
at 2-5, so the value CARRIED whatever it happened to be — which depended on what the player had
played before, not on the level. Every level now states its own.

## Rounds and levels

**A round is one board. A level is `rounds_per_level` of them** (`rounds` in `DeliveremLevelConfig`, 5 for every
level so far). Winning a board steps `round_in_level`; only when it reaches `rounds_per_level` does
`increase_difficulty()` bump the level and the level card appear. In between, the smaller
"Round N of Level M completed" panel shows and the next board is dealt at the SAME level.

Before this, **every won board advanced the level.** The `rounds` column in the config was dead text
— nothing read it — and the board changed under the player every single time they finished one, so
no level was ever played twice and none of them could settle into a rhythm.

Losing is unchanged: it ends the session (`game_over.emit(false)`), so every completed round is a
won one and there is nothing here for an accuracy gate to measure.

`_on_game_popup_closed()` is what continues after the between-rounds panel. It is bound to the
GLOBAL `MainGlobals.sig_game_popup_closed` — the instructions card reaches it too — so it acts only
when `game.level_is_done`, i.e. when a round is actually waiting on it.

**The tutorial is exempt**: its session is one lesson, not round 1 of 5, and it has always ended on
the level card. A "Round 1 of Level 1" panel would land on its closing caption.

## Pause

The truck's motion is a manual interpolation in `agent._process` between board tiles, against the
**wall clock**, not a Tween — so it does not stop just because the game is paused. `_process`
therefore shifts `time_set_target_pos` forward by the paused duration: the truck holds still
mid-tile while a caption, the help screen or a popup is up, and resumes without jumping.

## Tutorial

`deliverem/scripts/tutorial.gd` (11 steps), entry `deliverem/scripts/main.gd::start_tutorial()`.
See `docs/tutorials.md` for the step schema.

The lesson is entirely about the doors, so the tutorial spends its middle on one door and one turn:
a first-timer's instinct is to steer, and nothing on screen says the doors are the controls. A
player who never taps one watches the truck loop the yard until the clock runs out.

Specific to this game:

- **The truck has to be dispatched by hand.** `_on_agent_dispatch_timer_timeout()` refuses to fire
  while `game.paused()`, and a coached tutorial is paused for every caption — so left to the timer
  the truck would not appear until the first step that hands control back. `new_game()` calls
  `tutorial_dispatch_now()` instead.
- `_tutorial_setup()` cuts the yard to four docks (`ntargets = 4`), and `start_tutorial()` stashes
  and drops `DeliveremG.num_packets` to 2 — one delivery taught, one to finish.
- **`tutorial_next_dock_id()` skips `_pending_remove_ids`.** `body_ids` does not shrink until
  `final_remove_body` runs from a tween callback ~0.5s after a delivery, so reading it raw in that
  window names the dock the player has just served.
- **The trucks are held for the door lesson** (`tutorial_hold_trucks`, checked at the top of
  `tick()`). That step is an ACTION step, so the game is unpaused and the truck drives on while
  the player hunts for the door being pointed at — and since the target door is derived from the
  truck's heading, every tile it moved re-picked a door and the frame hopped around the yard. One
  cause, both symptoms. `tutorial_lock_next_door()` additionally pins the target; with the hold in
  place that is redundant (removing it still passes), and it is kept only as insurance for a
  future step that points at a door while the truck is moving.
- **`on_clicked_door()` ignores clicks while the game is paused.** A door is an `Area2D` and its
  input is not pause-gated, so a click otherwise lands during a caption, the help screen or a
  popup — and during a tutorial it would satisfy the very step still explaining what doors are.
  This helps the real game too.
- **One dock is framed, not all of them.** `tutorial_all_docks_rect()` spans practically the whole
  yard, which tells the player nothing and leaves the caption nowhere to sit clear of it;
  `tutorial_a_dock_id()` picks a single concrete example.
- `all_agents_done()` cannot end the level in tutorial_mode, and `BE.upsert_game_state` is skipped.
- The dispatch line normally auto-hides after a few seconds; in tutorial_mode main passes
  `autohide = false` so it stays while the coach reads it out.
- **The order line is registered in `runner.never_dim`.** The HUD is a CanvasLayer at 1 and the
  tutorial overlay dims from 120, so the dispatcher's line spent the whole tutorial unreadable
  except on the single step whose spotlight happened to fall on it — and part of learning the game
  is learning WHERE the order appears.
- **The order line carries the truck's own color.** `add_agent_at()` announces it AFTER
  `add_child(agent)`, because `agent.color` is assigned in the agent's `_ready()`; announcing any
  earlier sends a null color and the line falls back to the theme's fixed yellow. With several
  trucks out at once a fixed color does not say which truck an order belongs to — the clue list
  has always been color-coded this way.
- Events reported to the coach: `agent_dispatched`, `door_turned`, `packet_delivered`,
  `reminder_shown` — all `game.tutorial_notify`, no-ops outside tutorial mode.
- Points for the coach, all in screen coordinates: `tutorial_agent_pos`, `tutorial_next_door_pos`,
  `tutorial_next_dock_pos`, `tutorial_dock_pos`, `tutorial_dispatch_label`.

## The lawn

The ground is ONE continuous field of drawn grass over the whole board — `scripts/grass_field.gd`,
shared by the twelve grass games — not a tile. `level.gd`'s `_fit_ground_to_board()` is the whole
installation:

```gdscript
GrassField.fit(self, get_node_or_null("TextureRect") as CanvasItem, game, 12)
```

It hides the tiled `TextureRect` it replaces, attaches a `GrassField` control to the Level layer itself, as its first child so it
draws behind everything, sizes it to the board plus a four-tile margin (merged with the full canvas,
so a board smaller than the screen still has grass to the edges), and sows it. The seed is this
game's own — 12 — so no two games show the same field.

It is called twice: at the end of `_ready()`, so the lawn is already there before the first board is
built, and at the START of `create_board()`, for a level that changes the board's size. `fit()`
re-sows only when the rect actually changed, because the field is a `MultiMeshInstance2D` of tens to
hundreds of thousands of blades and building it is not something to redo between rounds.

Every empty cell used to carry its own 40x40 `grass.png`; `empty_space.gd`'s `_ready()` now hides it.
That per-cell sprite was the real reason the board looked tiled — the background alone was never
it — and the per-cell random rotation some of these games applied made it worse, because the tile
wraps seamlessly and turning a cell breaks the wrap.

`probe_lawn.gd` checks all twelve: the field exists, is the first child of its layer, is sown before
any board is built, covers the board and the canvas, retires the tiled ground only once it has
something in it, and that no cell shows its own grass again.
