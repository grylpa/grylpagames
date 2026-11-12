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
first — `_start_playing()` calls `turn_lights_off()`: every target and door is hidden and the paths
dim to a cold moonlight tone (see "A garden at night"). From then on the player is navigating from memory.

That coupling is worth knowing: the first input both starts the walk *and* spends the look. The
printed instructions say "You cannot move while the lights are on", which is the same fact from the
other side.

`show_clue()` relights the board for 0.1s and costs a point.

## Winning and losing

`check_player_on_target(q)` runs as the player enters a tile and looks for a target one tile away:

- the **receiver** whose `transaction_id` matches the player's → delivered, lights on, round won
- a **bomb** → `collision`, explosion, `player.mark_hit()`

Both end the run. `mark_hit()` and `drive_into_dock()` (2026-11-12: the player walks on into the
receiver at twice its pace, fading as it crosses the mouth, instead of shrinking where it stood) end
in a callback that calls
`on_player_remove_player()`, which **frees the player** and then calls `level_is_done()`. That
delay matters — see the tutorial notes.

**Every explosion sounds.** A monster hit plays `explosion` from the start every time; it was guarded
by "if not already playing", and the explosion rings for seconds, so walking into hazards in quick
succession left the last one silent. (Detour's bonk had the same guard and lost it too.)

**No card over the game-over banner.** The player is removed a moment after the hit that cost the
last life, which ends the round (`level_is_done`); by then the HUD's "Game Over" is up. The round
still counts, but `level_is_done` returns before any round or level card when the lives are gone or
the clock has run out -- it used to open "level not passed" on top of "Game Over".

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
shared by the eleven grass games — not a tile. `level.gd`'s `_fit_ground_to_board()` is the whole
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

`probe_lawn.gd` checks all eleven: the field exists, is the first child of its layer, is sown before
any board is built, covers the board and the canvas, retires the tiled ground only once it has
something in it, and that no cell shows its own grass again.

## No snake body

This game's agents are a head and nothing else. `agent.gd` and `player.gd` used to carry the whole
trailing-body rig copied from the delivery games — `body_ids`, `bodies`, `nbody_parts`, a
`time_back_positions` trail, `find_closest_dist()`, `add_body`/`remove_body`/`final_remove_body`, a
`Skeleton` `Line2D` to string the segments on, and a `tube_animation.tscn` built from
`agent_body2.png` / `agent_body3.png` — but the level always assigned an EMPTY `body_ids`, so the
build loop never ran and not one segment was ever created. Measured by running the game and counting
the nodes, not by reading it.

All of it is gone: both scripts, the `Skeleton` node in `agent.tscn` and `player.tscn`, the
`tube_animation` scene and script, and the two PNGs. `player_animation.tscn` went with them —
a second copy of the same rig using `player_body1-3.png`, instantiated by nothing, and the last
thing referencing `tube_animation.gd`; its three PNGs are gone too. `angles` keeps a single entry, the head's
heading, which is all `set_rots()` ever read.

**parkem is the one game that really does grow a body** (four segments on level 1, two on level 2),
so its rig stays. Do not copy this game's `agent.gd` there, or the reverse.

## What this game measures

Session records are the v6 named-dictionary format (see `scripts/generic_game_util.gd`
and `scripts/session_stats.gd`). Metrics reset centrally in `reset(from_scratch)`.

Response times are handed to the shared session record as a whole distribution, not just a mean: `game.record_times()` in `main.gd::get_game_score()` stores spread, median, within-session slope and lapse count beside the mean. The spread is the point — it moves before the mean does.

## The chooser tile

`art/game_screen_200.png` (200 x 200) is **drawn** (`devtools/make_thumbs.py`, `lightsout()`), not
grabbed. The old tile was a screen grab of the lit board, every marker a few pixels.

It is now **THE LAST LANTERN** (2026-11-12): an old lantern hanging on a chain in the dark, its warm
light pooling on a few stones of a path that curves away and dissolves into the black, and the game's
blue walker standing on the near stones at the edge of the light. An icon of the game's idea -- you see
the way, then walk it in the dark -- not a scene of play, so it fits both themes (the coal mine and the
night garden). Drawn with soft layered light (`_radial`, `_halo`).

Before it, from 2026-10-30, one board with the lights going out across it on a diagonal (the lit half
holding the bomb and the blue goal, the dark half the glowing player) -- on tar roads and a day lawn the
game no longer has. Turned down on the way to the lantern: the board redrawn in each theme, crops of the
real board rendered in the game (both "super ugly", the drawn garden "nothing like the game"), a
remembered route on a dark board, a lantern lighting a patch of paths, and a firefly trail. Earlier
still: the walker with its eyes shut and the maze in a thought bubble (a dark board with a blob in the
corner at chooser size), a light switch, a light bulb with the maze in its glass.

## Sounds

`explosion` (`lightsout_boom.ogg`) is a BIG explosion: a crack, an overdriven roar sweeping down from 5 kHz, a "whoomp" of pressure, crackle, debris raining down and a rolling rumble kept in the midrange. The first was a 50-110 Hz sine under low noise (a phone played nothing); the second had the crack and the roar but no body or debris, and was "very bland".

Made for this game by `devtools/make_action_sounds.py` (synthesized, seeded; names in code kept): `motor` the ambient, a quiet night -- a slow harp ostinato in minor, a low reed, crickets (`lightsout_ambient.ogg`, `make_ambient_sounds.py`, -6 dB; it was a car engine, then a low hum the user found bad), which plays on between rounds and stops at the main menu, `feet` steps on stone (were on grass), `delivered` the lights coming on (a switch and a rising shimmer; was an arcade coin), `explosion` the explosion above (was a car crash), `start` a soft switch click.

## A garden at night (2026-11-12)

Lights Out is a WALK at night -- footsteps on stone, crickets and a harp -- and was drawn as the vehicle
games' asphalt road (markings, crown, tire tracks, concrete curbs) on their daytime lawn. It is now a
night garden (chosen over a house at night and a cave):
- **The paths are pale flagstones** (`garden_path.gdshader`, in pipe.gd): irregular slabs about half a
  tile across (`STONE` 19 px between centers -- 13 read as busy crazy paving), each its own tone in cool
  moonlight, thin LOW-CONTRAST soil joints with a little moss (the bombs, docks and doors on the path must
  stay the clearest things), in world coordinates; the tiles' art gives only the alpha, the rounded-corner
  cut is the asphalt shader's. Edged with a darker stone border (`_draw_curb`: same thin geometry, same
  joined corners). `asphalt.gdshader` is no longer used.
- **The lawn is moonlit**: the shared GrassField tinted `NIGHT_LAWN` (level `_fit_ground_to_board`; the
  things on the lawn are drawn under it and darken with it), with LawnScatter's GARDEN mode -- bushes
  and trees -- instead of the countryside's stones, ponds and houses.
- **Garden lamps** (`_place_lamps`, `GardenLamp`): about one per `LAMP_EVERY` lawn cells, on lawn cells
  beside a path, kept 4.5 cells apart; a dark lantern frame with a warm glass and an ADDITIVE pool of
  light that spills onto the path and breathes a little. They go out over half a second with the lights
  (`turn_lights_off`) and are lit at once when they come back (a clue's flash too).
- **With the lights off the stones lose their light**: the paths fade over half a second to a dim, cold
  `PATHS_DARK` and stay SOLID (`_set_path_tone`), and come back at once with the lights. They were meant
  to turn 70% see-through, but the path shader assigned its color outright and so dropped the node's
  tint: nothing showed at all. `garden_path.gdshader` now multiplies in the tint, taken in `vertex()`
  (in `fragment()` COLOR already carries the tile art's texture, road markings and all).

## The coal mine (a second look, 2026-11-12)

**The theme is the player's choice: "Theme" in the main menu** (2026-11-12), a dropdown (a list, not a
switch, though there are two so far -- more may come): `LightsoutLevelConfig.THEMES` is the list in the
menu's order (`theme_names`, `theme_index`), `LightsG.theme` the choice, saved as the third settings
value (an older save has none and gets `DEFAULT_THEME`: Random since 2026-11-12, the mine before). It takes effect with the next board;
switching back to the garden brings the lawn back and hides the rock (`_fit_ground_to_board`). Both
looks were liked; Random is the default. (The third idea, a house at night, was not built.) A new
theme is one more entry in `THEMES` and its look in level.gd, pipe.gd, empty_space.gd and the shaders.
**"Random"** is the list's third entry (`LOOK_RANDOM`, -1): every new board picks one of the real
looks (`REAL_LOOKS`) at random. So the code keeps two things apart: `LightsG.theme`, the CHOICE (saved,
shown in the menu), and `LightsG.look`, the look the current board is drawn in, settled at the start of
`create_board()` (`LightsG.settle_look`). Everything that draws reads `look`.
**A fade left running is stopped by `reset()`** (2026-11-12): the lights going off starts a half-second
fade of the paths (`_dim_tw`); opening the menu inside it paused it, and resumed after a new board was
built it darkened the NEW paths -- the board started dark, and at the countdown's end `turn_lights_off`
restarted the fade from lit: a flash of light, then dark. `reset()` kills it and relights the mine's
rock. (Reproduced by starting a new board mid-fade: the new paths came out at the dark tone with the
lights on; with the fix, at full light.)
- **Tunnel floor** (`garden_path.gdshader` `look` 1, `mine_floor`): packed earth and gravel, coal dust
  in patches, sparse small stones, falling into shadow toward each tunnel wall (`open_sides`).
- **Rock** where the lawn was (`mine_rock.gdshader` on a ColorRect over the GrassField's area, the lawn
  hidden, no lawn things): dark blocky masses with cracks, broad nearly level coal STRATA (thin wiggly
  bands read as scribbles), a rare mineral fleck. The walls' lip is a dark rock edge catching warm light
  (pipe.gd `_draw_curb`), the empty cells' rim dark rock (empty_space.gd `RIM_MINE`).
- **Lanterns** on the rock beside the tunnels (the garden lamps, `mine`): warmer and FLICKERING.
- **Lights off**: the tunnels AND the rock dim (`PATHS_DARK_MINE` 0.62, `ROCK_DARK_MINE` 0.26; the rock
  shader multiplies in its tint like the path shader), the tunnels much LESS than the rock, so they stay
  readable on a phone: with only the tunnels dimmed the rock stood brighter than them, and at 0.42 / 0.40
  the two were so close the tunnels all but vanished on a phone's screen.
- **Phone contrast** (2026-11-12, median brightness of path cells against the cells round them, WCAG):
  coal mine 2.6 lit / 2.3 dark (the floor lighter, 0.42/0.37/0.31, and the rock darker than first set;
  `PATHS_DARK_MINE` 0.86 -- at 0.62 the dark measured 1.7), night garden 2.8 / 2.3.
- **The lamps' light is one smooth radial gradient** (`GardenLamp._pool_tex`, added; 56 px, the
  mine's at 0.95 and the garden's at 0.75 -- the first gradient, at 0.50 / 0.40 over 48, was too weak):
  eight stacked circles showed as rings. And **no shadow** on a lamp: it is the light, so a shadow off to one side --
  as the other drawings have -- made no sense.

## Look (2026-10)

- Docks are beacon pads (`scripts/dock_art.gd`); a dock showing a bomb or an icon has no chevrons, and
  its content is centered on the pad. Live docks skip orange and brown.
- Bombs, the player and the hazards are `scripts/monster_art.gd`'s; doors the shared drawn gate / nail
  stubs. A door turns whenever it is tapped (2026-11-12; it used to refuse with an actor in the cell,
  `DoorGuard`). Nothing that moves reads a door here: the bombs (the "agents") stand still and the
  player is steered.
- Paths: rounded corners (`scripts/road_corners.gd`), flagstones and a stone edging (see "A garden at
  night"); the lawn at night with garden things on it (`scripts/lawn_scatter.gd`). Board:
  `init_sizes_odd()`, `buttons_height = 0`.
