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

`increase_difficulty()` bumps the level, grows the board to `7 + level*2`, and raises
`num_more_packets` to `min(7, level-1)` — so level 1 carries the settings-chosen `num_packets`
(3 by default) and level 8+ carries 7 more on top.

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
