# Ptbits — Game Design & Implementation Document

## Overview

**Game name:** Ptbits
**Folder:** `ptbits/`
**Singletons:** `PtbitsG`, `PtbitsLevelConfig`
**Save key (short name):** `ptbits`
**Initial time:** 1 minute (game over on time out)
**Category:** Attention & Speed
**Clear color:** `0x161d2bff` (dark slate)

Ptbits is a **physics** game. Colored balls fall slowly from the top under
gravity. The player drags color-matching **tools** (paddles) to physically push
each ball up and sideways into the matching-color **basket** on the side. A tool
only interacts with balls of its own color — mismatched colors pass straight
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
│   ├── level_config.gd     (PtbitsLevelConfig autoload; per-level difficulty)
│   ├── main.gd             (orchestrator — standard platform pattern)
│   └── level.gd            (all physics gameplay)
└── scenes/
    ├── main.tscn           (Main → Level, HUD, GameTick, Help)
    └── level.tscn          (Level = Node2D, everything built in code)
```

No art files. Baskets and tool paddles are drawn procedurally; the ball uses a
generated white circle texture (see below). Sounds come from `res://art/sounds/`.

---

## The color = physics-layer trick (core mechanic)

Collision behavior is driven entirely by Godot physics layers:

- **Bit 1 = OUTER** — side walls + ceiling + the **triangular bumpers** (no floor, so misses
  fall out the bottom). Walls carry no physics material, so every surface uses the ball's own
  low 0.4 bounce and feels solid. (An earlier springy `_wall_material` bounce 0.9 was removed —
  the triangular bumpers now do the un-sticking, and the springiness made balls hop off walls.)
- **Solid triangular bumpers** (`_add_side_bumper`, drawn from `_bumpers`): a rigid
  `ConvexPolygonShape2D` triangle at **25% from the top** of each side — long (vertical) side on
  the screen wall, a 45° face on top and bottom meeting at an inward apex. A ball **falling** from
  above slides down-and-inward off the top face; a ball **pushed up** from below slides up-and-inward
  off the bottom face — either way toward center. They're the **main way to work a ball inward**
  toward a bucket. Being a real solid shape, the physics handles the **whole ball radius** (no
  squeeze) and it **can't be forced through**. Earlier tries that were dropped: a physical
  `one_way_collision` ramp (kinematic tool forced balls through it) and a scripted center-only
  deflector (a ball could be squeezed past because only its center was tested). Top-corner
  chamfer deflectors were also removed once the raised bumpers took over the inward-deflection job.
- **Color `i` = bit `2 + i`** — shared by that color's balls, its tool and its basket walls.

| Body | `collision_layer` | `collision_mask` |
|------|-------------------|------------------|
| Outer wall (StaticBody2D) | OUTER | — |
| Basket `i` walls (StaticBody2D) | bit(2+i) | — |
| Tool `i` (AnimatableBody2D) | bit(2+i) | — (0) |
| Ball `i` (RigidBody2D) | bit(2+i) | OUTER \| bit(2+i) |

Because two bodies collide iff `A.layer & B.mask` **or** `B.layer & A.mask`:

- Ball `i` collides with outer walls, **its own** tool, **its own** basket, and same-color balls.
- Ball `i` ignores every **other** color's tool and basket → they pass through (the requirement).
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
  changed later, but mask it for the physics." The sprite is `modulate`d per color, so
  one texture tints to any color. **To swap in real art:** drop a square PNG at
  `res://ptbits/art/ball.png` and return `preload(...)` from `PtbitsG.ball_texture()`.
- **Soft, non-jumpy motion:** `linear_damp = 3.2`, `angular_damp = 4.0`, `mass = 2.0`,
  **bounce 0.4** (rebounds off walls when thrown at them), friction 0.9. High damping means
  a tool contact only *nudges* the ball and it settles fast instead of being flung.
  `can_sleep = false` (a resting ball still responds to a push), `continuous_cd = CCD_MODE_CAST_SHAPE`
  (sweeps the whole circle, not just the center ray, so a fast ball can't clip through a wall corner).
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
- Spawn x is a random point in the **central band between the bucket columns**
  (`_spawn_min_x … _spawn_max_x`, computed in `_build_baskets` from the bucket mouths + ball
  radius). So a ball never spawns above a bucket and can't fall straight into one — it must be
  maneuvered there.

## Tools

- `AnimatableBody2D` with `sync_to_physics = true` (kinematic body that pushes rigid
  bodies as it moves). One per color. **Only the pusher disc collides** — a `CircleShape2D`
  (radius `tool_radius`, 27 desktop / 54 mobile) at the tool origin. Round on purpose: a ball
  can't rest on a disc, so the player must keep nudging.
- **Shape = disc + handle + loop** (roughly an ant: big head, body, tail loop). Below the disc
  is a **thick rounded handle bar** (`Line2D`, round caps) then an **open loop** (a `Line2D` ring
  at local `(0, grab_offset)`, `grab_offset = tool_radius·1.7`, `loop_radius = tool_radius·0.52`).
  The player **grabs the loop**, so the disc — and the ball it's pushing — sits `grab_offset`
  **above the finger** and stays visible. The stem/loop are visual only (no collision).
- **Grab & drag:** `_grab_at()` matches a press near a tool's **loop center** (`origin +
  (0, grab_offset)`). During drag the disc target is `finger − (0, grab_offset)` (loop stays
  under the finger), moved toward at `TOOL_MAX_SPEED` (1150 px/s). `_clamp_tool_pos` keeps the
  disc top and the loop bottom inside the field. Single active drag (`_drag_index`; `-1` = mouse).
- All tools live in a dedicated `_tools_layer` (`Node2D` added before any balls, so balls draw
  on top). On grab, `_bring_tool_to_front()` `move_child`s the tool to the end of that layer, so
  the tool you're moving renders **in front of the other tools and stays there** after drop.

## Baskets

- **Free-standing island trapezoids** (symmetric: wide open top ~134px, narrower bottom
  ~104px, ~96px tall), distributed **even ids → left, odd ids → right**, stacked downward
  from ~36% of the play height. Critically, they are held **well off the screen walls** —
  `clearance = 2·ball_radius + 26` (wider than a ball) on the outer side (`cx = play_left +
  clearance + top_w/2`, mirrored on the right).
  - **Why islands, not wall-hugging:** a bucket near/against a wall creates a wall-adjacent
    ledge. Pushing a same-color ball *up along the wall* jams it in the wall+bucket corner
    (the tool can't reach the wall side of the ball) → solver over-constrained → jitter,
    and the jitter briefly flings the ball above the mouth, arming it, so it drops in and
    false-scores. As islands the tool can approach a bucket from any side, and a ball herded
    to the wall rides a triangular bumper back toward center.
- Each is one `StaticBody2D` (on that color's bit) with **three** `CollisionShape2D`
  children: a horizontal bottom wall + two **rotated** rectangle walls for the slanted sides
  (`_add_wall_shape(body, center, size, rotation)`; rotation = the side segment's `.angle()`).
  Open at the top. Walls are **24px thick** (and the bucket widened to suit) so the kinematic
  tool can't force-push a same-color ball *through* a wall into the interior — a hollow-backed
  thin (12px) wall let a ~19px/frame push tunnel across; 24px > the per-frame push distance.
- **Scoring requires an actual drop-in from above**, not mere presence in a zone. In
  `_process`, for a ball whose `color_id == i`, three conditions must all hold:
  1. **Armed** — the ball has, at some point, been **above the bucket mouth** (center
     `y ≤ poly.TL.y` and `x` within the opening span `[TL.x, TR.x]`); a per-ball `armed`
     meta flag latches this. Being pushed *up* through the zone from below never arms it.
  2. **In the interior zone** — center inside `_basket_rects[i]`, the lower-**center** of the
     bucket (`bot_w·0.56` wide, lower ~42% tall, inset from every wall so a ball merely
     pressed against a wall at the bucket's height doesn't count).
  3. **Settled at the bottom** — `linear_velocity.length() < 40` (come to rest). It does *not*
     score while still falling/bouncing, so the ball visibly settles in the bucket rather than
     vanishing mid-drop, and it never scores while being shoved upward.
  Safe because a ball can only physically enter its own bucket over the top rim (bottom/side
  walls block all else; wrong-color balls pass through and are never tested). The mouth
  span / interior come from `_basket_polys[i]` (`[TL,TR,BR,BL]`) and `_basket_rects[i]`.
- **Bucket is drawn as one clean silhouette** (`_draw_basket`): a filled **outer trapezoid**
  (`col`) with the **inner cavity carved out** (filled with the backdrop color, raised above
  the mouth so the top is open), plus a faint color tint in the cavity. Both halves are simple
  convex quads (sides pushed out `hw = 12` = `wall_t/2`, bottom slab `2·hw` tall), so the slanted
  sides join the bottom with **no gaps**, and visible ≈ collision (walls centerd on the
  `tl/tr/bl/br` edges ±`hw`) so the ball still rests flush. (Earlier tries — thin outlines put
  the collision ~12px outside the line; three separate thick quads left a square-slab bottom that
  didn't meet the slanted sides.)
- **Stacked-bucket spacing:** `step = height + 24 + gap` (gap 44 desktop / 92 mobile). The `+24`
  accounts for the bottom wall (visible bucket is `height + 24` tall), so top/bottom buckets on
  a side never touch when a level has 3–4 colors.

---

## Gameplay Flow

1. `new_game()` pops the next level id, `_load_level()` sets difficulty, `_build_world()`
   rebuilds outer walls + baskets + tools (color count can change between levels).
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

## Level Config (`PtbitsLevelConfig.LEVELS`)

| ID/Name | Colors | gravity_scale | spawn | max_active | rounds | radius |
|---------|--------|---------------|-------|-----------|--------|--------|
| 1 | 2 | 0.26 | 3.1s | 10000 | 6  | 27 |
| 2 | 2 | 0.30 | 2.8s | 10000 | 8  | 25 |
| 3 | 3 | 0.34 | 2.6s | 10000 | 10 | 25 |
| 4 | 3 | 0.40 | 2.2s | 10000 | 12 | 23 |
| 5 | 4 | 0.46 | 2.0s | 10000 | 14 | 23 |

`max_active` (cap on concurrent balls) is set to **10000 = effectively unlimited** for now — balls
just spawn on the `spawn_interval` timer up to `rounds`. The mechanism is kept in the code in case
a concurrency cap is wanted later. (`gravity_scale` is tuned against `linear_damp = 3.2`; see
Balls → Fall speed.)

`LEVEL_PROGRESSION_ORDER = [1,2,3,4,5]` (cycles). A level with `< 60%` accuracy is
re-queued (`PtbitsG.record_level_result`). Settings array: `[starting_level_id]`.

Color palette (`level.gd COLORS`, up to 6): red, blue, green, yellow, purple, orange.

---

## Scoring

- Correct drop: `+15` + speed bonus (`max(0, 10 - elapsed_sec)`, i.e. up to +10 for a fast drop).
- Miss (ball falls out the bottom, **or** rests outside a basket for `REST_TIMEOUT_MS` = 5s at
  speed `< REST_SPEED`): `-min(5, score)`, plus `_flash_miss()` fades a red ✗ at the spot.
  The rest-timeout is essential: a new ball only spawns once the current one resolves, so a ball
  stuck at rest (on a dropped tool or a bumper) would otherwise **softlock the level** (no more
  balls drop, you just wait out the clock). Per-ball `rest_ms` accumulates while slow + outside a
  basket, and resets the moment it moves or enters a basket.
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
  by its own-color balls and never collides with basket/outer walls (which would tangle the
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
