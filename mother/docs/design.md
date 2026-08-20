# Mother Snake — Design Document

## Overview

A breathing game where the player (child snake) follows the mother snake's movement. The mother traces a smootherstep-eased path determined by the breathing pattern: up during inhale, flat during hold, down during exhale, flat. The child snake grows longer over time. Score is based on how closely the player's breathing rhythm matched the target pattern, measured via autocorrelation + phase-folding at session end.

## File Structure

```
mother/
├── docs/design.md
├── scenes/
│   ├── main.tscn      — Node root with Level child
│   └── level.tscn     — CanvasLayer with MotherCanvas + overlays
└── scripts/
    ├── globals.gd      — MotherG autoload; presets, PATTERN_RING_THRESHOLD, GenericGameUtil
    ├── main.gd         — orchestrator; main menu wiring; score saving
    ├── level.gd        — game logic + _do_draw()
    └── mother_canvas.gd — thin Control whose _draw() calls level._do_draw(self)
```

## Layout

- **Single background**: dark, unified (no split).
- **Mother y range**: `M_TOP_FRAC=30%` to `M_BOT_FRAC=56%` (center ~43%, just above screen mid). Child starts 60px below `_m_bot_y` at session start.
- **Both heads at `HEAD_X_FRAC=0.82`**.

## Visual design — "night desert"

Every colour and dimension lives in one block of constants at the top of `level.gd`, and
`mother/docs/make_thumbnail.py` mirrors them. Re-run that script after any visual change.

**What it replaced.** The game was saturated sand `(0.82, 0.70, 0.46)` under a near-pure green
mother `(0.18, 0.82, 0.22)` and a saturated indigo child `(0.30, 0.25, 0.90)` — three unrelated
hue families at high chroma. Three concrete problems: it was the only bright screen in the
"Serenity" category (crack `0.04,0.05,0.09`, river `0.06,0.18,0.34`, udbr `0.04,0.07,0.14`); it
contradicted itself, since the results panel and stats graph were already near-black; and the
child shared no hue with the mother, so they read as unrelated species.

Now the ground is dark and warm and the snakes are the light source: mother warm amber
`MOTHER_COL`, child pale gold `CHILD_COL` — one hue family, separated by lightness, so they read
as the same animal at two ages.

## The body

Three passes, in this order, and the head uses **the same three** so the two match:

| pass | what | node |
|---|---|---|
| halo | `GLOW_MUL` wider, `GLOW_ALPHA` faint, body hue, offset `SHADOW_DY` down | `_l_*_sh` |
| fill | base colour with dark bands (`BAND_PX`, `BAND_DARK`), tail dissolve | `_l_*` |
| spine | `STRIPE_W` wide, `STRIPE_LIGHT` lighter, **unbanded** | `_l_*_st` |

There is deliberately **no dark outline** anywhere.

### Line2D, not hand-built geometry

Two earlier approaches failed, and the second failure is the one to remember:

1. `draw_polyline` at constant width plus a pale stripe **down the center** — a centered stripe
   reads as a racing stripe, and a constant-width line with round caps reads as a cable.
2. A hand-built tapered polygon ribbon. **`draw_colored_polygon` triangulates through `Geometry2D`,
   which fails and draws NOTHING on a self-intersecting polygon** — and an offset ribbon
   self-intersects wherever the path turns sharper than its own half-width. A fold does not render
   a knot, it renders nothing: the mother vanished and the child flickered.

Line2D solves all of it in the engine — robust tessellation, `joint_mode` ROUND, `width_curve`
for the taper, `gradient` for banding and the tail dissolve.

**Points must arrive head-first**: `Line2D` samples `width_curve` and `gradient` from `points[0]`,
so the guided mother path — built left to right — is reversed before being handed over.

**Do not add nodes for visual effects.** A soft-edge attempt added two extra Line2Ds per snake and
every body stopped rendering. The cause was never identified; the working version instead
*repurposed* the existing shadow line as the halo. Six Line2Ds total, and the probe asserts that
count.

**A halo cannot be a hand-drawn polyline.** `draw_polyline` has a constant width, so it cannot
follow `width_curve` — at the tail the body is `TAIL_FRAC` of full width while the halo stayed at
100%, ballooning around the thin tail — and its mitred joints look wrong on corners. Built by the
same function from the same points, the halo inherits both for free.

### Bands

`_build_gradient` alternates base / `BAND_DARK` stops along the line; the tail dissolve is folded
into the same gradient.

**Stops are anchored in PIXELS from the head** (`offset = distance / length`), so a band 100 px
back stays 100 px back as the child's body grows and only new bands appear at the tail. Splitting
0..1 into equal fractions instead moved *every* band whenever the length changed — that was the
growth jitter.

**The length used is the smooth growth cap, not the measured span.** The snapped-time sampler
quantises the tail to the sample step, so the measured span oscillates every frame (132 shrinks
per 900 frames, measured); feeding that in would put the wobble into the pattern.

### The spine

**Must not be banded.** Sharing the body's banded gradient put its dark stops at value 0.72 against
the body's lit 0.88, so along the length the spine alternated between lighter *and darker* than
the body and cancelled itself out. A plain constant gradient measures 0.928 flat against a body
range of 0.722–0.880 — lighter everywhere.

### Width, taper and the breathing pulse

`MOTHER_W` / `CHILD_W` are the width at the **head**; `width_curve` tapers to `TAIL_FRAC`, and the
pulse scales the whole thing between `PULSE_W_LOW` and `PULSE_W_HIGH`.

The body **swells and brightens on the inhale**, driven by `_openness(y, drop)` (0 exhaled, 1
inhaled). It changes nothing geometric, so it cannot reintroduce the artifacts that per-point
offsets caused — and it is the one visual that *means* something: in a breathing game the snake
should visibly breathe. The player's own body pulses from their own position, so it is feedback,
not decoration.

**Brightness rides on `modulate`, not `default_color`.** `Line2D.gradient` REPLACES
`default_color`; written there it did nothing at all, and a probe "verified" it by reading back
the ignored property.

**Judge width by the MEAN along the body, not the base number** — the taper hides a large fraction
of it.

### Anything spatial must scale with the body width

`MOTHER_W` has been retuned repeatedly (18 → 30 → 80 → 30). Every constant in absolute pixels
silently went wrong each time: a fixed 2 px sample step against an 80 px body is a segment/width
ratio of 0.026, and `BAND_PX` 12 goes from 1.5 to 6.4 bands per width. Express spatial constants
as a share of body width, and re-check `BAND_PX` after any width change.

### Slither — vertical displacement only

Amplitude `SLITHER_AMP_W` (a share of body width), one wave per `SLITHER_WAVE_W`, travelling
toward the tail at `SLITHER_SPEED`, eased in over `SLITHER_RAMP_W` behind the head so the head
stays exactly on the true path (measured: 0.00 px).

**It displaces in Y only, and that is the whole design.** An earlier version displaced along the
local NORMAL; at a turn that rotates nearly 180° between adjacent samples, so the points crossed
and the body tangled itself at exactly the turns. The path is strictly monotonic in x, so moving
points in y alone leaves it monotonic — and **a polyline monotonic in x cannot self-intersect**,
because any vertical line still crosses it once. That is a proof, not a tuning; the probe asserts
the monotonicity every frame.

Phase comes from **horizontal distance from the head**, which is independent of the point count,
so it cannot jump when the sampler adds or drops a vertex.

Note the amplitude scales **both** ways: at a body width of 80, `0.32` is a 26 px wobble.

### Sampling

Both bodies are sampled at times snapped to a fixed grid
(`t_base = floor(elapsed / dt_step) * dt_step`), walking head-first, never at fixed screen-x.
Snapping the sample *times* keeps each vertex's neighbours constant frame to frame, so the body
scrolls smoothly instead of resampling under itself.

The guided mother used to be the exception — fixed screen-x with exact phase-transition vertices
spliced in — which changed the point count every frame and jittered everything, worst at the turns
because that is where the extra vertices were. `_phase_y_at` uses smootherstep, which is C2, so no
vertex is needed at a phase boundary.

### The child's tail

Starts at `CHILD_START_LEN_PX` and lengthens at `CHILD_GROW_PX_PER_MS` (~40 s to fill the screen).
`_prefill_history` seeds the ring buffer with a flat run at the starting position, so the opening
tail is ordinary history samples drawn by the same code path. It used to start at zero and reach
full length in ~12 s, so every session opened with the tail visibly stretching.

## The head

**Drawn, not a sprite.** It was `head1/2/3-4x.png` — a white ellipse with a black border and two
eyes. **No transform can make an ellipse snake-like**: scale, rotation and skew are affine, so they
map a rectangle to a parallelogram and can never taper. Squashing the quad narrower at the nose
would squash the *border* with it, thick at the base and thin at the snout.

Drawn, the outline is the real thing: narrow at the snout, widest at the **jaw** a little behind it
(`HEAD_JAW_AT`), then narrowing into the neck. A straight wedge reads as a spearhead; the jaw bulge
is what makes it a snake.

- **Both ends are rounded caps.** Flat cuts left hard corners that caught the eye on every turn.
- **The halo fades out toward the neck** (`HEAD_HALO_FADE`). Carried all the way round, anything
  drawn outside the outline puts a ring ON the body where the head overlaps it — which is what made
  the head read as a separate disc rotating over an unrelated body.
- **The head reaches well behind the body's head point**, so the rounded neck is buried inside the
  body and the join is never visible.
- **The banding continues across the join with zero phase error.** The body pins bands to distance
  *back* from the head point; head-local +x runs *forward* from the same point, so distance = −x
  carries the phase straight through. Verified against the body's own gradient at 0/6/12/18/24 px:
  delta 0.000 at every sample.
- The fill is drawn as **transverse strips**, so each band follows the tapering outline instead of
  cutting straight across it.
- Eyes carry a faint lid ring (`HEAD_EYE_RING`) because a plain black dot loses definition on a
  banded fill. Frame 2 of the 4-frame cycle is a blink.

## Environment

- **Three parallax dune ridges** (`DUNE_LAYERS`), filled bands whose top edge is a slow double
  sine, each scrolling at its own fraction of world speed (0.22 / 0.40 / 0.62, far to near). The
  differing speeds are what read as depth. Deliberately **not** a horizon with a moon: the ripples,
  pebbles, bushes and beetles all establish an oblique view of a ground *plane*, and a skyline
  would contradict every one of them. The top edge is single-valued in x and always well above the
  bottom, so the outline is always a simple polygon.
- **Drifting dust** (`DUST_COUNT`): size, speed and opacity all derive from the **same** depth
  value as the mote's y, so a nearer mote is bigger, faster and brighter together. Rolling them
  independently just looks like noise. Dust also drifts faster than the fastest pebble, so the
  parallax runs the right way round.
- **A vignette** on the props canvas, over the snakes. `VIGNETTE_DEPTH` is capped so the darkening
  stops short of `HEAD_X_FRAC` — at 0.22 it clipped the heads, the one thing the eye should go to.

## Layer order

Ground canvas 0 → halo 1 → body 2 → spine 3 → props canvas 3 → heads 5/6.

The props canvas exists because bushes and beetles are drawn **over** the snakes, so a snake
passing behind a bush reads as being on the ground; once the bodies became Line2D nodes rather
than canvas draws, the props needed their own canvas above them.

## Active mode draws the PLAYER, not the mother

In Active mode there is no guide: the only body on screen is the player's own trail. It used to
wear the mother's colour, width and head, which made Active mode look exactly like Guided mode
with the mother missing — reported as a bug more than once. It now wears the child's.

**When debugging "I can't see the mother", check `selected_mode` in the save file first.** Probes
written during the Line2D rework all forced `selected_mode = 2` to have a guided path to test, so
three rounds of verification passed while never touching the mode the player was in.

## Heads turn gradually

Both heads ease toward the current direction at `HEAD_TURN_RATE` via `lerp_angle`. The body's turn
is smootherstep-eased, so a head snapped to the instantaneous tangent looked mechanical. The
mother's was previously set straight from her phase velocity with no smoothing at all.

## Freeze guard in `_do_draw`

`_scroll_px_per_ms` is `screen_w / (1.5 * cycle_ms)`. If it is ever zero, a loop that steps from a
start derived by dividing by it begins at `-INF` and **never terminates** — a hard freeze, not a
glitch. A layout that has not been sized yet is enough to produce it. Checked at the top of
`_do_draw`.

## Thumbnail

`mother/art/game_screen_200.png` is generated by `mother/docs/make_thumbnail.py`, which mirrors
level.gd's constants and passes. It approximates Line2D as a run of overlapping discs — which is
effectively what a round-jointed Line2D is. Two details matter there: the halo must be a separate
pass (a per-disc outline beads the edge and makes the body read as rope), and the banding must be
sampled per disc from distance-along-the-body so it follows the taper.

**Verification here is structural only.** Headless Godot has no renderer and there is no xvfb, so
nothing visual can be checked in this repo — probes confirm points, widths, colours, z-order and
node counts, and those have repeatedly passed on something visibly broken. Add visual features one
at a time and confirm each on a real screen before the next.


## Mother Path

`_phase_y_at(t_ms, top_y, bot_y)` uses smootherstep easing (`x³(x(6x-15)+10)` — C2 continuity, no sharp corners at hold transitions):

```
if t < inhale_ms:  return lerp(bot_y, top_y, smootherstep(t/inhale_ms))
if t < hold_top:   return top_y
if t < exhale_ms:  return lerp(top_y, bot_y, smootherstep(t/exhale_ms))
return bot_y
```

## Child Input

- **Touch**: drag vertically — position follows finger within `[_c_top_y, _c_bot_y]`.
- **Keyboard**: smooth velocity (`lerpf` factor 8). UP held → lerps toward inhale speed, DOWN held → exhale speed, no key → velocity lerps to 0 (hold). This gives curved path shape matching mother's smootherstep.
- Body drawn from history ring buffer (16ms intervals, 3000 slots ≈ 48s max body).

## Trace Recording

`_current_trace` stores `Vector2(elapsed_ms, y_norm)` samples every 200ms (y_norm = (child_y - c_top_y) / c_range). Finalized into `_trace_segments` on session end.

## End-of-Session Analysis: `_compute_phase_durations(keys)`

Keyboard is polled every 50ms during the session. Each sample appended to `_key_poll`:
- `1` = UP pressed (inhale)
- `2` = DOWN pressed (exhale)
- `0` = neither (hold)

`_compute_phase_durations(keys: Array) -> Array` receives the full poll array and returns `[inhale_ms, hold_top_ms, exhale_ms, hold_bot_ms]` as average phase durations in ms. The stub returns `[0, 0, 0, 0]` — user fills the implementation.

## Scoring

Pattern accuracy score from FFT analysis vs. preset target:

```
err = mean of |measured - target| / target for each of 4 phases
score = max(0, round((1 - min(err, 1)) * 100))
```

Saved via `game.add_score_and_time(score, 0, true)` then `game.save_score(get_session_score())`.

**Score array** (saved): `[unixtime, score, time_left, times_run, didwin, wasaborted, duration_min, session_ps, rt_ms]`
- Index 8 = `rt_ms`: average reaction time in ms (trimmed mean of center 80th percentile). 0 if no data or active mode.

Results display shows measured vs. target for each phase and average reaction time (ms).

## Reaction Time

`calc_reaction_time(mother_commands, child_actions)` — both arrays are 50ms-slot polls (0=hold, 1=inhale, 2=exhale).

For each phase transition in mother_commands:
- Look back 4 slots (200ms): if child made the same transition already → record 0 (early reaction)
- Look ahead 40 slots (2s): find first slot where child makes the same transition → record delay in slots
- If neither found: skip (missed transition, not counted)

Returns trimmed mean of center 80th percentile of recorded values × 50ms, rounded to int.

**Stats display**: reaction time appears in the Scores table "React Time" column, the Speed tab, and the Chart tab as a second metric ("React Time", lower is better).


## Scroll Speed

`screen_w / (1.5 * cycle_ms)` — ~1.5 breathing cycles visible at once.

## Settings

Index 0: `duration_min` (1–30, default 1)
Index 1: `selected_preset` (index into `GUIDED_PRESETS`)

Presets (seconds): `[4,1,4,1]`, `[6,1,6,1]`, `[4,4,4,4]`, `[2,1,2,1]`.

## Tutorial

`mother/scripts/tutorial.gd` (12 steps), entry `mother/scripts/main.gd::start_tutorial()`, forced
into **Guided 4-1-4-1** (`selected_mode = 2`) with `duration_min = 30`. Both are restored in
`_on_tutorial_done` and in `_exit_tree`, since neither is part of the `GenericGameUtil` snapshot.

**Shape: introduce her, send her away, bring her back.** The game asks for one thing — keep your
head level with hers — but learning an unfamiliar control *while* keeping up with a rhythm is one
thing too many, and with her on screen every fumbled movement is also a failure to match her. So
the mother is introduced, then hidden (`tutorial_set_mother_visible(false)`); the player learns the
three things they can do — up, down, hold — each on its own step, judged only on their own
movement; then she comes back and the final ask is a few seconds of trying to go with her, on a
30-second timeout. That last step is a try, not a test: a player who cannot hold a whole breath
level with her yet still finishes, and the closing caption reads the live state and says so.

Two things a first-timer does not work out alone, and both get their own caption: **your finger
never has to touch the snake** (players poke at the moving head otherwise), and **a hold is
performed by doing nothing** — stop moving, lift off. The hold is the action nobody performs unless
asked, which is why it gets a step to itself.

Specific to this game:

- **Forcing Guided is not optional.** Active mode has no mother on screen at all, so every caption
  in the tutorial would describe something that is not there. The User preset is built from the
  player's own past sessions, which a first-timer has none of.
- **`_on_level_session_done` returns early in `tutorial_mode`.** The tutorial holds the session open
  for 30 minutes, so a slow player can genuinely reach the end of one, and the Active branch writes
  `MotherG.learned_*` / `has_user_session` — plain in-memory globals that `save_settings`'s
  tutorial-mode guard does not cover, so the *next* legitimate save would persist the tutorial's
  numbers as the player's own breathing pattern.
- **Freezing is free here.** `_process` returns early on `game.paused()`, so a caption stops the
  mother, the scroll and the session clock together, and nothing jumps when it closes. The harness
  asserts both her y and the phase name are unchanged across a caption.
- **The heads are positioned in `new_game()`, not only in `_process`.** They are made visible there,
  and a tutorial caption that opens on the first frame freezes `_process` — so without it both
  heads sit at the origin, in the top-left corner, for as long as the coach is talking. That is
  what "declares a spotlight but nothing resolved" meant on the first run.
- **Latches are seeded from the starting position** in `new_game()`, not cleared to false: the child
  starts *below* the mother's band, so a false latch reports "reached the bottom" on frame one.
- **The solo events must not depend on where she is**, since she is not on screen when they are
  taught. `moved_up` / `moved_down` are judged against a baseline the step's `setup` stamps
  (`tutorial_mark_move_baseline()`), and `held` needs `TUT_HOLD_MS` (1.2 s) within `TUT_STILL_PX`
  (6 px) — with slack for the settle, because releasing does not stop the child dead: the velocity
  lerps out over a few tenths of a second.
- Events: `moved_up`, `moved_down`, `held`, `reached_top`, `reached_bottom`, `with_mother`,
  `cycle_followed`. The last needs unbroken proximity (`TUT_WITH_PX`, 40 px) for a full cycle, and
  any drift restarts it — the only one a single lucky swipe cannot earn.
- **`_tutorial_watch()` runs outside the guided branch of `_process`.** It used to be called from
  inside it with `mother_y` passed in, which would have stopped the three solo events firing the
  moment she was hidden.
- Points for the coach: `tutorial_mother_pos`, `tutorial_child_pos`, `tutorial_head_radius`,
  `tutorial_phase_label`, `tutorial_goal_label`, plus `tutorial_phase_name` /
  `tutorial_is_with_mother` / `tutorial_follow_progress` for captions that read the live state
  instead of asserting one.

## Key Pitfalls

- `_analyze_trace()` needs at least ~2 complete breathing cycles to detect the period
  (autocorrelation threshold 0.15). Short sessions or no movement return `valid=false`.
- Mother path uses **smootherstep, not smoothstep** — C2 continuity, so no velocity jump at hold
  boundaries. This is also why no vertex is needed at a phase transition.
- History ring buffer has a 4-slot warm-up: the body is not drawn until 4 slots are populated.
- **Both** bodies are sampled at times snapped to a fixed grid, never at fixed screen-x. The guided
  mother used to be the exception (fixed screen-x plus spliced `_extra_xs` vertices); that changed
  the point count every frame and jittered the texture, the joints and the slither, worst at the
  turns. `_extra_xs` is gone.
- **`Line2D.gradient` REPLACES `default_color`.** Anything written to `default_color` on a line
  that has a gradient is silently ignored.
- **`draw_colored_polygon` draws NOTHING for a self-intersecting polygon** — it fails to
  triangulate. A fold does not look like a knot, it looks like absence.
- **`draw_polyline` has a constant width**, so it can never follow a `width_curve`.
- **Do not add nodes for visual effects.** Two extra Line2Ds per snake once made every body vanish;
  the cause was never found. Reuse the six that exist. The probe asserts the count.
- **Anything spatial must be a share of body width.** `MOTHER_W` has moved 18 → 30 → 80 → 30 and
  every absolute-pixel constant broke silently each time.
- **`var ease`, `var lerp`, `var round`… shadow GDScript built-ins** and Godot warns
  (`SHADOWED_GLOBAL_IDENTIFIER`). Headless does not surface it. The scratch linter now checks for
  built-ins and base-class members as well as unused locals.
- **Check `selected_mode` in the save file before debugging "the mother is missing"** — in Active
  mode there is no mother by design.
- **Nothing visual is verifiable in this repo.** Headless has no renderer and there is no xvfb;
  structural probes have repeatedly passed on something visibly broken. One visual change at a
  time, confirmed on a real screen.
