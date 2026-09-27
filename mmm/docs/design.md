# Mind Palace (folder `mmm`) — design

You wander a castle of rooms joined by corridors, picking up one coin per room. When every room has
been visited and every coin taken, the view zooms out to the whole floor plan and you are asked,
room by room, **what color that room's floor was**. Right answers score, wrong ones cost.

The name in the chooser and in game is "Mind Palace"; the folder and `file_names_prefix` stay `mmm`,
because every scores/settings file on disk is named after that prefix.

## Bomb art

Bombs use the `Bomb` animation in the shared `scenes/head_anim.tscn`, which mmm, lightsout, storm,
wolves and gorilla all draw from — a change here shows up in all of them.

The art is `art/bomb_crackle.png`, 12 frames of 128x128 generated from `bomb1-vig-4x.png`. It is
deliberately **grayscale**, because each game tints it (`modulate = Color(0.5, 0, 0)` for target
bombs), so the fuse can only be told apart from the ball by brightness and shape, never by hue.

The original art read as "a worm coming out of a ball": the cord was a fat, evenly wide tube that
was actually *brighter* (peak 247) than the flame blob on its end (143), and the only part the
three frames animated was a large, dim, round puff detached to the upper right. The replacement
drops the puff, redraws the cord as a tapered fuse that is dimmer than the flame, and puts a
necked, flickering teardrop flame with crackle sparks at the cord's real tip.

Everything is contoured. The ball carries a near-black outline all the way round (10..40
luminance on its edge) so it reads on light and dark backgrounds alike, and the fuse, the flame
and the sparks are outlined to match — about 2 px, against the ball's 4-6 px, since they are much
thinner shapes. The fuse stops at the dome rather than being drawn into it, so its two side
outlines meet the ball's own contour instead of cutting a channel through the bright dome. Sparks
sitting right at the top edge of the frame are the one place the ring cannot close (about three
pixels per frame).

The frame is fixed at 128x128 and every game positions the sprite by that footprint, so the only
way to make the fuse and flame read at play size was to give them more of the frame: the ball is
scaled to 84% and sat on the bottom, which takes the headroom above it from 38% of the ball's
height to 66%. The sprite's footprint is unchanged, so nothing moves in any game.

## Files

```
mmm/scripts/
├── globals.gd       MmmG autoload: starting_level, save/load settings
├── level_config.gd  MmmLevelConfig.LEVELS — 12 levels, 3 rounds each
├── main.gd          orchestrator: menu, HUD, instructions, score rows
├── level.gd         the castle: rooms, corridors, coins, bricks, hazards, the answer popups
├── player.gd        you; continuous movement, `mark_arrived()` ends the exploring phase
├── agent.gd         the things that move in the rooms and the bombs
├── pipe.gd          one floor tile: holds `has_coin`, `has_brick`, and the room color
```

## A round

1. The level's briefing goes up at once, held, and `create_board()` builds the castle behind it (see
   "The briefing and the build"): `num_rooms` rooms (`create_rooms`), joined (`add_corridors`), then
   `add_player`, `add_coins` (one per room), `add_bricks`, `add_bomb_agents`, `add_moving_agents`.
   The round starts when the card's Start is pressed (`_begin_round()`).
2. You walk with swipes or arrow keys — `move_dir()` sets a direction and you keep going until you
   turn or hit something, like Gorilla. Entering a tile calls `mark_visited_room()`.
3. Stepping on a coin tile takes it (`move_player_on_tick`), worth 1 or 2 depending on whether it
   sat on the room's edge.
4. When `did_visit_all_rooms() and len(coins) == 0`, the player spins away (`mark_arrived()`), which
   fires `remove_player(true)` → `on_player_remove_player()`: agents are cleared, `in_answring_mode`
   goes on, the camera zooms out, and one color-selection popup is created per room.
5. Each answer calls `answered(correct)`: +1 score / +5 s, or −1 / −5. When every room has been
   answered, `_check_if_all_rooms_answered()` ends the round a second later.

Touching a moving agent or a bomb kills the round outright: `check_agent_collisions()` →
`player.mark_hit()` → `remove_player(false)` → `level_is_done(false)`.

The speed bonus (`min(5, 60 - seconds)` score and time) is paid only for a round that was WON. It
used to be applied before the win/lose branch, so a round lost after ten seconds paid the same as
one won in ten seconds.

## Difficulty

`_apply_level()` is the whole curve: `num_rooms = 1 + level` (capped at 12), and
`num_distracting_colors = level - 1 + round_in_level` — extra colors that appear in the answer
palette but were never on any floor. So level 1 round 1 is two rooms and no decoys; by level 6 it is
seven rooms and a palette with several colors that are pure noise. Board size grows with the level
and agents speed up.

`num_distracting_colors` rises with `round_in_level`, and `round_in_level` now counts LOST rounds
too (see below) — so a level the player is struggling with gets harder round by round rather than
holding still.

## Passing a level

A level is `rounds_per_level` rounds (`rounds` in `MmmLevelConfig`, read by `_apply_level()`), and
it is **passed on the share of them that were FULLY CORRECT** — the round survived AND every room
named right first try:

```
passed = 100 * _rounds_fully_correct / _rounds_played >= MmmLevelConfig.pass_pct_for(level)
```

One wrong pick in `answered()` sets `_round_had_wrong_answer` and spoils the round for the gate. The
round can still be finished — the palette stays open and the player tries again — it just no longer
counts toward the level.

**The gate has its own counters on purpose.** Every other gated game reads
`game.session_pct_correct()`, but here `game.corrects` / `game.mistakes` already count ROOM ANSWERS
and the HUD shows them (`hud.show_corrects_mistakes()`). Putting round verdicts in the same pair
would mix two different units in one number and make the counter on screen wrong.

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
complete!" with a check badge or **"Level N not passed"** with none. Under it, `Rounds fully right: 2 of 3`,
`Accuracy: 66%`, and what happens next:

- passed -> `Level passed — on to level N.`
- failed -> `You need at least 60% of the rounds fully right to pass to the next level.`

Mid-level rounds keep the small "Well done!" / "Oh no!" panel, now numbered from the round that was
just played rather than from the one about to start.

`MainGlobals.global_level_is_done()` takes the gate result, so the fanfare does not play over a
level that was not passed.

**Each card is followed through its own `closed` signal** (`level_is_done`, `_finish_level`), not
the app-wide `sig_game_popup_closed` / `sig_level_done_popup_closed`, which fire for ANY card. With
a briefing card at the start of every round, those would have ended the round the moment Start was
pressed -- the bug Storm had first.

## The briefing and the build

The same mechanism as Storm's, copied into `level.gd` (games do not share scripts).

- **The card goes up at once, held.** `new_game()` shows the level's briefing and holds it
  (`game_popup.hold()`): it reads only "Building world", with no Start button, and nothing closes it.
  It is laid out at its final size, the real text already in it and hidden. When the board is ready
  and the card has been up at least `BRIEF_HOLD_MS` (1 s), `_release_brief()` puts in the real text
  (`_brief_text()`: how many rooms, with the count the board actually got, what to do, and the level's
  rounds) and shows Start. The round -- its clock, `level_is_ready`, the start sound -- begins when
  the card closes (`_begin_round()`). The tutorial has no card and starts as soon as its board is built.
- **The background stays opaque while held**, unlike Storm's, where the build is watched: every
  room's floor color is the question at the end of the round, and the whole castle drawn behind a dim
  card would show them all.
- It replaced a yellow "Building board" label (`BuildingLabel`, now removed with its style) after
  which the round started at once.
- **The board is built in slices.** `_breathe()` in every loop of the build hands the frame back after
  `BUILD_SLICE_US` (14 ms), so the card stays drawn. Built in one go, level 12 froze the game for
  3.5-4.5 s; it now takes about 1.5 s, without freezing (measured in a window).
- **The build flag is raised the moment `new_game()` stops waiting** for the last build, so two builds
  can never share one board (Storm crashed on exactly that when the flag was raised late).
- **The corridor search is a faster copy of the shared one**, finding exactly the same paths
  (`_corridor_astar()` and `_corridor_reachable()`, as in Storm: the cost inline, packed arrays for
  the states, a byte mask of built tiles, and a flood under looser rules that skips a search that
  could not succeed). Measured in Storm: the search 2x faster, and most of the hopeless searches skipped.
- **A corridor's tiles are listed in walking order** (`_try_corridor_L()`, Storm's fix). A straight
  run going up or left was listed low to high, and the door put one step back from its first two
  tiles could land off the board -- a crash Storm showed about one build in five.

`devtools/probe_mmm_build.gd` checks all of it: rounds at random levels often mid-build leave a whole
board, the fast search matches the shared one on every query, corridors are in walking order, and the
briefing holds, releases after the build and a second, starts the round on close, and does not end it.
`level.probe_real_round` lets it do that in tutorial mode (which is what keeps a probe from writing
scores) with the real levels and the real card, which tutorial mode otherwise swaps for the lesson's.

## A replay starts clean

`new_game()` runs after EVERY round, so it cannot clear the level's counters unconditionally.
`_level_is_over` is set by `_finish_level()` and is what tells `_advance_if_needed()` that a LEVEL
is starting: only then does it reset `round_in_level` and the round tally (`_rounds_played`,
`_rounds_fully_correct`, `_round_had_wrong_answer`). Otherwise a retry would inherit the rounds that
failed the level and could not pass it even played perfectly.

`game.corrects` / `game.mistakes` are deliberately left alone — they are the session's room answers,
not the level's rounds.

## A failed level earns nothing

`_score_at_level_start` is stamped when a level begins — in `new_game()` for the first level of a
session, in `_advance_if_needed()` for every level after it, in both cases AFTER the rollback so
consecutive failures all measure from the same point. A level that misses the gate goes back to it
(`_rollback_score_on_next_level`), applied when Continue is pressed rather than when the level ends,
because watching the score drop out from under a summary you are still reading is alarming.

Without it the gate is a scoring exploit: the score is cumulative across a session, so every failed
attempt banked its points and the retry cost nothing.

## Tutorial

`mmm/scripts/tutorial.gd`, entry `mmm/scripts/main.gd::start_tutorial()`.

The thing this game needs taught is not a control, it is a **deferred goal**: nothing on screen
while you explore says you are being tested on the floor colors, so a first-timer collects the coins
happily and is then asked a question they had no reason to prepare for. The tutorial therefore says
what the test will be *before* the first coin, and points at the floor while saying it.

Specific to this game:

- **The step that sends the player to the second room marks nothing.** The other room is off camera
  (the view is zoomed to the player), so a marker on it lands off screen. Marking the corridor mouth
  instead was tried and reverted: the doorway is often not visible either, so a marker floating at
  the edge of the room is more confusing than the plain instruction to follow the corridor.
- **The tutorial answers BOTH rooms.** The round is not over until every room has been named, so
  stopping after one would leave the player having seen most of a process rather than all of it.
  The caption keeps clear of the room still to be answered — the whole ROOM, not just its color
  strip: with the rooms stacked vertically, dodging the strip alone put the caption straight onto
  its room, 67% of it covered, and the player could not see which room was being asked about. Only
  while `in_answring_mode`, and only once ONE room is left — while several are open the player can
  start with whichever they can see, and a full-width caption cannot clear two rooms at once.
- **No end-of-round panel.** Two guards, because one is not enough. `level_is_done()` returns early
  in tutorial_mode — every branch of it ends in a popup ("Level 1 completed", "Well done!", "Oh
  no!"). But `_check_if_all_rooms_answered()` schedules that call with `do_after(1)`, and a second
  later the player has usually tapped through the closing caption, the tutorial has ended and
  tutorial_mode is false again — so the guard inside sees nothing to suppress and the panel appears
  anyway. The flag is therefore also captured at SCHEDULE time, while the tutorial is still up.
  Scoring and level progression are suppressed in tutorial mode regardless.
- **Nothing on the floor is marked.** Markers here are screen-space rects over a camera-followed
  world, so anything captured at the wrong instant is off screen and anything recomputed every
  instant wanders after the player. The rule that works: pin the first value that lands on screen,
  then hold it — and only use a marker where the thing is reliably in view. Only two things are ever
  marked: the player on the movement step, and the coin in the first room. Floor markers were tried
  in both rooms and removed — a marker on the tile underfoot reads as the "this is you" frame
  shrinking, one beside the player points at nothing being asked for, and the floor being discussed
  is the whole room anyway.
- **The tutorial castle is empty apart from the coins.** No bombs, no enemies, no bricks. Note that
  `num_bomb_agents_to_add = 0` is NOT enough on its own: `add_bomb_agents()` divides by it and only
  checks "have I placed enough?" AFTER placing one, so a count of zero is a division by zero on a
  path that can still leave a bomb. The function returns early instead.
  There are three places an agent could come from: `add_bomb_agents()` and `add_moving_agents()`
  at board build, both guarded, and `_on_agent_dispatch_timer_timeout()` during play — which cannot
  fire here, because `start_dispatch` is never set true in this game (only ever false). No guard is
  needed there, and adding one would imply a path that does not exist.
- **Hazards are switched off** (`num_bomb_agents_to_add = 0`, `tutorial_no_movers`). Being killed
  mid-lesson would end the round and teach nothing.
- **The smallest possible castle**: level 1's two rooms, and `num_distracting_colors` forced to 0,
  so the palette at the end holds exactly the two colors that were actually on the floors.
- **Answering is two taps**, which is easy to miss when reading the code: the strip drawn on a room
  (`small_version`) only OPENS that room's palette; the swatch inside it, carrying `is_correct`, is
  what answers. A wrong pick costs a point and leaves the room open to try again, so
  `room_answered` is reported only for a correct one — otherwise the coach moves on while the room
  is still unnamed.
- **Single-cell spotlights frame a whole tile.** Tile positions are points, so
  `_screen_rect_for_cells(p, p)` produced a zero-size rect and the frame round the coin came out at
  20 px — smaller than the coin inside it, which reads as a rendering glitch rather than as a
  pointer. It now grows by half a tile each side (plus the step's `spot_pad`), giving 69 px against
  a 57 px tile. The tile size comes from the camera (`game.tile_size * canvas_scale`), not from
  the neighboring tile: `add_coins()` puts some coins on a room's EDGE, where the tile to the
  right is a wall with no pipe to measure, and the frame collapsed to a fixed inset there — the
  same marker was about two tiles wide mid-room and about one on an edge.
- **A wrong pick flashes.** `_flash_wrong()` reddens and shakes the swatch that was tapped. Before
  it, the only signs were a point coming off the counter at the top of the screen and a sound —
  both easy to miss entirely, so a wrong answer looked like the game ignoring you. This applies in
  normal play too, not only in the tutorial.
- **The answer step marks nothing.** Three attempts at pointing the player at one specific room
  all failed: refusing taps on the others left dead-looking strips; hiding the other strips still
  left the ROOMS tappable, which brings their strip back. The step now frames no room and says
  "tap a room's strip, then choose the color that room's floor was" — every room is equally
  answerable, in any order, exactly as in normal play.
- **Hazards, accurately**: `add_agent_at` sets `is_moving` only when `agent_type != 0`, so bombs
  (type 0) sit still and enemies (type 1) patrol. The closing step says exactly that.
- Events reported to the coach: `coin_taken`, `room_entered`, `map_shown`, `room_answered` — all
  `game.tutorial_notify`, no-ops outside tutorial mode.

## The ground and the camera

The Level is a `CanvasLayer` with `follow_viewport_enabled`, so everything in it moves WITH the
camera. This game's camera is parented to a moving node and PANS, so a screen-anchored ground in
that layer covers the screen once, at the start, and is then walked off the edge of — bare screen
at the sides.

The ground therefore sits in a nested `BgLayer` (`CanvasLayer`, `layer = -1`) — the arrangement
gorilla already used. That layer DOES follow the viewport, because what is in it is no longer a
screen-sized texture but a board-sized lawn (see "The lawn" below): a ground that covers the board
has to be drawn in the board's space, or it appears at the wrong scale the moment the camera zooms.
storm, delemfp and gorilla are the same. Games whose Level layer does not follow the camera at all
(deliverem, guidem, lightsout, parkem, pneumo, pop, taxi, wolves) have no BgLayer and put the lawn
straight into the Level layer.

`probe_look.gd` fails if a BgLayer goes missing, is empty, or stops following a camera its Level
follows.

**The camera frames the room you are in** (copied from Storm), **at one zoom for the whole round.**
One camera (`game_cam`): during play it centers the player's room at the zoom that fits the castle's
LARGEST room -- its tiles plus `FRAME_MARGIN` (a quarter tile) a side, across the screen's width, or
between the HUD strip and the button bar if it is taller than that (`_play_zoom`,
`_largest_room_zoom()`, `_frame_for()`). Each room at its own largest zoom was tried first and moved
too much: with rooms of 5 to 11 tiles the zoom changed by up to 2x between rooms. Walking into another room glides the frame over (`ROOM_GLIDE_SEC`); in a
corridor it follows the player at the zoom it had (`_follow_player_room()`, run after the player each
frame: `process_priority = 1`). Stepping into a corridor clears the framed room, so the next room
walked into is framed afresh even when it is the one just left: the frame used to be redone only for
a DIFFERENT room, and walking out into a corridor and back left the view where the corridor had taken
it -- on level 12 the player walked off the top of the screen. `probe_mmm_build` walks that route and
checks the player is on screen, and that every room gets the same zoom. For the answers the camera
frames the whole castle, as large as it fits.
It replaced a camera parented to the player at ONE zoom for every room, sized for the widest room
the game can make plus two tiles -- so a 5-wide room took up half the screen's width. Measured: a
7 x 9 room fills the band from y 78 to 726 of 788 (at its own zoom, before the zoom was fixed).

**The answers' view frames the corridors too** (`_castle_rect()`, as in Storm): the rooms' outline
grown by `CORRIDOR_REACH` (3), the reach the corridor search is confined to, kept to the board. It
framed the rooms alone, and in 10 of 12 builds some corridor ran up to 3 tiles outside and was cut off
(`probe_mmm_build`, framing the rooms alone: 50 of 596 tiles).

**A bit faster in a corridor** (`_set_player_pace()`, `CORRIDOR_RUN` 2): a corridor holds no coin and
asks nothing. Each step into a corridor tile is taken at twice the walking speed, and in a corridor
the next step is taken the frame the player arrives rather than at the next game tick (`_process()`).
Measured at 60 fps: 145 ms a corridor tile against 236 in a room, about 1.6x. (Storm runs at 3x.)

**No room wider than 11 on a phone** (`_room_side()`, `MOBILE_MAX_ROOM_SIDE`, as in Storm): a room's
side sets the tile size, and 13 would give about 5.4 mm tiles. mmm's range, 5..10 made odd, tops out
at 11 already; the cap keeps it so if the range grows.

**Twelve rooms fit where Storm's nine did** on the same 75 x 75 board at level 12 (6 builds of 6 got
all 12): mmm's rooms are 5, 7, 9 or 11 tiles a side, Storm's 9, 11 or 13 -- about half the area.

## The lawn

The ground is ONE continuous field of drawn grass over the whole board — `scripts/grass_field.gd`,
shared by the eleven grass games — not a tile. `level.gd`'s `_fit_ground_to_board()` is the whole
installation:

```gdscript
GrassField.fit(get_node_or_null("BgLayer"), get_node_or_null("BgLayer/TextureRect") as CanvasItem, game, 7)
```

It hides the tiled `TextureRect` it replaces, attaches a `GrassField` control to `BgLayer` (a nested `CanvasLayer`, `layer = -1`, `follow_viewport_enabled`) so it
draws behind everything, sizes it to the board plus a four-tile margin (merged with the full canvas,
so a board smaller than the screen still has grass to the edges), and sows it. The seed is this
game's own — 7 — so no two games show the same field.

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
`tube_animation` scene and script, and the two PNGs. `angles` keeps a single entry, the head's
heading, which is all `set_rots()` ever read.

**parkem is the one game that really does grow a body** (four segments on level 1, two on level 2),
so its rig stays. Do not copy this game's `agent.gd` there, or the reverse.

While it existed, this game's build loop called `anim.play("EnemyBody")` — an animation its
`SpriteFrames` never defined; only `"main"` was there. It never raised anything because the loop
never ran, but a single segment would have sat frozen on frame 0. storm had the identical bug.

## What this game measures

Session records are the v6 named-dictionary format (see `scripts/generic_game_util.gd`
and `scripts/session_stats.gd`). Metrics reset centrally in `reset(from_scratch)`.

Response times are handed to the shared session record as a whole distribution, not just a mean: `game.record_times()` in `main.gd::get_game_score()` stores spread, median, within-session slope and lapse count beside the mean. The spread is the point — it moves before the mean does.

## The chooser tile

`art/game_screen_200.png` is **drawn** (`devtools/make_thumbs.py`, `mmm()`), not grabbed. The old
tile was the castle as a floor plan: flat colored boxes joined by gray lines on a flat green that
was not even the game's current lawn. Accurate, and it read as a diagram.

It is now a palace: four towers at dusk, each in one of the room colors from the game's palette
(`GenericGameUtil.colors`: red, blue, yellow, cyan, picked to be far apart), which is what a round
asks you to remember. Each tower is shaded as a round one lit from the left, with a crenellated
parapet, faint stone courses, a cone roof in a deeper shade of its own color (the red one has none),
and a warm light in some windows; the tallest, in front, has a door and a pennant, and the one
furthest back is hazed toward the sky. They stand on the lawn every grass game now has
(`GrassField`'s ground and blade colors). The grass and the towers are drawn in depth order: a blade
rooted above a tower's foot is behind it, one rooted below is in front. All the grass used to go on
last, so every tower wore the same fringe at its foot however far away it stood. Checked at chooser
size: it still reads as four colored towers.
