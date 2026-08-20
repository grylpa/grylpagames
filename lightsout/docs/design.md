# Lights Out — design

"Remember your path, goal, and obstacles." A maze of pipes, shown lit for five seconds, then the
lights go out: the markers vanish and the maze dims. You walk it from memory to your destination,
avoiding bombs.

## Files

```
lightsout/
├── scripts/
│   ├── globals.gd       LightsG autoload: num_packets, starting_level
│   ├── level_config.gd  LightsoutLevelConfig: 5 levels (board size, bomb count, dispatch rate)
│   ├── main.gd          orchestrator, HUD wiring, scoring
│   ├── level.gd         board generation, lights, walking, targets, bombs
│   ├── player.gd        the walker
│   ├── agent.gd         other movers on the board
│   ├── target.gd        a marker: sender, receiver, or bomb
│   └── door.gd / pipe.gd / empty_space.gd   board tiles
└── scenes/  main, level, player, agent, target, door, pipe, empty_space
```

## The board

`create_board()` carves a pipe maze and places `targets`. Each target is one of three kinds
(`target.gd`): a **sender**, a **receiver**, or a **bomb**. `add_player_at()` picks the closest
target as the sender and the farthest as the receiver, assigns both the same `transaction_id`, and
gives the player that id — so exactly one receiver on the board is "yours".

`add_random_static_agents()` then drops **obstacle agents** onto pipe tiles — `num_bombs` of them,
so the level config's bomb count actually governs both hazards. They are kept clear of the player
and the goal, and each is only placed if a path to the target still exists afterwards. These are a
*different* hazard from the bomb targets above: the targets are markers on the board edge, these
sit in the maze itself. `LightsoutLevelConfig` sets the count (2 at level 1, up to 11 at level 5)
and the board size (9 up to 23).

## The lights

The heart of the game. `create_board()` sets `time_to_hide` five seconds out and starts a visible
countdown. When it elapses — or **as soon as the player makes their first move**, whichever comes
first — `_start_playing()` calls `turn_lights_off()`: every target and door is hidden and the pipes
drop to 70% alpha. From then on the player is navigating from memory.

That coupling is worth knowing: the first input both starts the walk *and* spends the look. The
printed instructions say "You cannot move while the lights are on", which is the same fact from the
other side.

`show_clue()` relights the board for 0.1s and costs a point.

## Winning and losing

`check_player_on_target(q)` runs as the player enters a tile and looks for a target one tile away:

- the **receiver** whose `transaction_id` matches the player's → delivered, lights on, round won
- a **bomb** → `collision`, explosion, `player.mark_hit()`

Both end the run. `mark_hit()` and `mark_arrived()` start an animation whose callback calls
`on_player_remove_player()`, which **frees the player** and then calls `level_is_done()`. That
delay matters — see the tutorial notes.

## Scoring

+10 delivered; −1 for a bomb, a new board, a timeout, or a clue. Three lives
(`GenericGameUtil.new("Lights Out", "lightsout", 0,5,0, 3)`); a completed level adds one.
Three rounds per level (`rounds_per_level`), then the level advances.

## Tutorial

`lightsout/scripts/tutorial.gd` (8 steps), entry `lightsout/scripts/main.gd::start_tutorial()`.
See `docs/tutorials.md` for the step schema.

The lesson is the five seconds. A first-timer does not know the board is about to go dark, does not
know which of the several markers is theirs, and does not know that their first swipe is what
spends the look. So the coach holds the lights ON, names the three things worth memorizing — you,
your target, one bomb — and only then puts them out.

Specific to this game:

- **`tutorial_hold_lights`** suppresses both the 5-second auto-hide and the countdown, and makes
  `move_dir()` a no-op — a stray swipe must not spend the look while the coach is still talking.
  `tutorial_lights_out()` ends it, from the step that first mentions moving.
- **The tutorial board has no obstacle agents.** `add_random_static_agents()` returns early in
  tutorial_mode: one wandering into the player calls `player.mark_hit()` (via
  `check_agent_collisions`), which kills them over a hazard no step had taught, and strands
  whatever step was waiting for them to walk somewhere. The closing caption names them instead, so
  meeting one in a real round is not a surprise. `check_agent_collisions` is guarded too, in case
  one exists anyway.
- **A bomb does not end the lesson.** `mark_hit()` starts an animation whose callback FREES the
  player, so a step waiting on a delivery would be left waiting on something that no longer exists
  — and reviving the player cannot help, because the removal is already scheduled by then. In
  tutorial_mode the bomb keeps its bang and its lights-on and the walk continues; the caption has
  already said what it would cost for real.
- **`_tutorial_board` guards level completion, not `tutorial_mode`.** The win is reported from the
  player's arrival animation callback, which lands *after* the coach has finished and
  `tutorial_mode` has gone false — so checking that flag there is too late and the "Round 1 of
  Level 1 completed" popup gets through anyway. The flag is captured when the board is built.
- **No talking step says "swipe".** The board is frozen while a caption is up, so the instruction
  to move lives on the step that accepts it.
- **`keep_clear` radii are deliberately tight (30px).** Three small zones scattered over a full
  board already leave the caption little room; asking for generous clearance around each only
  guarantees it buries one.
- `BE.upsert_game_state` and `BE.send_event` are skipped in tutorial_mode.
- Events reported to the coach: `lights_off`, `player_moved`, `delivered`, `hit_bomb`, `clue_used`
  — all `game.tutorial_notify`, no-ops outside tutorial mode.
- Points for the coach, all in screen coordinates: `tutorial_player_pos`, `tutorial_goal_pos`,
  `tutorial_bomb_pos`.
