# Delem FP — design

"Deliver packets in order while zoomed in." A delivery truck drives itself around a pipe maze; the
player only chooses which way it turns, and after the first few seconds they are looking through a
zoomed-in camera that follows the truck, so the route has to come from memory.

FP = first person: the zoomed camera is the whole point of the game. `deliverem` is the same idea
played on the full board.

## Files

```
delemfp/
├── scripts/
│   ├── globals.gd        DelemfpG autoload: speed, num_packets, starting_level, freeze
│   ├── level_config.gd   DelemfpLevelConfig: 9 levels (rounds only; difficulty is computed)
│   ├── main.gd           orchestrator, HUD wiring, scoring
│   ├── level.gd          board generation, dispatch, driving, delivery, camera
│   ├── agent.gd          the truck: head, body segments (one per packet), tail
│   ├── player.gd         the depot the truck is dispatched from
│   ├── pipe.gd           one road tile (picks its own sprite rotation from its neighbours)
│   ├── empty_space.gd    one non-road tile (draws walls against adjacent roads)
│   ├── door.gd / target.gd  numbered loading docks
└── scenes/  main, level, agent, player, pipe, empty_space, target, door, game_over
```

## The board

`create_board()` builds a fresh maze each level:

- `ntargets` (7) numbered docks are placed **on the board edges**, walking round the four walls,
  never in a corner and never adjacent to another dock.
- Each dock gets a **lobby**: the road tile just inside it. Docks are not enterable — `can_go_to()`
  rejects `istarget` — so the truck delivers by pulling up *next to* one.
- A random walk (loop-erased, `stack`) from the depot to each lobby carves the road tiles. Cells
  are constrained to `q.x % 2 == 0 or q.y % 2 == 0`, which is what makes it read as a street grid
  rather than a blob.
- Every non-road cell becomes an `empty_space`, and a border of empties is padded around the board
  so the zoomed camera never shows the void past the edge.

Board size is `7 + level*2` square, so level 1 is 9×9 and level 9 is 25×25.

## A round

1. `_on_agent_dispatch_timer_timeout()` dispatches a truck at the depot once `start_dispatch` is set.
2. `add_agent_at()` gives it `num_packets + num_more_packets` body segments, each labelled with a
   dock number (a shuffled subset of 1..ntargets), and announces them: **"Deliver to 3,1,5"**.
3. A 5-second countdown runs (`global_start_countdown(5)`) — the board is fully visible and the
   truck is frozen. **This is the memorization window.**
4. `create_camera()` attaches a 2× smoothed `Camera2D` to the truck and clears `DelemfpG.freeze`.
   From here the player sees only the truck's surroundings, and can steer.
5. `tick()` (driven by main's game-tick timer) moves the truck one tile per major tick. The player's
   `move_dir()` sets `next_agent_dir`, which is used **if the road allows it**; otherwise the truck
   keeps its heading, and at a dead end it turns to whichever side is open.
6. Passing a dock delivers a packet **only if that dock is first in the list** —
   `remove_body_if_first()`. Wrong-order passes do nothing at all, silently.
7. When every packet is delivered, `all_agents_done()` ends the level.

## Order is the lesson

The list is a queue, not a set. A player who drives to the nearest dock number on their list and
sees nothing happen has met the game's only real rule the hard way. Everything else — the maze, the
zoom, the memory load — is pressure on top of it.

## The two costed helpers

Both charge **-2 score and -10 seconds**, which is what makes them a decision rather than a habit:

- **Clue / reminder** (`display_reminder()`): shows the packets still aboard, in order.
- **Zoom out** (`zoom_unzoom()`): drops back to the whole board for 4 seconds. The truck is frozen
  while it is out (`DelemfpG.freeze = true`), so it is a look, not a free move.

`halt_or_resume()` ("stop") pauses the truck outright, uncosted — a keyboard convenience.

## Scoring

`game.delivered_one()` on each delivered packet. Score row is
`[didwin, wasaborted, level, mean_time_to_answer_ms]`; the mean is over rounds where the truck was
emptied, capped to the last 20.

## Difficulty

Every per-level number lives in `delemfp/scripts/level_config.gd` (`DelemfpLevelConfig.LEVELS`),
read by `increase_difficulty()` through `get_level()`: `board_size`, `num_more_packets` and
`rounds`. Level 1 carries the settings-chosen `num_packets` (3 by default) and level 8+ carries 7
more on top, on a board that grows from 9 to 25 tiles.

Those were two formulas in `level.gd` (`7 + level * 2` and `max(0, min(7, level - 1))`). A formula
is fine until one level needs to be different, and then it cannot be — the table can.

## Rounds and levels

**A round is one board. A level is `rounds_per_level` of them** (`rounds` in `DelemfpLevelConfig`, 5 for every
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

The truck's motion is a manual interpolation in `agent._process` between board tiles, not a Tween,
so it does not stop just because the rest of the game is paused. `_process` therefore shifts
`time_set_target_pos` forward by the paused duration: the truck holds still mid-tile while a
caption, the help screen or a popup is up, and resumes without jumping when play continues.

## Tutorial

`delemfp/scripts/tutorial.gd` (13 steps), entry `delemfp/scripts/main.gd::start_tutorial()`. See
`docs/tutorials.md` for the step schema.

The shape of it: **the coach walks the real dispatch sequence, one beat at a time.** Whole map and
delivery order visible → five-second countdown → zoom onto the truck → steer. Nothing about that
order is invented; it is what `add_agent_at()` does, slowed down so each beat can be explained.

Two earlier designs were wrong and are recorded here so they are not tried again:

- **Do not teach steering before the zoom.** Zoomed out, `DelemfpG.freeze` is true and the truck
  cannot be steered at all — that is the game's rule, and its printed instructions say so ("You
  cannot move while zoomed out"). A tutorial that drove on the open board would demonstrate a state
  the game does not have and contradict its own instructions.
- **Do not skip the countdown.** Holding it back leaves an unexplained freeze between the map and
  the zoom, which a first-timer reads as the game not responding. The countdown is now *shown* and
  named, and the caption says outright that you cannot move until it reaches zero.

Specific to this game:

- **The countdown is frozen while it is explained.** The HUD's `_on_countdown_timer_timeout()`
  skips a tick whenever `game.paused()`, and a talking step pauses the game — so the step whose
  `setup` calls `tutorial_start_countdown()` leaves a 5 sitting on screen, pointed at, until the
  player taps. It then runs on the following (non-blocking) step.
- **The camera follows the VISIBLE countdown, not `MainGlobals.sig_global_countdown_finished`.**
  Two HUDs listen to the global countdown: this game's, and the spare `GenericGameHUD` in the app
  root (`scenes/main.tscn`). The root's has no `game` reference, so its
  `if game and game.paused(): return` guard never fires and it keeps counting in real time under a
  caption — reaching zero, and emitting the finished signal, while the visible countdown is still
  frozen at 5. That zoomed the camera in mid-caption and left the truck driving with the countdown
  still ticking on screen. `_tutorial_watch_countdown()` polls the visible label instead, which the
  HUD hides exactly at zero. `time_to_start_camera` is no use either: it is a wall-clock comparison
  in `_process` and is equally unaware of the pause.
- **The two bottom-bar steps demonstrate themselves after 20s.** Zoom and Clue are the only steps
  that depend on a control OUTSIDE the game's own scene (the app's `BottomOptionButtons`), which is
  the one thing a game's tutorial cannot fully account for — a player reported being unable to get
  past "Lost?", and it could not be reproduced here (the button advances the step both immediately
  and after the hint appears, with the overlay correctly set to MOUSE_FILTER_IGNORE). A tutorial
  step must never be a dead end regardless of cause, so each carries a `tick` that performs the
  action itself once `tutorial_step_elapsed_sec()` passes 20 — the player still sees what the
  button does, and the run continues. Their `setup` calls `tutorial_mark_step()` to start that
  clock.
- **The truck is parked (`tutorial_hold_truck(true)`) from the zoom until the delivery step.** The
  Zoom and Clue steps wait on a button press, so the game is UNPAUSED and the truck would drive off
  on its own — and if it rolled past the right dock it would deliver a packet no step was waiting
  for. The runner holds one pending event, so a delivery spent there is one the last step waits for
  forever: the tutorial simply stops. `halt` is the game's own mechanism for this.
- **The truck has to be dispatched by hand.** `_on_agent_dispatch_timer_timeout()` refuses to fire
  while `game.paused()`, and a coached tutorial is paused for every caption — so left to the timer
  the truck would not appear until the first step that hands control back, four captions after the
  coach starts pointing at it. `new_game()` calls `tutorial_dispatch_now()` instead.
- **`tutorial_next_dock_id()` and `tutorial_packets_left()` both skip `_pending_remove_ids`.** `body_ids` does not shrink when a
  packet is delivered: `remove_body()` starts a shrink tween and the id is only dropped in
  `final_remove_body`, ~0.5s later. In that window the raw list still holds the packet just handed
  over — which made the coach say "one down, 2 to go" on a two-packet run, and send the player back
  to the dock they had just served.
- `_tutorial_setup()` cuts the yard to four docks (`ntargets = 4`) so the maze can be read in one
  look, and `start_tutorial()` stashes and drops `DelemfpG.num_packets` to 2 — one delivery taught
  with help offered, one to finish.
- `all_agents_done()` cannot end the level in tutorial_mode: a "Level 1 completed" popup landing
  over the coach is the failure mmm taught us to guard against.
- `BE.upsert_game_state` and `BE.send_event` are skipped in tutorial_mode. A lesson is not a round.
- The dispatch line ("Deliver to 3,1") normally auto-hides after a few seconds; in tutorial_mode
  main passes `autohide = false` so it stays while the coach reads it out, and the following step's
  setup takes it down (`tutorial_hide_dispatch()`) — the HUD refuses to show a reminder while it
  is up.
- **The steering instruction lives on the step that RELEASES the truck**, not on the one that
  parks it. It was on "Now you drive", the talking step whose setup calls
  `tutorial_hold_truck(true)` — so the player read "swipe, or use the arrow keys", swiped, got
  nothing, and stayed stuck through the next two steps until something else released the truck.
  That step is now "The view closes in" and says the truck is parked for a moment.
- **A zoom-out must be ended before asking for steering.** `zoom_unzoom()` holds
  `DelemfpG.freeze` true for a 4-second look, and movement is refused while zoomed out by design.
  The delivery step can arrive inside that window, so its setup calls `tutorial_end_zoom_out()`
  rather than racing the coroutine.
- **No step before the zoom may read as an instruction to move.** The truck is frozen until the
  countdown ends, so "go to dock 4" asks for something the player cannot do. That step now says to
  trace the route in their head and states outright that the truck is locked.
- **The "dock first" caption is deliberately one short line.** The truck always sits at the depot
  (340, 260) and the dock is random; when the dock lands directly below it there is only a ~170px
  gap, and a taller caption cannot avoid burying one or the other.
- Events reported to the coach: `agent_dispatched`, `steered`, `zoomed_in`, `packet_delivered`,
  `passed_dock`, `reminder_shown`, `unzoomed` — all `game.tutorial_notify`, no-ops outside
  tutorial mode.
- Points for the coach, all in screen coordinates: `tutorial_agent_pos`, `tutorial_next_dock_pos`,
  `tutorial_all_docks_rect`, `tutorial_dispatch_label`, `tutorial_countdown_label`,
  `tutorial_bottom_button`.

## The truck and its packets

The truck is a head, one body sprite per packet still on board, and a tail. The head drives; the
packets and the tail follow it along a recorded trail, `time_back_positions`, which gets one sample
per frame while the truck is moving.

`pos_back_along_trail(dist)` returns the point exactly `dist` back along that trail, interpolating
inside whichever segment it lands in, and returns `null` while the trail is still shorter than
`dist`.

**Two things about it are deliberate, and getting either wrong brings back a visible jitter.**

- It interpolates rather than returning the nearest recorded sample. The old version returned the
  index of the first sample at least `dist` back and the caller parked the packet on that sample.
  Between index steps the sample is fixed while the truck drives on, so the packet slid backwards
  and then jumped a whole sample forward when the index stepped — a sawtooth as large as the
  distance covered per frame (5.5 px at speed).
- The trail stores raw positions, not `position.round()`. Rounding the samples to whole pixels
  makes the segment lengths alternate, so a packet reading a distance off the trail wobbles about
  half a pixel every frame no matter how well the lookup interpolates. At low speeds that
  quantization *was* the whole of the jitter, which is why it showed up most on the first packets.

Measured on a straight run: snapping to samples gave 0.8 px of wobble at 1.4 px/frame and 5.5 px at
5.5 px/frame; interpolating alone cut the fast case to 1.0 px but left the slow case untouched;
interpolating on an unrounded trail gives zero on both.

**The board's dispatch runs from `_process`, not the `GameTick` timer.** `tick()` gates itself on
`major_tick_time_ms * time_scale`, so calling it every frame changes no cadence. On the 0.05 s
timer it did change one: a fire landing just short of the deadline (599.6 ms into a 600 ms leg)
failed the gate, and the next chance was a whole 50 ms later, so the agent finished its tile and
stood still for three frames at 60 fps before being handed the next one. That was the intermittent
jump on a straight run. Measured in delemfp: 12-13 frozen frames per 228 in bursts of 3, down to 5
in bursts of 1.

**`set_target_pos()` also backdates the clock** by however late the dispatch was, capped at
`MAX_LEG_CATCHUP_MS` (17 ms, one frame). Without it `dt` starts at 0 and the first frame of every
tile advances nothing. That took delemfp from 5 frozen frames per 220 to 2.

The cap is the whole point. An earlier attempt used 50 ms, which is harmless when the dispatch is
merely a frame late but wrong when the agent legitimately finished early and was *waiting* for the
next tick: it then injected the full 50 ms of travel into a single frame, about 7 px, and every
tile visibly jumped. Only delemfp carries the backdating -- it measured no benefit in deliverem,
and guidem/parkem/pneumo could not be measured because agents teleporting on spawn swamp the
signal.

## The skeleton and its backing line

`Skeleton` is a `Line2D` whose points are the head, each packet and the tail. `SkeletonBK` is a
second, thicker, black `Line2D` sitting behind it to give the whole train an outline.

`SkeletonBK` carries `res://scripts/line_backing.gd` and simply mirrors `Skeleton.points` each
frame, so **no game code touches it**. It is an earlier sibling of `Skeleton`, which is what puts
it behind at the same `z_index`, and it copies at a raised `process_priority` so it is never a
frame stale. Do not add, move or remove its points by hand — that duplicates every skeleton call
and drifts out of sync the moment one is missed.

## Turning

The truck's head is drawn from `_head_angle`, which chases the logical heading rather than
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
  a heading change while the truck was at rest still snapped.
- **The first heading of a truck's life is not a turn, and it is not `angles[0]` either.**
  `angles[0]` stays 0 (east) until the truck has actually moved, so seeding the drawn angle from it
  left a truck that is dispatched facing DOWN pointing right for its first moment and then swinging
  round. `set_pos()` seeds it from the dispatch `direction` instead — the level always dispatches
  with direction 1.
- **The old note, kept because the mistake is easy to repeat:** `_head_angle_set` seeds the drawn angle
  outright the first time it is known (from the first eased frame, since the truck's heading only exists once it moves) — otherwise it swings into place in full view as it
  appears.
