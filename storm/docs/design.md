# Storm — Game Design

## Concept

A time-pressure management game. A storm is battering your old house and the roof is leaking. You must protect your belongings by placing containers and duct tape under leaks, emptying filled containers at drains, and preventing water from overflowing onto the floor.

## The drawn path

The path the player drags is the shared `PathOverlay/PathLine` in `scenes/main.tscn`. Its own color
is a fixed orange, which disappeared over the warmer room floors.

The line also fades fast here: `storm/scripts/main.gd` sets `MainGlobals.path_fade_sec = 0.18`
against the 0.6 default. The path is laid out in SCREEN space, and storm's camera follows the
player, so the board slides out from under the line the moment the finger lifts and it stops
describing the route that was asked for. It is a confirmation of the gesture, not a marker.
Measured: gone 200 ms after release, against 617 ms at the default. Wolves keeps the default
deliberately -- it always uses the whole-board camera, never scrolls, so its line stays meaningful.

`storm/scripts/level.gd::path_color_at(bp)` reports what color a board cell is -- a room floor is
painted `color_by_index(room_id).lightened(0.5)` in `pipe.gd`, so the path is told exactly that --
and `main.gd` registers it as `MainGlobals.path_color_probe` when the level is shown. The overlay
then gives the line a `Gradient` whose stops are black or white, whichever the cell underneath is
further from by Rec.709 luma. Games that set no probe keep the plain orange, and the chooser clears
the probe on every game switch so one game's cannot leak into the next.

Measured, and worth knowing before changing the palette: every one of the 13 room colors comes out
light after `.lightened(0.5)` (luma 0.62 to 1.00), so today the ink is dark on all of them. Cells
with no room fall back to light, which is right for both things the path can cross -- the marble
corridor tile is luma 0.79 and the brick walls 0.40 to 0.58, and dark ink reads on all of it. The
per-cell machinery only starts doing visible work if a genuinely dark floor is ever introduced.

## Corridor floor

The corridor tile is the `PipeImageNoDir` sprite in `scenes/pipe.tscn`, shown by `pipe.gd` for a
cell with no directional pipe art. It uses the shared `res://art/marble_tile.png`, the same light
marble mind palace uses, rather than `art/pipe_no_dir.png`.

Only four games have this node at all -- mmm, storm, gorilla and wolves. The other ten games with a
`pipe.tscn` have no corridor floor: their pipe is a directional tube or road.

## Game Flow

1. An intro popup describes the round (room count, storm duration)
2. The storm starts: leaks appear periodically on random room tiles
3. The player walks to leaks, selects a tool from the action panel, and places it
4. Tools fill with water over time; when full, water starts overflowing the tile
5. The player carries full tools to a drain to empty them
6. Round ends when the storm passes (120-second timer)
7. Round fails when too many tiles have overflowed (score hits 0)
8. 3 rounds complete a level; completing a level advances to the next

## Controls

- Click/tap a leak (when close) → action panel opens; select a tool or pick up a filled one
- Click/tap a drain (when close) → select a tool to empty
- F / L: faster / slower game speed
- N: new game
- M: main menu

## Scoring

- **initial_score = 100** per game session (carries across rounds and levels)
- **−val** when a tile overflows (`_on_pipe_leak_overflow`; `val` = furniture value or 1)
- **−1** when a tool's container fills up (`action_full` flag in `pipe.gd`)
- **+2** when a tool is placed on a leak
- **+5** when a tool is emptied at a drain
- **+1/+5** for correct / **−1/−5** for incorrect answers (via `answered()`)
- **End-of-round bonus**: `min(5, 60 − elapsed_seconds)` score and time (can be negative for slow rounds)
- Score is clamped at 0 (never goes negative)

## Score Saving

`score_was_changed` is set when `add_score_and_time` is called with `is_actual_score=true` (the default). The countdown timer passes `is_actual_score=false` so mere time-passing does not count as "having played." A score is only saved if the player actually placed a tool or had an overflow.

## Levels

12 levels defined in `StormLevelConfig.LEVELS`, each with 3 rounds. Difficulty (room count, leak rate, etc.) increases with level. The game loops silently at the last level.

## Tools

Tools are defined as `CAction` objects with a `name`, `id`, `level` (current fill), and `overflow_level`. At game start only `bucket` is available; higher levels unlock more tool types (rag, cup, plate, fix). Each tool type has a different `overflow_level` controlling how quickly it fills.

## Pipes (Leaks)

- `pipe.gd` handles per-tile water logic
- `water_level` (0→1): how full the tile floor is; hits 1.0 → `sig_leak_overflow` → score penalty
- `action_level` (0→overflow_level): how full the placed tool is
- When `action_level >= overflow_level`: tool is full, `action_full = true`, −1 score penalty fired once; water then starts filling the tile
- `set_action()` resets `action_full` so placing a new tool or draining clears the state

## Drains

Drain tiles are special pipes (`is_drain = true`). When a filled tool is placed on a drain, `action_level` is reset to 0 each frame — the container empties. The player gets +5 for a successful drain.

## Rooms & Board

- Board divided into rectangular rooms connected by corridors
- Player is a walking character that must be close to a leak or drain to interact
- Furniture (flower, screen, rug) placed in rooms adds visual variety and raises the overflow penalty for that tile

## Save Files

Uses standard `GenericGameUtil` with prefix `storm`:
- `settings_v5_{key}_storm.gpa` — `[starting_level]`
- `scores_v5_{key}_storm.gpa` — score rows: `[unixtime, score, time_left_sec, times_run, didwin, wasaborted, level]`
- `ongoing_score_v5_{key}_storm.gpa`

## Scene / Script Structure

```
storm/
├── art/           (graphics only)
├── docs/
│   └── design.md
├── scenes/
│   ├── main.tscn
│   ├── level.tscn
│   ├── pipe.tscn
│   ├── empty_space.tscn
│   ├── agent.tscn
│   ├── player.tscn
│   ├── door.tscn
│   └── action_panel.tscn
└── scripts/
    ├── globals.gd         (StormG autoload)
    ├── main.gd            (orchestrator)
    ├── level.gd           (core gameplay, board, rooms, leaks)
    ├── level_config.gd    (StormLevelConfig — 12 levels)
    ├── pipe.gd            (per-tile water logic, overflow detection)
    ├── agent.gd
    ├── player.gd
    └── hud.gd
```

## Tutorial

Coached tutorial in `storm/scripts/tutorial.gd`; see `docs/tutorials.md` for the framework.

- **Entry**: as for the other games; `StormG.starting_level` is saved/restored by hand.
- **Hooks in `level.gd`** (no-ops outside tutorial mode): `_on_path_drawn` emits `path_drawn`;
  `add_leak` emits `leak_started`; `create_actions_popup` emits `tapped_too_far` when the tap is
  out of reach; placing a tool emits `tool_placed`.
- `tapped_too_far` exists because tapping a leak you are not standing next to does *nothing* — no
  message, no sound. That silence is the most confusing thing in the game, and the hook lets the
  coach explain it at the moment it happens rather than in the abstract.
- **`demo_path`**: the tutorial animates a pointing hand tracing a route from the player, the same as
  wolves, so the drawn-path gesture is shown rather than described.
- **Drawn-path movement**: storm and wolves are the only two games where
  `MainGlobals.draw_path_mode` is on, so nothing a player has learned elsewhere suggests it. It is
  taught early and the player has to draw one, because reaching a leak in time is the whole game.
- The tutorial also states outright that the score starts at 100 and only falls — a number counting
  down with no explanation reads as a bug or a timer.
- The level's intro popup is skipped in tutorial mode.

## The level intro

The briefing is the shared card (`GenericGameUtil.show_game_popup` -> `scripts/result_card.gd`),
the same one every other game uses, on its BRIEFING tone (cool header, "Start" on the button). It
replaced `show_text_popup` / `PopupText`, a fixed-size yellow panel that sized itself to its text
and so needed every line hand-wrapped with `\n`.

Two things follow from that and both matter when editing the text:

- **Prose is written as sentences.** The card wraps it. Hand-broken lines now come out as separate
  centered fragments.
- **A fact is written `Label: value`** and is set as a table row, label left and value right, with
  a hairline between adjacent facts. So the facts are grouped together, not scattered between the
  prose lines, or they end up as separate one-row tables.

Play still starts when the card closes, now via `MainGlobals.sig_game_popup_closed` (connected
once, guarded with `is_connected`) instead of the popup instance's own `closed` signal.

## One signal, two popups

Storm shows the shared game popup TWICE per round: the level briefing at the start, and the
"Well done!" / "Oh no!" card at the end. Both report through the same global
`MainGlobals.sig_game_popup_closed`, so a second handler connected for the briefing runs when the
ROUND-RESULT card closes too — and `_on_game_popup_closed` emits `sig_level_is_done`, so closing
the briefing ended the round it was introducing.

`_intro_is_open` routes it: `_on_game_popup_closed` starts the round if the flag is set and ends it
otherwise. Any future popup this game adds has to extend that routing, not add a connection.

## The ground and the camera

The Level is a `CanvasLayer` with `follow_viewport_enabled`, so everything in it moves WITH the
camera. This game's camera is parented to a moving node and PANS, so a screen-anchored ground in
that layer covers the screen once, at the start, and is then walked off the edge of — bare screen
at the sides.

The ground therefore sits in a nested `BgLayer` (`CanvasLayer`, `layer = -1`, NOT following the
viewport), which is the arrangement gorilla already used. Games whose camera is pinned to the board
centre (lightsout, taxi, wolves) do not need it and do not have it.

`probe_look.gd` fails if this game's ground goes back into the following layer.

## The lawn

The ground is ONE continuous field of drawn grass over the whole board — `scripts/grass_field.gd`,
shared by the eleven grass games — not a tile. `level.gd`'s `_fit_ground_to_board()` is the whole
installation:

```gdscript
GrassField.fit(get_node_or_null("BgLayer"), get_node_or_null("BgLayer/TextureRect") as CanvasItem, game, 19)
```

It hides the tiled `TextureRect` it replaces, attaches a `GrassField` control to `BgLayer` (a nested `CanvasLayer`, `layer = -1`, `follow_viewport_enabled`) so it
draws behind everything, sizes it to the board plus a four-tile margin (merged with the full canvas,
so a board smaller than the screen still has grass to the edges), and sows it. The seed is this
game's own — 19 — so no two games show the same field.

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
