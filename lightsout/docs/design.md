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
Three rounds per level (`rounds`, per level in `LightsoutLevelConfig`).

## Passing a level

A level is `rounds_per_level` rounds (`rounds` in `LightsoutLevelConfig`, read by `_apply_level()`), and it is
**passed on the share of them WON**:

```
passed = game.session_pct_correct() >= LightsoutLevelConfig.pass_pct_for(level)
```

Below the bar the SAME level is played again; at or above it, the next one. `level_is_done()`
records each round's verdict with `game.add_correct_or_mistake()` and steps `round_in_level`; when
that reaches `rounds_per_level`, `_finish_level()` judges the level and `_advance_if_needed()` —
called from `new_game()` — acts on the verdict.

Before this, **a level could not be failed, only postponed.** `round_in_level` only moved inside
`_advance_if_needed()` when `game.need_to_increase_level` had been set, and that happened on a WIN
— so a lost round did not count toward the level at all. You could lose forever and simply keep
being handed the same round.

**The percentages have to land on a rung.** A level is a fixed number of rounds, so out of 3 the
only scores that exist are 0, 33, 66 and 100. `pass_pct` is 60, which is exactly 2 of 3. Recheck it
whenever `rounds` changes.

The last level is judged the same way but never promotes.

## "complete!" only when it was

The level card is shown with the gate result as its `passed` argument, so it reads "Level N
complete!" with a check badge or **"Level N not passed"** with none. Under it, `Rounds won: 2 of 3`,
`Accuracy: 66%`, and what happens next:

- passed -> `Level passed — on to level N.`
- failed -> `You need to win at least 60% of the rounds to pass to the next level.`

Mid-level rounds keep the small "Well done!" / "Oh no!" panel, now numbered from the round that was
just played rather than from the one about to start.

`MainGlobals.global_level_is_done()` takes the gate result, so the fanfare does not play over a
level that was not passed.

## A replay starts clean

`new_game()` runs after EVERY round, so it cannot clear the level's counters unconditionally.
`_level_is_over` is set by `_finish_level()` and is what tells `_advance_if_needed()` that a LEVEL
is starting: only then does it reset `round_in_level`, `game.corrects` and `game.mistakes`.
Otherwise a retry would inherit the losses that failed the level and could not pass it even played
perfectly.

## A failed level earns nothing

`_score_at_level_start` is stamped when a level begins — in `new_game()` for the first level of a
session, in `_advance_if_needed()` for every level after it, in both cases AFTER the rollback so
consecutive failures all measure from the same point. A level that misses the gate goes back to it
(`_rollback_score_on_next_level`), applied when Continue is pressed rather than when the level ends,
because watching the score drop out from under a summary you are still reading is alarming.

Without it the gate is a scoring exploit: the score is cumulative across a session, so every failed
attempt banked its points and the retry cost nothing.

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

## The lawn

The ground is ONE continuous field of drawn grass over the whole board — `scripts/grass_field.gd`,
shared by the twelve grass games — not a tile. `level.gd`'s `_fit_ground_to_board()` is the whole
installation:

```gdscript
GrassField.fit(self, get_node_or_null("TextureRect") as CanvasItem, game, 15)
```

It hides the tiled `TextureRect` it replaces, attaches a `GrassField` control to the Level layer itself, as its first child so it
draws behind everything, sizes it to the board plus a four-tile margin (merged with the full canvas,
so a board smaller than the screen still has grass to the edges), and sows it. The seed is this
game's own — 15 — so no two games show the same field.

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
