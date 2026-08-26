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

## The look (`ptbits/scripts/arena_art.gd`)

`PtbitsArt` is where every pixel of the arena is drawn. It exists because the game used to be four
flat fills: one `draw_rect` of slate for the whole field, gray triangles for the deflectors, and
each basket a flat colored trapezoid with the backdrop color punched out of it. Nothing in the
arena had a top or a bottom, so the tool read as a colored circle rather than something you could
pick up and push with.

The scene is now lit from ONE place — the inlet at the top center, which is also where the balls
come from — and every part is built the same three ways: a vertical gradient so the surface has a
lit side, a rim light on the edge facing the light, and a shadow underneath so the part sits ON the
backdrop instead of being painted into it. Because the light source is a fact about the scene, the
ball texture, the tool disc and the basket lips all shade in the same direction.

| Part | What it is |
|---|---|
| `backdrop` | gradient, panel seams for scale, a widening cone of light from the inlet, vignette |
| `motes` | 14 specks drifting in the light, positions derived from the clock, no state |
| `loss_zone` | hazard wash + dashed line at the open bottom — the drop costs points and nothing said so |
| `frame` | inner shadow on three walls + a hairline of lit metal, so the field is recessed |
| `inlet` | two angled plates leaving a gap exactly as wide as the spawn band, with bolts |
| `bumper` | Gouraud-shaded steel: lit top face, dark bottom face, chamfer line, glint when struck |
| `basket_back` | breathing halo, contact shadow, gradient body, near-black cup, lip shadow |
| `basket_front` | ribs, overhanging rim, rim lights, white flash + expanding ring — drawn ABOVE the balls |
| `tool` | shadow, highlighted stem, rim-lit loop, shaded disc with a specular, glow while held |
| `ball_trail` | a tapered smear behind a ball above 150 px/s |

### Rules that must not be broken here

- **Every polygon is a convex quad or a triangle.** `draw_polygon` triangulates its input EVERY
  frame, and a concave outline can triangulate differently frame to frame — that is what made
  mother's dune crests crawl. Convex input has exactly one triangulation, and per-vertex colors
  then give a real gradient in a single call instead of a stack of banded strips.
- **The white highlight on a ball cannot live in the ball texture.** The texture is white and
  tinted per ball with `modulate`, which MULTIPLIES: white times a saturated red is red, so a
  specular baked into it is just a paler patch of the ball's own color. Each ball is therefore
  three sprites — `glow_texture` halo behind, tinted `ball_texture` sphere, untinted
  `ball_sheen_texture` in front.
- **What is drawn is what the ball hits.** `tool_parts().disc_radius` IS the collision radius and
  `basket_parts()` is laid out from the same interior polygon and half-wall-thickness as the
  collision boxes. A disc drawn a few pixels off its shape makes pushes feel wrong for a reason the
  player cannot see. The probe asserts both.

### The grab hint

The loop handle is the least discoverable thing in this game — a player who presses the disc gets
nothing and concludes the tool is fixed. The loop now pulses (`_grab_hint`, two rings) until
`_begin_drag` fires for the first time, then fades over ~0.45s and never returns. A hint that stays
forever is decoration; one that retires the moment it is understood is instruction.

### Feedback

`_pop_at()` floats the score change where it happened (`+15`, `−5`), because the HUD number
ticking is not something a player can connect to the ball they just lost. A scored ball also
flashes its OWN basket only (`_basket_flash[color_id]`), and a ball passing a deflector glints it —
proximity to the face, not physics contacts, so no ball needs contact monitoring turned on.

`_update_art()` runs BEFORE the playing/paused guard in `_process`: the arena keeps breathing while
a tutorial caption holds the balls still, which is the difference between paused and switched off.

### Why the rim overhangs

The first version put a flat, near-white cap on top of each of the two walls, and every basket read
as a **horseshoe magnet** — a U of saturated color with a bright tip on each prong is exactly how a
magnet is drawn, and the red one was unmistakable. Three changes, all in `basket_parts` /
`basket`:

- the rim overhangs the wall **outward** by `COLLAR` (7px) and is bevelled underneath, which is
  what a bucket rim does and what a pole face never does;
- the highlight on it dropped from `lightened(0.72)` at full alpha to `lightened(0.34)` at 0.55 —
  bright enough to catch the light, not bright enough to be a pole;
- two **ribs** band the body, breaking the smooth silhouette the magnet reading depends on.

The probe asserts the overhang is outward and that neither rim reaches over the mouth the ball has
to drop through.

### Two passes, with the balls in between

A ball that lands in a basket is IN it, not in front of it. The level's own `_draw()` runs before
every one of its children, and the balls are children, so anything the basket drew there was behind
the ball unconditionally — a resting ball covered the near wall completely and read as sitting on
top of the cup.

So a basket is drawn twice: `basket_back` (halo, shadow, body, cavity, lip shadow) from the level
itself, and `basket_front` (ribs, rims, rim lights, score flash) from `_basket_front`, a Node2D at
**z_index 20**. It has to be a z_index and not tree order: balls are added as children as they
spawn, so they always come later in the tree than any node created in `_ready`.

Score pops (z 62) and the miss cross (z 60) stay above both.
