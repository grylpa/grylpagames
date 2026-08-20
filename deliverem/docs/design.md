# Deliverem — design

"Remember the delivery order." A delivery truck drives itself around a pipe maze; the player never
steers it. What the player controls is the **doors** — tapping one rotates it, and a truck passing
through a rotated door is deflected ninety degrees. The whole yard is visible the whole time.

`delemfp` is the same idea played through a zoomed camera locked on the truck; this is the
full-board version. The two games share a skeleton but not a single file — each has its own copy.

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

`increase_difficulty()` grows the board to `7 + level*2`, and raises `num_more_packets` and
`num_more_agents` — later levels run several trucks at once, each with its own list.

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
