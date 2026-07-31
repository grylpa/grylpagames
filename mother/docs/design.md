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

The palette lives in one block of constants at the top of `level.gd`; the thumbnail generator
mirrors it exactly.

**What it replaced, and why.** The game used to be saturated sand `(0.82, 0.70, 0.46)` under a
near-pure green mother `(0.18, 0.82, 0.22)` and a saturated indigo child `(0.30, 0.25, 0.90)` —
three unrelated hue families at high chroma, nothing receding. Three concrete problems:

1. **It was the only bright screen in "Serenity."** Every sibling is dark and low-chroma: crack
   `0.04, 0.05, 0.09`, river `0.06, 0.18, 0.34`, udbr `0.04, 0.07, 0.14`.
2. **It contradicted itself.** The results panel and the stats graph were already near-black, so
   the palette flipped the moment a session ended.
3. **The child shared no hue with the mother**, so they read as unrelated species rather than one
   animal at two ages. The old doc simply said "Child color: always blue."

Now the ground is dark and warm (`GROUND_TOP` → `GROUND_BOTTOM`, a 24-band vertical gradient,
cooler at the horizon) and the snakes are the light source: mother warm amber `MOTHER_COL`, child
pale gold `CHILD_COL` — same family, separated by lightness. Ripples became light-on-dark
(moonlight on a dune crest); pebbles and bushes are lighter than the ground rather than dark
specks on it. Both head sprites are tinted to their own body colour — the mother's used to be
modulated to pure green, which crushed the art to a flat silhouette, while the child's was not
tinted at all.

### Body shape — Line2D, not hand-built polygons

Two earlier attempts failed, and the second failure is the one worth remembering.

1. **`draw_polyline` at constant width** plus a thinner pale polyline **down the centre**. A centred
   stripe reads as a racing stripe rather than a rounded form, and a constant-width line with round
   caps reads as a cable — the two snakes looked like a logic-analyzer timing diagram.
2. **A hand-built tapered polygon ribbon.** `draw_colored_polygon` triangulates through
   `Geometry2D`, which **fails and draws nothing** on a self-intersecting polygon — and an offset
   ribbon self-intersects wherever the path turns sharper than its own half-width. A fold therefore
   does not render a knot, it renders **nothing**: the mother (steep guided path, wide body)
   disappeared entirely and the child flickered as folds came and went while scrolling.
   The fold probe that cleared this change tested a gentle sine and a coarsely-aliased sample path,
   so it missed the real geometry. If you test for folds again, test the **actual** guided path at
   the **actual** body width.

The bodies are now `Line2D` nodes, which solves all of it in the engine:

| need | Line2D |
|---|---|
| robust tessellation | built in — nothing here can fail to triangulate |
| rounded turns | `joint_mode = LINE_JOINT_ROUND`, `round_precision 12` |
| taper | `width_curve`: 1.0 at the head → `TAIL_FRAC` at the tail |
| scales + roundness | tiled `texture` (`LINE_TEXTURE_TILE`) |
| rounded nose/tail | `begin_cap_mode` / `end_cap_mode` ROUND |

**Points must arrive head-first.** `Line2D` samples `width_curve` from `points[0]`, so the guided
mother path — built left-to-right — is reversed before being handed over, or the taper comes out
backwards.

**Appearance is currently PLAIN — deliberately.** The body is a Line2D with `default_color`,
round joints and caps, a `width_curve` taper, `antialiased`, and a `gradient` for the tail
dissolve. **No texture, no shader, no undulation.** With no texture assigned Line2D emits no UVs
at all, so no UV-derived artifact is even possible.

This is a baseline reached after three attempts to make the body fancy, every one of which broke
*at the turns*, and none of which could be checked here — headless Godot has no renderer, so
nothing visual is verifiable in this repo, only structure:

1. **Tiled bitmap skin** (`LINE_TEXTURE_TILE`). A tile is cut off wherever the line ends, so the
   round end cap drew partial diamonds at the base of the head; and round-joint fans interpolate
   UV across triangles that are not a straight run of body, smearing the pattern at turns.
2. **Analytic shader skin.** Removed the tiling seams but broke two subtler rules: lighting that
   depended on the **sign** of UV.y flipped to the other edge wherever a joint fan emitted
   mirrored UVs (reported as the body going "photographically negative"), and `fwidth()` of a
   `fract()`-derived value spiked at every wrap, collapsing the lattice into dark blotches.
3. **Lateral slither.** Offsetting each point along its local normal by ~6 px is safe on a
   straight run and not safe at a turn, where the normal rotates through nearly 180° between
   samples 2 px apart — the offset points cross over and the path tangles itself, exactly at the
   breaks.

**Add nothing back without looking at it.** All three were structurally verified and reported as
fixed, because structural checks cannot see a rendering artifact. Re-add one feature at a time and
confirm visually before the next.

### The one thing added back: the breathing pulse

The body **swells and brightens on the inhale and settles on the exhale** — `width` scales between
`PULSE_W_LOW` and `PULSE_W_HIGH`, and `default_color` brightens by `PULSE_LIGHT`, both driven by
`_openness(y, drop)` (0 fully exhaled at the bottom of the range, 1 fully inhaled at the top).
The shadow line's width tracks the body's.

Chosen over every other candidate for two reasons. It **changes nothing geometric** — only `width`
and `default_color` — so it cannot reintroduce what offsetting points along their normals did at
the turns. And it is the one idea that makes the visuals *mean* something rather than decorate: in
a breathing game the snake should visibly breathe.

The player's own body pulses from their own position, so the swell is direct feedback on their
breath, not just an animation playing alongside it.

Measured: openness spans 0.02–1.00 over a cycle, mother width 15.9–20.5 px against a base of 18
(bounds 15.8–20.5), worst per-frame width step 0.013 px — far below anything that could strobe.

### Skin: bands + a dorsal stripe

Added after the pulse, once the plain baseline was confirmed clean. Both parts are drawn on the
**identical path** as the body, so their joints behave exactly as the body's do — no normals, no
offsets, no UVs, which is what every failed attempt needed.

- **Bands** come from the `Gradient`: alternating base / `BAND_DARK` stops along the line,
  interpolated per-vertex by the engine. The tail dissolve is folded into the same gradient.
- **The dorsal stripe** is a narrower Line2D (`STRIPE_W` of the body) on the same points, lighter
  by `STRIPE_LIGHT`. Being narrower, its round joints sit *inside* the body's at every turn.

**`Line2D.gradient` REPLACES `default_color`, it does not multiply it.** The pulse's brightness was
originally written to `default_color`, where a line with a gradient ignores it completely — so
half the pulse silently did nothing, and the probe "verified" it by reading back the property that
was being ignored. Per-frame brightness now rides on `modulate`, which does multiply.

**The band count is keyed to the body's HORIZONTAL SPAN, not its arc length.** Gradient offsets are
normalised, so whenever the count changes every band shifts a little — which reads as the pattern
crawling. Arc length oscillates as the breath steepens the path: measured, 19 rebuilds per 700
frames on the mother. Horizontal span is constant for the mother and grows monotonically for the
child, giving 0 rebuilds for the mother and rebuilds only while the child's body is still growing.

### The child's tail: starts long, grows slowly

The child's body length used to be whatever history existed — zero at session start, full in ~12 s.
So every session opened with the tail visibly stretching, and the pattern renormalising while it
did. Now it starts at `CHILD_START_LEN_PX` and lengthens at `CHILD_GROW_PX_PER_MS` (~40 s to fill
the screen). `_prefill_history` seeds the ring buffer with a flat run at the starting position, so
the opening tail is made of ordinary history samples and is drawn by exactly the same code path.

**Bands are anchored in PIXELS from the head**, not as equal fractions of the body: `offset =
distance / length`. A band 100 px back stays 100 px back as the body grows, and only new bands
appear at the tail. Splitting 0..1 into equal fractions instead moved *every* band slightly each
time the length changed — that was the growth jitter.

**The gradient is keyed to the smooth growth cap, not the measured span.** The snapped-time
sampler quantises the tail to the 2 px sample step, so the measured span oscillates by up to one
step every frame (132 shrinks per 900 frames, measured); feeding that in would put the wobble into
the pattern. The tail *tip* still moves those 2 px, where the alpha ramp has already faded it to
nothing. Measured after: band #3 holds 18.6–19.3 px from the head across the whole growth.

### Heads turn gradually

Both heads ease toward the current direction at `HEAD_TURN_RATE` via `lerp_angle`. The body's turn
is smootherstep-eased, so a head snapped to the instantaneous tangent looked mechanical against
it. The mother's was previously set straight from her phase velocity with no smoothing at all; the
child's was smoothed at rate 20, fast enough to read as instant. Measured: the mother swings 94°
over a cycle at no more than 1.95°/frame.

Still deliberately absent: any per-point offset, any UV-derived shading, any tiled texture.

### Layer order

Ground canvas (z 0) → body shadows (z 1) → bodies (z 2) → props canvas (z 3) → heads (z 5/6).
The props canvas exists because bushes and beetles are deliberately drawn **over** the snakes so a
snake passing behind a bush reads as being on the ground; once the bodies became Line2D nodes
rather than canvas draws, the props needed their own canvas above them.

### Freeze guard in `_do_draw`

The phase-transition marker loop steps by `_cycle_ms` from a start derived by dividing by
`_scroll_px_per_ms`. **Either being zero makes that start `-INF` and the loop never terminates** —
a hard freeze, not a glitch. `_scroll_px_per_ms` is `screen_w / (1.5 * cycle_ms)`, so a layout that
has not been sized yet is enough to produce it. Both are now checked at the top of `_do_draw`.

### Thumbnail

`mother/art/game_screen_200.png` is generated by a PIL script that mirrors this drawing code
(palette constants, `smootherstep` path, `taper_poly`), so it cannot drift from the game. Two
things it does differently on purpose, both because the thumbnail is proportionally much smaller:
the dry bushes are drawn as **upward tufts** rather than the game's full radial spikes (a radial
burst at 200px reads as a sparkle, and one placed high reads as a star), and the heads are drawn
larger — the old thumbnail's heads were tiny white dots that vanished, which is a large part of
why the paths read as a diagram rather than as animals.

It approximates `Line2D` as a run of overlapping discs, which is effectively what a round-jointed
Line2D is. Two details matter there: the dark rim must be a **separate silhouette pass** (a
per-disc outline beads the edge and makes the body read as rope), and the skin must be
**low-contrast** (a strong lattice at 200px also reads as woven rope rather than scales). Both
were wrong on the first attempt.

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

## Key Pitfalls

- `_analyze_trace()` needs at least ~2 complete breathing cycles to detect the period (autocorrelation threshold 0.15). Short sessions or no movement return `valid=false`.
- Mother path uses smootherstep, not smoothstep — ensures C2 continuity (no velocity jump at hold boundaries).
- History ring buffer has a 4-slot warm-up: body is not drawn until 4 slots are populated.
- The child body (and the active-mode mother body) is sampled at times snapped to a fixed grid (`t_base = floor(elapsed/dt_step)*dt_step`, `dt_step = step/scroll_px_per_ms`), not at fixed screen-x. Sampling at fixed screen-x makes sharp trail vertices (up→down with no hold) alias and jitter as they scroll, because the peak drifts between sample points each frame. Snapping the sample times keeps each vertex's neighboring samples constant frame-to-frame, so the trail scrolls smoothly. The guided mother path avoids this differently — it inserts exact vertices at the known phase-transition times (`_extra_xs`).
