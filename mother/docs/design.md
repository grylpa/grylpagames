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

- **Single background**: the lit dune field (see Environment), unified (no split).
- **Mother y range**: `M_TOP_FRAC=30%` to `M_BOT_FRAC=56%` (center ~43%, just above screen mid). Child starts 60px below `_m_bot_y` at session start.
- **Both heads at `HEAD_X_FRAC=0.82`**.

## Visual design — sunlit desert

**It used to be night, and that was the problem under all the others.** The ground sat at 7-18%
luminance; the three dune ridges differed from it by six to fourteen levels out of 255. There is no
such thing as an interesting near-black surface, so every attempt to make the scene richer failed
while the fundamental stayed dark.

It is now a desert in full sun:

| | luminance (of 255) |
|---|---|
| sand in sun | 204 |
| shaded sand | 148 |
| dune crest | 225 |
| slip face | 120 |
| mother's diamonds / ground | 29 / 163 |
| child's diamonds / ground | 46 / 216 |

**Desert shadows are blue.** In open sun the only light reaching a shadow is skylight, so the slip
faces and troughs were cooled (the old crescents' shadow had more blue than red) while lit sand is warm; the dune field's shadow (`DUNE_SHADE`) is a warm orange instead, as on the tile. That
warm-lit / cool-shadow split is where a desert's color actually comes from, and having everything
one brown is why the old scheme read as mud.

Everything else followed from the inversion: props are darker than the ground now (dry olive scrub,
warm pebbles, near-black beetles), text is dark ink rather than cream, the vignette dropped from
0.26 to 0.10 so it does not re-darken a sunlit scene, and the bodies' halo pass became a **cast
shadow** (`BODY_SHADOW`) — in daylight a snake does not glow, it sits on the sand and darkens it.

## The snakes are diamondbacks: scales and a pattern, not rings

The bodies wear a SKIN TEXTURE (`_build_skin`, a 96x48 tile built once per snake at `_ready`), tiled
along each body Line2D (`LINE_TEXTURE_TILE`: across the tile is across the body, along it two body
widths): a light ground color, down the back a dark diamond with a pale rim and a lighter heart, tip
to tip with the next, small dark blotches on the flanks between them, overlapping scales (staggered
rows, each with a darker edge and a faint sheen), and the whole shaded darker toward the flanks so the
body reads as round. Mother: amber ground (`MOTHER_BAND`) with chocolate diamonds (`MOTHER_COL`);
child: pale gold (`CHILD_BAND`) with the same pattern in a lighter brown -- the same animal at two
ages. The gradient now only fades the tail (`_tail_gradient`, white, alpha to 0 past `TAIL_SOLID`);
the texture is multiplied by it. The dorsal sheen line is no longer drawn (its points are left empty).

History, briefly: crossband RINGS -- a gradient alternating two colors along the body, `BAND_PX`
apart -- which snakes do not have ("why are we using those cross-section rings anyway?", user
2026-10-25), and which fanned into wedges on every tight turn. A texture was tried long before and
dropped because, at the path's real corners, a round joint's texture coordinates did not match the
segments'. That held only while the path had corners: the corners are now rounded wider than the
body (Mother Path), the body's own curves are smoothed (`_smooth_body`), and the points are 2 px
apart (`_densify`), so the joints are invisible. `_build_gradient`/`_band_shade` remain in the code
but are not used for the bodies.

## The body

Two passes per snake, and the head matches them:

| pass | what | node |
|---|---|---|
| halo | `GLOW_MUL` wider, `GLOW_ALPHA` faint, body hue, offset `SHADOW_DY` down | `_l_*_sh` |
| skin | the skin texture (`_build_skin`), tail dissolve gradient | `_l_*` |

(`_l_*_st`, the old sheen line, still exists so the node count holds; it is drawn with no points.)
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
for the taper, a tiled texture for the skin, `gradient` for the tail dissolve.

**Points must arrive head-first**: `Line2D` samples `width_curve` and `gradient` from `points[0]`,
so the guided mother path — built left to right — is reversed before being handed over.

**Do not add nodes for visual effects.** A soft-edge attempt added two extra Line2Ds per snake and
every body stopped rendering. The cause was never identified; the working version instead
*repurposed* the existing shadow line as the halo. Six Line2Ds total, and the probe asserts that
count.

**A halo cannot be a hand-drawn polyline.** `draw_polyline` has a constant width, so it cannot
follow `width_curve`; built by the same function from the same points, the halo inherits it.

**The body's own curves are smoothed** (`_smooth_body`, drawing only): a moving average of the
points' y over about 0.8 body width, faded in behind the head so the head stays exactly on its
point. The child's path is the player's input, which turns as sharply as a key is pressed, and a
thick body folds round a turn tighter than its half-width.

**No body segment is longer than `BODY_MAX_SEG_PX` (2 px)** (`_densify`, after the slither). A Line2D
interpolates per vertex, and on a steep diagonal the 2 px x-sampling put vertices 6-10 px apart, so
the pattern there shimmered ("flicker/jitter, but only on the diagonal parts", user 2026-10-25).

### Width, taper and the breathing pulse

`MOTHER_W` / `CHILD_W` are the base widths (x1.5 on a phone; they were x2, too wide for the curves of
the breath, and the bodies folded at every turn). `width_curve` gives the shape -- a slimmer neck,
the belly fullest a third of the way back, narrowing to `TAIL_FRAC` at the tail ("not so constant in
width") -- and the pulse scales the whole thing between `PULSE_W_LOW` and `PULSE_W_HIGH`.

The body **swells and brightens on the inhale**, driven by `_openness(y, drop)` (0 exhaled, 1
inhaled). It changes nothing geometric, so it cannot reintroduce the artifacts that per-point
offsets caused — and it is the one visual that *means* something: in a breathing game the snake
should visibly breathe. The player's own body pulses from their own position, so it is feedback,
not decoration.

**Brightness rides on `modulate`, not `default_color`.** A Line2D with a gradient ignores
`default_color`; written there it did nothing at all, and a probe "verified" it by reading back the
ignored property.

**Judge width by the MEAN along the body, not the base number** — the taper hides a large fraction
of it.

### Anything spatial must scale with the body width

`MOTHER_W` has been retuned repeatedly (18 → 30 → 80 → 30). Every constant in absolute pixels
silently went wrong each time: a fixed 2 px sample step against an 80 px body is a segment/width
ratio of 0.026. Express spatial constants as a share of body width (the skin tile already is: two
body widths per diamond).

### Slither — vertical displacement only

Amplitude `SLITHER_AMP_W` (a share of body width), one wave per `SLITHER_WAVE_W`, traveling
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

**It fades out where the path is steep** (by the square of the path's horizontal share over ±3
samples). On a steep diagonal a Y shift slides a point ALONG the body rather than across it, so the
body stretched and squeezed under its own bands and the diagonal parts jittered (user, 2026-10-25).
Fading the amplitude keeps the Y-only proof intact; an attempt to fix it by displacing along the
normal again was backed out for the reason above.

### Sampling

Both bodies are sampled at times snapped to a fixed grid
(`t_base = floor(elapsed / dt_step) * dt_step`), walking head-first, never at fixed screen-x.
Snapping the sample *times* keeps each vertex's neighbors constant frame to frame, so the body
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

**A snake's head, seen from above, wearing the body's skin** (2026-10-25, "a bit strange and not snaky
at all"; then "looks awful on mobile"). Filled with the body's scales (`_build_skin(..., false)`: the
same tile without the diamonds, mapped in the head's own space), and on the crown a dark ARROWHEAD with
a pale rim, the first mark of the pattern down the back. It is long
(`HEAD_LEN_W` 1.85), the front half of an ELLIPSE so the snout is round (`_head_half_width`), widest at
the jaw a little behind its middle (`HEAD_JAW_AT` 0.58), then tapering into a neck narrower than the
jaw (`HEAD_NECK_W` 0.60) -- and drawn far enough back (`HEAD_BACK_W` 0.80) that it tapers into the body
rather than ending in a square cut. Small eyes set out at the sides (`HEAD_EYE_R` 0.095), two
nostrils near the snout. It was a short blunt wedge with large eyes, which read as a pentagon.

**The tongue flicks** (`_draw_tongue`): every 1.5-5 s at random, each head on its own clock, a forked
red tongue darts out of the snout and back twice within half a second. The heads redraw every frame
for it (they redrew at 3.5 fps, the old sprite cadence).

**The head turns at its NECK** (`_neck_offset`): the head node is put ahead of the body's front point
by 0.40 of a head-length along the head's angle, so the neck sits on the body's end and the head
swings from there. Centered on that point it turned round its own middle, and its back swung off the
body at every turn ("turns on an axis and briefly doesn't connect").

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
- **The neck overlaps the body's end only slightly** (the head node sits ahead of it, see above), so
  the join reads as one animal from every angle.
- Eyes carry a faint lid ring (`HEAD_EYE_RING`) because a plain black dot loses definition on a
  patterned fill, and a white glint toward the snout. **No blink**: snakes have no eyelids, and the
  blink frame (a quarter of the time) drew the eyes as two dashes.
- **The head's fill and halo are clipped at `HEAD_BACK_W`** (0.80 body widths behind its center),
  the end of its neck taper.

## Environment

- **A lit DUNE FIELD** (`_build_dune_tex`, drawn first in `_do_draw`): diagonal ridges, each a long
  sunlit windward slope rising to a bright crest and a steep slip face behind it in warm shadow, baked
  once into a 384x240 texture that repeats along x (every term is periodic in it, the diagonal tilt by
  a whole-number u term) and drifts at `DUNE_PARALLAX` of the world's speed, one repeat per
  `DUNE_SPAN_W` screen widths. It is the chooser tile's desert, and it replaced a pale flat gradient
  with faint sand patches and barchan crescents that barely read ("make the game background as
  interesting as the icon", user 2026-10-25). Contrast is held moderate so the snakes stay the subject.
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
wear the mother's color, width and head, which made Active mode look exactly like Guided mode
with the mother missing — reported as a bug more than once. It now wears the child's.

**When debugging "I can't see the mother", check `selected_mode` in the save file first.** Probes
written during the Line2D rework all forced `selected_mode = 2` to have a guided path to test, so
three rounds of verification passed while never touching the mode the player was in.

## Heads point the way they are going

Each head's angle is the chord from the body point a third of a body width behind the head to the
head point (`_head_chord_angle`, `HEAD_CHORD_W`): the direction the snake is moving now, smooth because
the path is. History: both heads eased toward the direction at a fixed rate (`HEAD_TURN_RATE`, gone);
then the chord reached back half a head-length, which made the head trail every turn -- twice as far
on a phone, with its wider body ("their heads turn very very slowly").

## Freeze guard in `_do_draw`

`_scroll_px_per_ms` is `screen_w / (1.5 * cycle_ms)`. If it is ever zero, a loop that steps from a
start derived by dividing by it begins at `-INF` and **never terminates** — a hard freeze, not a
glitch. A layout that has not been sized yet is enough to produce it. Checked at the top of
`_do_draw`.

## Thumbnail

`mother/art/game_screen_200.png` is **drawn by `devtools/make_thumbs.py`, `mother()`** (install with
`install_thumbs.py mother`): the mother and her child crossing pale golden dunes on the same wave,
the child just below and behind, in the game's skin -- diamondback scales, the head with its
arrowhead and the neck joined to the body, the tongue out. The sand is pale and cool enough for the
amber mother to stand out (on orange dunes she was "almost invisible"). No text. Earlier tiles: a
screen grab with text, the game's own view, a close-up on flat sand, banded snakes on orange dunes. `mother/docs/make_thumbnail.py` still draws the night scene that was replaced: it is superseded.

**Verification here was structural only.** Headless Godot has no renderer, so a probe cannot see
anything (screenshots from a windowed run, as in the 2026-10-24 look pass, can) — probes confirm points, widths, colors, z-order and
node counts, and those have repeatedly passed on something visibly broken. Add visual features one
at a time and confirm each on a real screen before the next.


## Mother Path

`_phase_y_raw(t_ms, top_y, bot_y)` is the breath itself, and it is **linear**: straight ramps for
the inhale and exhale meeting flat holds. (This doc used to say smootherstep; the code had been
linear for a long time.)

```
if t < inhale_ms:  return lerp(bot_y, top_y, t/inhale_ms)
if t < hold_top:   return top_y
if t < exhale_ms:  return lerp(top_y, bot_y, t/exhale_ms)
return bot_y
```

**`_phase_y_at` rounds its corners**: a raised-cosine-weighted average of `_phase_y_raw` over a window
of `PATH_ROUND_FRAC` (0.25) of the shorter ramp, `PATH_ROUND_TAPS` (17) samples. A symmetric average
leaves a straight line as it is, so the ramps and holds are untouched; each corner becomes a curve
wider than the body. (It was a 0.08 box: curves smaller than the body was wide, so the body folded
round them, worst on a phone, whose taller canvas makes the ramps steeper.) Without it the corners were true kinks -- no sampling density can round one -- and the
mother's body broke at every turn into wedges, its bands not meeting. At a corner the guide moves by
a few px at most; the score comes from the player's breathing rhythm, not from distance to her.
Everything that reads the mother's height (her head, her body, the tutorial's "with her" test) goes
through `_phase_y_at`.

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

---

## Default mode

`selected_mode` ships as `DEFAULT_MODE` (2) — **4-2-4-2**, not Active. Active records
whatever the player does but paces them through nothing, which is the wrong thing to hand
someone who has just arrived: with no pattern to follow there is nothing to do and nothing to
score. Only the shipped default changed; `load_settings()` still overrides it with whatever a
returning player last chose.

The preset list is shared by crack, udbr and mother:

| # | pattern | |
|---|---|---|
| 0 | 4-2-4-2 | the default |
| 1 | 4-7-8-1 | the 4-7-8 relaxation pattern |
| 2 | 4-4-4-4 | box breathing |
| 3 | 5-0-5-0 | no holds |
| 4 | 4-4-8-0 | long exhale |
| 5 | 4-0-8-0 | long exhale, no holds |
| 6 | 4-2-4-0 | |

Menu rows are the bare numbers — `Active`, then `4-2-4-2`, `4-7-8-1`, … The word "Guided" on all
seven said nothing the numbers did not, and ate the width the mono fit-shrinking then had to claw
back. `main_menu.gd` draws the list in the project mono face so the columns line up; that used to
require *every* row to start with a digit, which `Active` vetoed, and now takes a majority.

---

## Skipping the tutorial with the mother hidden

The tutorial takes the mother off screen for three steps (`tutorial_set_mother_visible(false)`) and
puts her back on a later one. A player who pressed **Skip** in between was left in the real game
with no mother body: `new_game()` reset `tutorial_mother_hidden` and re-showed the head sprite, but
never touched the three body `Line2D`s, so the mother ran headed and bodiless.

`new_game()` now calls `tutorial_set_mother_visible(true)` instead of clearing the flag by hand, so
every fresh game restores sprite, body lines and phase label together, whatever the tutorial did and
however it ended. Reproduced and fixed under probe: with the old code the head came back and the
body did not, which is exactly what was reported.

Note that in **Active** mode there is no mother at all by design, so the bug is only visible in a
guided mode — checking it in Active proves nothing.

---

## Session progress bar

The top edge carries the same thin progress bar udbr and breathe use, and for the same reason: it
replaced a digital `m:ss` countdown, which is a number to read and do arithmetic on rather than
something to glance at.

The geometry is identical to those games (`BAR_PAD_X` 24, `BAR_Y` 18, 7 px mobile / 5 desktop) but
the **colors are this game's own**: the fill is `MOTHER_COL` and the track is the same color
darkened, because the cyan udbr and breathe use belongs to their cool backgrounds and reads as a
foreign object on the dunes. Tying it to the mother's color also means the bar belongs to the scene
rather than sitting on top of it.

The `TimerLabel` node is removed from the scene, not just hidden — a node left behind with nothing
setting its visibility simply shows.

The countdown used to sit **above** the goal and phase labels, so removing it left them where the
bar now runs: on desktop the goal line (y 8–46) crossed the bar's band. `_ready()` pushes both
labels down to clear `SessionBar.Y + bar height + 11`, **derived from SessionBar's own constants**
rather than hardcoded, so moving the bar or changing its height cannot silently put them back on
top of each other. It is applied as a *minimum*, so the mobile layout — which already cleared the
bar — is untouched.

Note for anyone measuring this: these labels render ~46 px tall against 38 px offsets, so the goal
and phase **boxes** have overlapped by 4 px since long before the bar existed. The drawn text does
not collide (bands 46–68 and 88–110), which is why it has never shown.

The bar itself lives in **`scripts/session_bar.gd`** (`SessionBar`), shared by udbr, breathe, crack
and mother. Geometry and the alpha policy are shared; **colors are the caller's**, because they are
not a detail — the cyan the three cool-background games use reads as a foreign object on mother's
dunes. `SessionBar.draw_cool()` is the cyan default; mother calls `SessionBar.draw()` with
`MOTHER_COL` and an alpha lift for its lighter background.

---

## The child glows when you are with her

The whole game is "stay level with your mother", and **nothing on screen said whether you were**.
The closeness test (`TUT_WITH_PX`) already existed, but only the tutorial ever read it — during a
real session the player had no feedback at all.

A meter or a number would be wrong in the calmest game in the app, and this design already
establishes that *the ground is dark and the snakes are the light source*. So the child simply
burns brighter as the player holds level with her: `_sync` (0 adrift, 1 level) scales the child's
halo alpha up to `SYNC_GLOW_MUL`, and its halo width with it. Nothing new appears on screen.

Two things that keep it calm rather than twitchy:

- `_sync` **eases** toward its target at `SYNC_FADE` instead of tracking the distance directly.
  Measured, the largest single-frame change is 0.015, so the light breathes rather than blinking at
  the edge of the band.
- Only the CHILD responds. The mother's halo is untouched — she is the reference, and a reference
  that reacts to you is no longer a reference.

Active mode has no mother to be level with, so the glow stays at rest there.

---

## The desert was invisible

The snakes were fine; the environment was not there. Measured from the palette:

| | luminance (of 255) |
|---|---|
| ground | 18 → 30 |
| the three "parallax dune ridges" | 24, 29, 32 |
| mother / child | 168 / 219 |

Eight levels of spread across all three ridges, six to fourteen above the sand. Nothing in that
range is visible on a phone in daylight, so the "night desert" was in practice a black field with
two glowing worms on it — which is exactly how it read.

Three changes, all in the palette block:

- **Ridges are separated.** 37 / 44 / 53 against sand that runs 26 (far) to 47 (near), so each one
  steps clearly off the one behind it.
- **A moonlit crest** along the top edge of every ridge (`DUNE_CREST`, alpha rising 0.16 → 0.30
  toward the camera), with a soft warm bloom falling away beneath it. A filled band is a shape; the
  lit edge where the crest turns away is what makes it a dune.
- **Warm/cool depth.** Far sand is cool violet (r−b = −0.045), near sand is warm (r−b = +0.073).
  The old scheme was one muddy brown at both ends, so distance carried no color information at all.

The snakes still own the screen: 168 and 219 against a nearest ridge of 53.

`mother/docs/make_thumbnail.py` mirrors these constants and has been updated in step, as its own
header instructs — the chooser tile is generated from it.

## The snakes light the sand

The palette is built on "the ground is dark and the snakes are the light source" — but they only
ever carried a thin halo. They lit *nothing*, so the desert stayed uniformly dark however close they
came to it, and the concept existed only in the doc.

`_draw_body_light()` lays a warm pool along each body on the **ground** canvas, so it falls under
the bodies and over the dunes. It is brighter toward the head, because the light travels with the
animal rather than being a uniform strip, and the **child's pool rises with `_sync`** — the light is
the reward for staying with her.

Measured: sand directly under the body is lit 0.20, two body-widths away 0.10, nine widths away
0.00. It illuminates its surroundings without flooding the screen.

It is drawn as **discs**, not a ribbon along the body, for the same reason the crest bloom is drawn
as per-segment quads — see below.

## Flicker along the ridge tops

The first crest bloom was one long ribbon polygon following the wave. That shape is concave, and
Godot re-triangulates it every frame as the dune scrolls; the triangulation flips between frames and
the gradient crawls. It is now **one convex quad per segment**, which cannot be triangulated two
different ways.

Anything that follows a moving curve and is filled has this problem. Cut it into convex pieces.

## The sand has form

Ripples were single hairlines of flat color — on a dark field they read as scratches ruled across
it. Each lit ripple is now a crest with its own shadow beneath it, and both thicken toward the
camera (1.0 px far, 2.6 px near). A ripple is a small dune and is drawn like one.


## Ripple fields

A ripple is not a ruled line across the screen: each runs for a stretch (`RIPPLE_FIELD_SPAN`, its
length and place from its phase) and fades out at both ends, the stretches drifting with the world.
Full-width lines at fixed heights read as lined paper.

## Sound: the wind breathes

One sound, `art/sounds/mother_wind.ogg` (`devtools/make_mother_sounds.py`): a steady desert wind
whose VOLUME follows the breath (`_wind_sound`, `WIND_DB` -17 exhaled to -8 inhaled, eased; it was
-28 to -13, and at -28 a phone plays nothing, so every exhale was heard as a BREAK; the loop is now
mastered by its audible band, and is PAUSED rather than stopped under a card, so it never restarts from
the top) -- the
mother's in Guided mode, the player's own in Active mode -- so the breath can be followed by ear. It
plays only while a session runs. The loop itself is kept steady on purpose: a wind that gusted on its
own would fight the guide. **Volume only, in 0.4 dB steps** (`WIND_STEP_DB`): the pitch followed the
breath too at first, set every frame, and the wind came out choppy.

## What NOT to add

**Wide translucent light pools** cast by the bodies — faithful to "the snakes are the light
source", and completely wrong here: large semi-transparent circles sliding around are agitating, and
this game is meant to relax.

**A sky.** A night sky with a low moon was added over the top seventh of the screen and looked good
in isolation, but it broke the game: on an oblique ground plane the snakes move vertically to go
*toward and away*, and the moment there is a horizon above them the same movement reads as
altitude — they look like they are flying. The design doc's "deliberately not a horizon with a moon"
was load-bearing for legibility, not a matter of taste. Do not re-add it.

## What makes it alive

Three things, none of which fight the ground-plane reading:

- **Tracks.** Each snake leaves a trail: a shadowed trough with sand pushed up below it and scuffs
  across it, fading out `TRACK_FADE_PX` behind the head. Drawn in the same language as the ripples,
  so it belongs to the desert. It also settles what the sky got wrong — a track can only exist on a
  surface, so seeing one behind each animal says "moving across ground", not "flying".
- **Weather.** Everything used to move at one unchanging intensity forever: the bushes swayed by the
  same amount on the first second and the thousandth, so there was nothing to notice. `_gust()` beats
  a 23 s period against an 8.5 s one, so gusts arrive irregularly rather than on a metronome.
  Measured over 100 s it ranges 0.01 to 1.00 — real calms and real gusts. A gust leans every bush
  the same way at once (that shared direction is what reads as wind rather than each bush fidgeting)
  and drags sand streaks across the ground, which only appear above 0.45 so they read as weather
  rather than permanent decoration.
- **The world notices the snakes.** A beetle bolts when a head comes within `BEETLE_SCARE_PX`,
  falling off with distance — measured, 15.9 px of scramble from a snake 20 px away and nothing at
  all from one twice the scare radius off. Nothing in this desert previously took the slightest
  notice of the two animals crossing it, which is most of why it read as scenery rather than a
  place. The player causes it, so it rewards watching.

## The view is DOWN, and everything must agree with that

This is the fault that kept coming back in different costumes. The player moves the child up and
down the screen, and that has to read as moving **across the ground**. Anything implying a horizon
direction turns the same movement into altitude, and the snakes look like they are flying.

Three things did it, each removed in turn:

1. **A sky with a moon.** Obvious in hindsight; looked good alone, wrong in place.
2. **Three horizontal dune ridges with wavy tops.** These were a SIDE view of ridges receding —
   seeing dune *tops* only makes sense from ground level. They were in the original design and were
   the deepest cause.
3. **A top-to-bottom brightness gradient** on the sand, dark at the top and light at the bottom.
   That is a distance cue: from above there is no far and near. Now 6.3 levels of difference where
   there were 21.

What replaced them is top-down by construction: crescent dunes, mottled patches of shade and open
sand, ripple fields, tracks, and props casting short shadows. None of it says which way is "away",
because from above there is no away.

## Color

The palette was one brown at both ends of its gradient — the reason the whole thing read as mud.
Sand is now split by **hue**, not by height: violet shade (`SAND_SHADE`, hue 0.70) against ochre
moonlit sand (`SAND_LIT`, hue 0.07), mottled across the field in drifting patches, with the dune
crests warmer still. The snakes remain far brighter than the brightest sand.

## Fallout from the inversion

Turning a night scene into a day scene inverts every contrast decision in the game, and three were
missed at first — all of them "this was tuned for light-on-dark and is now dark-on-dark":

- **The results buttons disagreed with each other.** `DoneButton` used `TEXT_COL`, which had just
  become dark ink, on its dark brown button; the dynamically-added `Again` button used a pale mint
  green that matched nothing. Both now use `BTN_TEXT`, one light cream, which is the opposite
  problem to text on sand and needs its own constant.
- **The goal and phase lines were illegible.** Dark ink with the old **black** outline is dark on
  dark. An outline exists to separate text from what is behind it, so dark ink needs a LIGHT halo:
  `TEXT_HALO`, 120+ levels clear of the ink.
- **Sand was not yellow enough.** Yellowness (avg(r,g) − b) went 0.274 → 0.392 on lit sand.

## Sand grain

The ground was a perfectly smooth fill, which is what a screen looks like and not what sand looks
like. `_build_grain_tex()` bakes a 96x96 sheet once — half the grains catching the sun, half the
pits between them, because sand sparkles rather than merely being dirty — and it is drawn in ONE
call with `draw_texture_rect_region`, the source rect offset by the scroll so the grain travels with
the world instead of sitting on the glass like dirt on the lens.

`_canvas.texture_repeat` must be `TEXTURE_REPEAT_ENABLED` or the region does not tile and the sheet
is stretched across the whole screen instead.

## What this game measures

Session records are the v6 named-dictionary format (see `scripts/generic_game_util.gd`
and `scripts/session_stats.gd`). Metrics reset centrally in `reset(from_scratch)`.

Declares its own `score_columns`: its array is not the generic shape, and without that its session length would be filed as `level` and its breathing rate as `pct_correct`.

## What counts as a level

Mother Snake has no levels: nothing gets harder and nothing is unlocked. What it has are two
settings the player picks, and **both change what the session is** - five minutes of 4-7-8
and five minutes of 4-2-4-2 are not the same test, and neither are five and twelve minutes
of the same pattern. Before this the sessions were grouped on nothing at all, so the charts drew one
series over everything and the baseline compared one pattern against another.

The level id is the PAIR, encoded by `MotherG.level_id(duration_min, mode)` as
`duration * 100 + mode`. One integer, because the scores window groups on a single column.
`MotherG.level_label()` names it (`5 min - 4-2-4-2`) and `MotherG.mode_label()` handles the two modes
with no pattern to state, `Active` and `Your own`. All three live in `globals.gd` rather than
at the call sites, so the id, its display name and the task signature cannot disagree about
what a session was. They are **copied** from Buoy rather than shared: games in this project
stay independent of one another.

`score_columns` ends `..., mode, level`, `progress_level_pos = POS_LEVEL`, and `new_game()`
sets `task_signature = {duration_min, mode}`.

**These two columns are appended, never inserted.** Rows are positional and
`GenericGameUtil._legacy_row()` stops at the first column a record does not carry, so every
session saved before this change is short. The scores window reads the level through
`_level_of()`, which returns 0 for such a row.

**Splitting by the pair costs sessions per bucket.** A baseline needs five after the warm-up
is skipped, so a player who varies both settings freely will read "not yet" for longer than
one who has a habit. That is correct - those sessions are not the same test - but it is the
reason the seeded demo data gives its player a dominant pair.
