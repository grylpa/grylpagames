# Nudge — design

Display name **Nudge**; the folder, the autoloads (`PtbitsG`, `PtbitsLevelConfig`) and the
`file_names_prefix` stay `ptbits` — that prefix names every saved score and settings file.

Colored balls fall into a walled arena. Down each side sits a basket, one per color. You drag a
**tool** — a disc on a stick — and push each ball up and over into the basket of its own color,
dropping it in from the top. A tool only interacts with balls of ITS color; every other color passes
straight through it.

## Files

```
ptbits/scripts/
├── globals.gd        PtbitsG autoload: starting level, save/load settings
├── level_config.gd   per level: num_colors, gravity_scale, spawn_interval, rounds, ball_radius, time_sec
├── main.gd           orchestrator: menu, HUD, instructions
├── level.gd          the arena: walls, baskets, bumpers, tools, balls, dragging, scoring
├── ball.gd           a ball: speed cap
```

## How the color rule is implemented

Physics layers, not code checks. `_color_bit(color_id)` gives each color its own bit; a tool is put
on its color's layer and masks only that layer, so a mismatched ball genuinely passes through it —
there is nothing to "get wrong" at the collision level. `LAYER_OUTER` carries the walls, which every
ball collides with.

## Dragging

`_grab_at(pos)` does NOT grab the disc. Each tool has a **loop handle** `grab_offset` (44 px) below
its disc, with a grab radius of `loop_radius + 34`. Grabbing there keeps the finger off the disc and
off the ball being pushed, which matters on a phone. This is the single least discoverable thing in
the game: a player who presses the disc gets nothing and concludes the tool is not draggable.

The dragged tool is an `AnimatableBody2D` moved toward the finger at up to `TOOL_MAX_SPEED`, so it
sweeps balls rather than teleporting through them.

## A round

`_spawn_ball()` drops a ball of a random color from a band between the basket columns (so nothing
falls straight in). `_resolve_ball(ball, scored)` scores 15 plus a speed bonus, or costs up to 5 for
a ball lost out of the bottom. The level ends after `rounds` balls are resolved or `time_sec` runs
out. Levels add colors (2 → 4), raise gravity and shorten the spawn interval.

## Pause

`_update_pause_freeze()` sets `freeze` on every ball whenever `game.paused()`, so a tutorial caption
holds the arena still — balls included — rather than letting them fall while the player reads.

## Tutorial

`ptbits/scripts/tutorial.gd` (10 steps), entry `ptbits/scripts/main.gd::start_tutorial()`, level 1.

Three things need showing rather than telling:

- **Where to hold the tool.** The ring below the disc, not the disc itself — `_grab_at()` only
  accepts a press near the loop. The step spotlights the loop alone (`tutorial_tool_loop()`, a
  point, not the whole tool) and waits for a real `tool_grabbed`. Framing the whole tool here
  would point at the wrong half of it.
- **That a tool only touches its own color.** Taught by handing the player a blue ball and asking
  them to bucket it: the red tool they have been using passes straight through it.
- **The up-and-over motion.** A ball only scores if it comes in over the rim from above (the
  `armed` flag in `_process`), so the caption says so and the two doing-steps make the player
  perform it.

Specific to this game:

- Spawning is held for the whole tutorial (`tutorial_hold_spawn`) and every ball is placed by a
  step — `tutorial_spawn_ball(color)` from a `setup`, `tutorial_ensure_ball(color)` from the step's
  `tick` so a ball missed or wedged mid-lesson is quietly replaced instead of stalling the step.
- `_tutorial_setup()` also sets `rounds` to a million: `_resolve_ball` ends the level the moment
  `rounds` balls have resolved, which would drop a "Level 1 completed" popup on top of the coach.
- `new_game()` skips the pre-level popup in tutorial mode and emits `started_playing` directly.
- `tutorial_release_drag()` runs in the setups after the grab step. While the coach talks the game
  is paused and `_input` returns early, so the finger lift is never seen; without this the tool
  lurches to the last touch point when play resumes.
- Events reported to the coach: `tool_grabbed`, `ball_spawned`, `ball_scored`, `ball_missed` — all
  `game.tutorial_notify`, no-ops outside tutorial mode.
- Points for the coach, all in screen coordinates: `tutorial_tool_rect`, `tutorial_tool_loop`,
  `tutorial_basket_rect`, `tutorial_all_baskets_rect`, `tutorial_ball_pos`, `tutorial_floor_rect`.
