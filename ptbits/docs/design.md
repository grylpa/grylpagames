# Ptbits — Game Design & Implementation Document

## Overview

**Game name:** Ptbits
**Folder:** `ptbits/`
**Singletons:** `PtbitsG`, `PtbitsLevelDefs`
**Save key (short name):** `ptbits`
**Initial time:** 1 minute (game over on time out)
**Category:** Attention & Speed
**Clear color:** `0x161d2bff` (dark slate)

Ptbits is a **physics** game. Coloured balls fall slowly from the top under
gravity. The player drags colour-matching **tools** (paddles) to physically push
each ball up and sideways into the matching-colour **basket** on the side. A tool
only interacts with balls of its own colour — mismatched colours pass straight
through it. A ball is scored when it drops into its matching basket from the top;
it is a miss if it falls out the bottom.

This is unlike the tween-based `bucketmadness` it borrows its scaffolding from —
here balls are real `RigidBody2D` bodies and tools are real `AnimatableBody2D`
pushers. The `main.gd` orchestrator, menu/instructions/scores wiring, level queue
and settings all follow the standard platform pattern (copied from bucketmadness).

---

## File Structure

```
ptbits/
├── docs/
│   └── design.md          ← this file
├── scripts/
│   ├── globals.gd          (PtbitsG autoload; owns GenericGameUtil + ball texture)
│   ├── level_defs.gd       (PtbitsLevelDefs autoload; per-level difficulty)
│   ├── main.gd             (orchestrator — standard platform pattern)
│   └── level.gd            (all physics gameplay)
└── scenes/
    ├── main.tscn           (Main → Level, HUD, GameTick, Help)
    └── level.tscn          (Level = Node2D, everything built in code)
```

No art files. Baskets and tool paddles are drawn procedurally; the ball uses a
generated white circle texture (see below). Sounds come from `res://art/sounds/`.

---

## The colour = physics-layer trick (core mechanic)

Collision behaviour is driven entirely by Godot physics layers:

- **Bit 1 = OUTER** — side walls + ceiling + **top-corner deflectors** (no floor, so misses
  fall out the bottom). All OUTER bodies get a **bouncy `_wall_material` (bounce 0.9)** so a
  ball jammed into a wall rebounds toward centre — this frees a side-pinned ball. Restitution
  combines as the max, so tool and bucket contacts (no material) keep the ball's own low 0.4
  bounce; only wall hits are springy. The two corners are chamfered by a 45° `StaticBody2D` segment
  (`_add_deflector`, drawn from `_deflectors`). This is the **escape route** for the
  pusher-can't-pull limitation: a ball pinned flush against a side wall (where there's no
  room to get the tool on its far side to push it back toward centre) can instead be pushed
  straight **up**; at the top the diagonal deflects it back inward, giving room to work it
  toward its basket. Bouncy walls (ball bounce 0.4) add finesse — you can also bank a ball
  off a wall.
- **Colour `i` = bit `2 + i`** — shared by that colour's balls, its tool and its basket walls.

| Body | `collision_layer` | `collision_mask` |
|------|-------------------|------------------|
| Outer wall (StaticBody2D) | OUTER | — |
| Basket `i` walls (StaticBody2D) | bit(2+i) | — |
| Tool `i` (AnimatableBody2D) | bit(2+i) | — (0) |
| Ball `i` (RigidBody2D) | bit(2+i) | OUTER \| bit(2+i) |

Because two bodies collide iff `A.layer & B.mask` **or** `B.layer & A.mask`:

- Ball `i` collides with outer walls, **its own** tool, **its own** basket, and same-colour balls.
- Ball `i` ignores every **other** colour's tool and basket → they pass through (the requirement).
- Tool `i` (mask 0) is *detected/pushed by* ball `i` but never collides with basket/wall
  bodies → no tangling. It is kept inside the play area by code clamping, not walls.

`_color_bit(i)` returns `2 + i`; `_set_layers(body, layer_bits, mask_bits)` applies them
via `set_collision_layer_value` / `set_collision_mask_value` (1-based bit indices).

---

## Balls

- `RigidBody2D` + child `CircleShape2D` (radius = `ball_radius`) + child `Sprite2D`.
- **Texture:** `PtbitsG.ball_texture()` returns a generated 96×96 white circle
  (`ImageTexture`) whose **alpha masks the square texture into a circle**, while the
  physics uses the `CircleShape2D`. This directly satisfies "use a texture so it can be
  changed later, but mask it for the physics." The sprite is `modulate`d per colour, so
  one texture tints to any colour. **To swap in real art:** drop a square PNG at
  `res://ptbits/art/ball.png` and return `preload(...)` from `PtbitsG.ball_texture()`.
- **Soft, non-jumpy motion:** `linear_damp = 3.2`, `angular_damp = 4.0`, `mass = 2.0`,
  **bounce 0.4** (rebounds off walls when thrown at them), friction 0.9. High damping means
  a tool contact only *nudges* the ball and it settles fast instead of being flung.
  `can_sleep = false` (a resting ball still responds to a push), `continuous_cd = CCD_MODE_CAST_SHAPE`
  (sweeps the whole circle, not just the centre ray, so a fast ball can't clip through a wall corner).
- **Speed cap (`MAX_BALL_SPEED = 420`)** — enforced authoritatively **inside the ball's own
  `_integrate_forces`** (`ball.gd`, instanced via `BALL_SCRIPT`). This matters: clamping in the
  level's `_physics_process` runs *before* the solver, so it misses the pinch impulse and the
  ball still shoots off for a frame; `_integrate_forces` runs *within* the step, after contacts.
- **Position corral (`_corral_balls`, every physics frame)** — a deep tool-vs-wall pinch can
  *positionally* teleport a ball past a wall (a jump no velocity clamp can stop). So each frame
  any ball outside the side walls / ceiling is snapped back inside and its outward velocity
  zeroed. The **bottom is deliberately left open** so a genuine miss still falls through.
  Tool speed was also lowered (`TOOL_MAX_SPEED = 1150`) to reduce pinch penetration depth.
- **Fall speed:** because damping caps terminal velocity at `≈ 980·gravity_scale / linear_damp`,
  the per-level `gravity_scale` (0.26–0.46) is tuned to give a gentle ~80 px/s (L1) up to
  ~140 px/s (L5) fall. If you change `linear_damp`, re-tune `gravity_scale` to match.
- Metadata: `color_id`, `spawn_ms` (for response-time scoring).
- Spawn x is a random point in the **central band** (`play_left+130 … play_right-130`)
  so balls never spawn on top of the side baskets.

## Tools

- `AnimatableBody2D` with `sync_to_physics = true` (kinematic body that pushes rigid
  bodies as it moves). One per colour, **round** `CircleShape2D` (radius `TOOL_RADIUS = 27`),
  drawn as a filled `Polygon2D` disc + `Line2D` rim + a small hub, in the colour.
- **Round on purpose:** a ball can never rest on top of a disc (round-on-round contact is
  unstable), so the player must keep nudging — the requested behaviour.
- Start in a tray row near the bottom centre; they float in place (kinematic, no gravity)
  until grabbed. All tools live in a dedicated `_tools_layer` (a `Node2D` added before any
  balls, so balls still draw on top). On grab, `_bring_tool_to_front()` `move_child`s the tool
  to the end of that layer, so the tool you're moving renders **in front of the other tools
  and stays there** after you drop it.
- **Dragging:** on touch/mouse press, `_grab_at()` picks the nearest tool within a circular
  grab radius. `_drag_target` follows the pointer; in `_physics_process` the tool moves
  toward the target capped at `TOOL_MAX_SPEED` (**1450 px/s** — deliberately low so a
  contact nudges rather than flings) instead of tunnelling. Single active drag at a time
  (`_drag_index` tracks the touch index; `-1` = mouse). Position clamped to the play rect.

## Baskets

- **Free-standing island trapezoids** (symmetric: wide open top ~120px, narrower bottom
  ~82px, ~94px tall), distributed **even ids → left, odd ids → right**, stacked downward
  from ~36% of the play height. Critically, they are held **well off the screen walls** —
  `clearance = 2·ball_radius + 26` (wider than a ball) on the outer side (`cx = play_left +
  clearance + top_w/2`, mirrored on the right).
  - **Why islands, not wall-hugging:** a bucket near/against a wall creates a wall-adjacent
    ledge. Pushing a same-colour ball *up along the wall* jams it in the wall+bucket corner
    (the tool can't reach the wall side of the ball) → solver over-constrained → jitter,
    and the jitter briefly flings the ball above the mouth, arming it, so it drops in and
    false-scores. As islands, a ball herded to the wall instead rides the **ceiling
    deflector back to open space**, and the tool can approach a bucket from any side.
- Each is one `StaticBody2D` (on that colour's bit) with **three** `CollisionShape2D`
  children: a horizontal bottom wall + two **rotated** rectangle walls for the slanted sides
  (`_add_wall_shape(body, center, size, rotation)`; rotation = the side segment's `.angle()`).
  Open at the top.
- **Scoring requires an actual drop-in from above**, not mere presence in a zone. In
  `_process`, for a ball whose `color_id == i`, three conditions must all hold:
  1. **Armed** — the ball has, at some point, been **above the bucket mouth** (center
     `y ≤ poly.TL.y` and `x` within the opening span `[TL.x, TR.x]`); a per-ball `armed`
     meta flag latches this. Being pushed *up* through the zone from below never arms it.
  2. **In the interior zone** — center inside `_basket_rects[i]`, the lower-**centre** of the
     bucket (`bot_w·0.56` wide, lower ~42% tall, inset from every wall so a ball merely
     pressed against a wall at the bucket's height doesn't count).
  3. **Dropping or settled** — `linear_velocity.y > 5` (falling in) **or** speed `< 30`
     (come to rest); it never scores while being shoved upward.
  Safe because a ball can only physically enter its own bucket over the top rim (bottom/side
  walls block all else; wrong-colour balls pass through and are never tested). The mouth
  span / interior come from `_basket_polys[i]` (`[TL,TR,BR,BL]`) and `_basket_rects[i]`.
- Drawn procedurally in `_draw()` from `_basket_polys[i]` (the 4 corners `[TL,TR,BR,BL]`):
  translucent trapezoid fill + horizontal "weave" slats + rim on the two slants and bottom
  (open top with small lip flares), so bucket colour/shape is fully controllable.

---

## Gameplay Flow

1. `new_game()` pops the next level id, `_load_level()` sets difficulty, `_build_world()`
   rebuilds outer walls + baskets + tools (colour count can change between levels).
2. `_process()` spawns a ball every `spawn_interval`s while `spawned_count < rounds` and
   fewer than `max_active` balls are on screen.
3. Player drags tools to push balls into matching baskets.
4. `_process()` resolves balls: inside matching basket → **scored**; below the bottom →
   **miss**. Each counts toward `resolved_count`.
5. When `resolved_count >= rounds`, `_level_done()` fires: records result, shows the level-
   done popup, emits `sig_level_is_done`. `main.gd` then advances to the next level.
6. **Time out** (1 min) → `game.game_over_on_time_out` ends the game via the HUD.

## Pause handling

Balls are `RigidBody2D`, so pause is handled in `_update_pause_freeze()`: when
`game.paused()` / not playing / level done, every ball's `freeze` is toggled true, and
restored on resume. Tool dragging and spawning also early-return while paused.

---

## Level Config (`PtbitsLevelDefs.LEVELS`)

| ID | Name   | Colours | gravity_scale | spawn | max_active | rounds | radius |
|----|--------|---------|---------------|-------|-----------|--------|--------|
| 1  | Green  | 2 | 0.26 | 3.4s | 1 | 6  | 27 |
| 2  | Blue   | 2 | 0.30 | 2.9s | 2 | 8  | 25 |
| 3  | Red    | 3 | 0.34 | 2.6s | 2 | 10 | 25 |
| 4  | Cyan   | 3 | 0.40 | 2.2s | 3 | 12 | 23 |
| 5  | Orange | 4 | 0.46 | 2.0s | 3 | 14 | 23 |

(`gravity_scale` is tuned against `linear_damp = 3.2`; see Balls → Fall speed.)

`LEVEL_PROGRESSION_ORDER = [1,2,3,4,5]` (cycles). A level with `< 60%` accuracy is
re-queued (`PtbitsG.record_level_result`). Settings array: `[starting_level_id]`.

Colour palette (`level.gd COLORS`, up to 6): red, blue, green, yellow, purple, orange.

---

## Scoring

- Correct drop: `+15` + speed bonus (`max(0, 10 - elapsed_sec)`, i.e. up to +10 for a fast drop).
- Miss (ball falls out): `-min(5, score)`, plus `_flash_miss()` fades a red ✗ at the spot so
  a vanished ball reads clearly as a miss.
- Score row: `[didwin, wasaborted, level_id, mean_response_time_ms, pct_correct]`
  with `progress_level_pos = 6`, `progress_time_pos = 7`, `progress_pct_pos = 8`
  (shown as level name + avg time, like bucketmadness).

## Sound Effects

- Correct: `res://art/sounds/FreeSFX/GameSFX/PickUp/Retro PickUp Coin 07.ogg`
- Miss: `res://art/sounds/swoosh.mp3`

---

## Mobile adjustments (`MainGlobals.is_mobile()`)

On mobile the canvas is a fixed `680×1200` (`content_scale_size`), so it has a taller
play area than desktop. Because a fingertip covers the touch point, several sizes/positions
are bumped for touch:

- **Ball radius +6** — a bit bigger so it stays visible under a fingertip (`_load_level`).
- **Tool radius 27 → 54** (twice as big) so the disc isn't hidden by the finger (`tool_radius`,
  set in `_ready`).
- **Bucket vertical gap `height + 92`** (vs `+30` desktop) — the stacked top/bottom buckets
  were too close on the taller screen (`_build_baskets`).
- **Tool tray raised 40px** so the tools don't overlap the bottom button bar (`_build_tools`);
  the bucket bottom-clamp margin is correspondingly larger (190 vs 90) to stay clear of the
  raised, larger tools.

## Coordinate space

`Level` is a `Node2D` at the origin, so its global coords == screen pixels (canvas_items
stretch, 680-wide portrait). The play rect is computed from `MainGlobals`:
`play_top = header_height + 6`, `play_bottom = screen_size.y - 4` (footer already excluded),
`play_right = full_screen_size.x`. Recomputed on every `new_game()`.

---

## Key Pitfalls / Notes

- **Do not give the tool a non-zero mask.** Tool mask must be 0 so it is only ever *detected*
  by its own-colour balls and never collides with basket/outer walls (which would tangle the
  kinematic body). It is confined by `_clamp_tool_pos()`, not by physics.
- **Tool speed is capped** (`TOOL_MAX_SPEED`) and balls use CCD so a fast drag pushes rather
  than tunnels through a ball. If tunnelling shows up, lower the cap or raise ball radius.
- **No floor** — misses rely on the ball falling past `play_bottom + 2·radius`. If you add a
  floor, add explicit miss detection instead.
- Scoring is **position-in-rect**, safe only because balls physically cannot enter a
  non-matching basket. If basket collision layering changes, revisit `_process()` scoring.
- Ball texture is generated at runtime and cached on `PtbitsG`; swap via `res://ptbits/art/ball.png`.

## Key Signals

| Signal | Direction | Purpose |
|--------|-----------|---------|
| `Level.sig_level_is_done(didwin)` | level → main | level complete → save + popup, then next level |
| `Level.started_playing` | level → main | round started → `game.playing = true`, HUD timer |
