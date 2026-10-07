# Lighthouse (folder `lighthouse`) — design

A boat crosses a dark sea at night, from the bottom center to a pier at the top center. Nothing in
the sea can be seen except where light falls on it: a lighthouse in the middle sweeps a beam round,
widening as it goes out, and the boat carries a small light of its own. Rocks, wrecks and cliffs show
only in slices as the light passes over them, so getting across is remembering where they were. The
view is top-down: the lighthouse is seen as its head from above (gallery, lit lantern, red cap).

## Files

```
lighthouse/
├── scripts/
│   ├── globals.gd        LighthouseG autoload: starting level (saved), the lifebuoy HUD icon
│   ├── level_config.gd   LighthouseLevelConfig: the level table (see below)
│   ├── main.gd           orchestrator: menu, HUD, instructions, score row
│   └── level.gd          the sea, the light, the boat, input, the round flow
├── scenes/  main.tscn (Level, HUD, GameTick, Help), level.tscn (a CanvasLayer; all UI built in code)
└── art/game_screen_200.png   the chooser tile
```

## Levels -- `level_config.gd`

Distances and speeds are in units of a 680-wide sea, scaled to the real one (`_k`).

| key | meaning |
|---|---|
| `obstacles` | how many rocks, wrecks and cliffs |
| `obstacle_size` | their typical radius; **smaller is harder** -- a small thing seen for a moment is harder to remember |
| `beam_turn_deg` | the beam's turning speed, degrees a second |
| `beam_width` | the beam's width where it reaches the far edge of the sea (it widens from the lamp) |
| `boat_light` | how far ahead the boat's own light reaches |
| `boat_speed` | the boat's speed |
| `rounds` | crossings per level |
| `boats` | how many other boats cross the sea, slowly, edge to edge (0 for none) -- see "Other boats" |
| `round_sec` | each round's time limit; a round whose time runs out is lost, and the level goes on to the next |
| `same_sea` | true: every round on the SAME sea, so what one round showed helps the next; false: a new sea each round |
| `max_crashes` | the most crashes the FIRST round can take: the HUD's lifebuoys count them down, and the crash that reaches the maximum loses the round. **On a same-sea level each later round allows one fewer, never below 1** (`max_crashes_for`) -- the sea has been seen. It drops after a failed round too: a round lost to crashes showed exactly where the rocks are, and a limit tied to success would make failing the way to an easier round. On a new-sea level every round allows the same |

**What the player reads says "crash"**, never "collision" or "hit" (the round card's "Max crashes" -- that
round's number -- "Max time"; the summary's "Crashes"). The
code and the saved records keep `collisions`.

**Passed** (`passed()`): every round reached the pier (none lost to crashes or to its clock). How much
faster the crossings got is what is measured and charted, not a condition. (An earlier rule also
capped the last round's crashes; it is gone -- the decreasing crash limit does that job round by
round.)

| level | obstacles / size | beam turn / width | boat light / speed | rounds / time a round | same sea | max crashes (first round) | boats |
|---|---|---|---|---|---|---|---|
| 1 | 6 / 34 | 50 / 230 | 150 / 105 | 3 / 60 s | yes | 3 | 0 |
| 2 | 8 / 30 | 46 / 200 | 140 / 110 | 3 / 60 s | yes | 3 | 0 |
| 3 | 10 / 28 | 42 / 180 | 130 / 115 | 3 / 65 s | yes | 3 | 1 |
| 4 | 10 / 26 | 40 / 170 | 120 / 120 | 4 / 60 s | no | 3 | 1 |
| 5 | 12 / 24 | 36 / 160 | 110 / 125 | 4 / 65 s | yes | 2 | 2 |
| 6 | 14 / 22 | 34 / 150 | 100 / 130 | 4 / 65 s | no | 2 | 2 |
| 7 | 16 / 20 | 30 / 140 | 95 / 135 | 4 / 70 s | yes | 2 | 3 |
| 8 | 18 / 18 | 28 / 130 | 90 / 140 | 5 / 70 s | no | 2 | 3 |

## The dark and the light -- `level.gd`

**Lighting does the hiding.** The sea, the obstacles and the pier are drawn in their own CanvasLayer
(`_world_layer`, layer 0) under a near-black `CanvasModulate` (`NIGHT`), and `PointLight2D`s light
them. `NIGHT` is ~1-2% on purpose: at a few percent, pale rock stayed a shade above the sea and every
obstacle showed as a faint silhouette in the dark.

- `_beam`: a wedge texture (`_beam_texture`, 256 px, scaled up) rotated about the lamp. It is narrow
  at the lamp and widens outward; `texture_scale` makes it reach the sea's farthest corner and a
  y-scale sets its width at the edge to `beam_width`. Its sides fade over the outer third of its
  half-width, and it turns smoothly, so a lit thing fades in and out as the beam passes -- **there is
  no afterglow**. It lights everything in its way, not just the nearest thing.
- `_boat_lamp`: a cone at the bow (`_cone_texture`), bright at the boat and fading to nothing at
  `boat_light`.
- **Only those two are lights.** The faint glows round the lantern, the boat's lamp and the green
  harbor light are soft additive sprites drawn just above the dark layer (`_draw_glows`), not
  PointLight2Ds. Five moving lights was the likeliest cause of jitter on a phone: a 2D light costs per
  lit pixel of every item it touches, the beam covers most of the screen, and every extra light
  multiplied that. The lighthouse's rock has a SOFT edge fading into the water: a hard disc with a
  foam ring, lit evenly, read as a sharp ring instead of a glow.

Anything in that layer is seen exactly where, and as much as, light falls on it; "partially seen" is
not computed. What must always be visible -- the lighthouse head, the boat, the drawn route, the crash
ring -- is drawn in the level's own layer above, untouched by the CanvasModulate. Because the dark
layer is a CanvasLayer of its own, hiding the level does not reach it: `visibility_changed` mirrors
it.

**The pier** at the top center, close to the top edge: a narrow plank walkway from the edge and a
wider landing across its end, with piles and two mooring posts. It is in the dark layer too, so it
shows only when light falls on it -- but a small **green harbor light** at the landing's end is always
visible (drawn in the overlay, with a faint green glow of its own, `_draw_glows`), so the goal is
known in the dark. It is **occulting** like a real harbor light -- the "Oc G 4s" of the charts: lit for 2.5 s,
then a 1.5 s dark break, every 4 s (`harbor_flash()`, `HARBOR_PERIOD`, `HARBOR_DARK`).
The break dips to a faint glow (`HARBOR_DIM`) rather than to black, so the goal is never lost. A
short flash with long dark gaps, tried first, left it dark most of the time. (The first version was a plain plank rectangle far down from the edge, which read
as one more obstacle.) A crossing ends when the boat **touches** the pier (`touches_pier()`: its bow
inside the walkway or the landing, or its hull's circle over an edge). An earlier distance to a point
below the landing said "docked" a boat-length short of the planks. `_dock`, just below the landing,
is only the approach that obstacles are kept clear of and the way-through search aims at.

## The sea

**Waves** (`_draw_waves`, their own node between the sea's fill and everything on it, redrawn every
frame): small crests, one per ~1800 px^2, that drift to the right at 14-26 units a second (wrapping
round), bob, and swell and fade each on its own phase -- a shallow lit arc with a faint trough under it. Being in the dark
layer, they show only where light falls: the beam and the boat's light find a moving sea.

`_build_sea()` places the obstacles (`_try_layout`): clear of the start, the pier and the lighthouse
rock, apart from each other by more than a boat's width, and checked by `has_way_through()` -- a grid
search at a boat's width from the start to the pier. A blocked layout is drawn again (40 tries, then
one obstacle fewer). Kinds: a **rock** (an irregular polygon with a lit top face and foam), a **wreck**
(a broken hull with deck planks and a fallen mast), a **cliff** (a long ragged ridge, 1.35x the size).
The lighthouse's rock in the middle is an obstacle too -- the straight way up runs into it.

`same_sea` false: a new layout at the start of every round after the first.

## Other boats

`boats` per level, any number. Each has its **own route** across the sea, found once when the sea is
built (`_build_traffic`): an `AStarGrid2D` over the sea, a cell solid where a boat there would touch an
obstacle, the lighthouse or the pier (with a boat's width of clearance); the boat starts at a random
height on one edge -- in the top two thirds of the sea, never the bottom third, where the player's
boat sets off -- and the search finds its way to the other. So a route is **straight where the sea
is clear and curves round whatever is in the way** -- a boat can never meet an obstacle, the rocks are
placed freely, and there is no limit on the number of boats. A route runs off both edges, so a boat
sails in and out of sight, and starts again from its beginning. The boat follows it turning smoothly
(1.6 rad/s), at 22-34 units a second, drawn turned along its course (`heading`).

**Painted hulls in cool colors** (`TRAFFIC_HULLS`): teal, blue, violet, magenta, one per boat in turn.
The beam's light is warm, and in it yellow and orange went brown like the wrecks (tried, rejected); the
first boats, dark red with a buff deck, did the same. **Drawn in 3-D** like the player's boat: the same
curved hull (`hull_at`), a shadow on the water, a darker band along the side away from the light, a
lighter deck with a white stripe, a rim, and a white wheelhouse whose dark side shows beneath its lit
roof so it stands up off the deck. (Flat, they looked like paper boats.)

They are in the dark layer like the rocks: seen only where light falls (`_mark_traffic_seen`). Bumping
into one is a crash (`hit_at` returns `TRAFFIC` + its index; an oriented-box test,
`_touches_traffic`), with the same one-crash-until-clear rule. The round card always says how many: "Other boats: 2", or "Other boats: None". A boat with the player's boat just ahead
waits -- the other boats never ram -- and so does the later-numbered of two boats about to touch.

Rejected: horizontal lanes reserved before the rocks were placed -- they bent the rock layout round
them and capped the number of boats -- and lanes searched for after placing the rocks, which found no
clear band on most levels.

**Waves** drift at 14-26 units a second, bob and swell faster than at first (the player's call).

## The boat

**How it looks** (`_draw_boat`, `_hull_outline`): a small motorboat seen from above -- a hull whose
sides curve out from a pointed bow to its widest point and run back to a flat transom, a white rim
round a wooden deck with planks along it, an open cockpit aft with a windscreen, the outboard motor off
the transom, the lamp at the bow, and a short soft V of wake fading behind it while under way. Its
length is `BOAT_LEN` 40 units (it was 30 -- a speck on a phone), and its collision radius is 0.3 of
that.

**Everything in the sea is bigger on a phone** by `MOBILE_SCALE` (1.35, `_s`): the boat (54), the rocks,
wrecks and cliffs, the other boats (`_traffic_len`/`_traffic_wid`), the pier and the lighthouse rock --
and every clearance measured from them follows, since it is computed from those sizes. A 680-wide
canvas is a hand's width on a phone. The phone's sea is also much taller (about 930 units against 560),
so every level still fits: checked five times a level at phone size, with full counts and always a
way through. (Drawn first as a straight-sided body with a short
neck and a block in it: from above, a bottle.)

Continuous, never on cells: a position, a heading, a speed. It steers by **pure pursuit**: it aims at
the point `LOOKAHEAD` further along the line from where it is (`_along_route`), a point that slides
along the line as the boat goes. It turns at most `TURN_RATE` (3.2 rad/s), slows for a turn and turns
in place when the line is more than 60 degrees off the bow, and its **speed eases** (`_pace`,
`PACE_EASE`) toward what the course allows instead of being set outright each frame. A route is taken
from its point NEAREST the boat, never back to where the finger went down. History: aiming at the
drawn points one after another (8 px apart) made the wanted heading -- and with it the speed -- jump
at every point of a wobbly hand-drawn line, a stop-and-go stutter at any frame rate; and a boat that
did not turn in place sailed ahead off a fresh line and looped back to it. `probe_lighthouse` checks
it keeps within 14 px of a line drawn from beside it, and glides along a wobbly line with no stalls
and no frame-to-frame lurch in speed. The sea's edges are walls it slides along.

**Input** (mouse button and motion only; touch is emulated as mouse), taken in `_unhandled_input`, so a
touch any button, card or screen claims never reaches the sea -- with `_input` the sea saw every
touch first, and a tap on the hamburger or a card's button was also a tap on the sea. The sea also
stops above the app's bottom bar (it reached 7 units under the hamburger):
- a **drag** draws a route, shown as a gold line from the boat that shortens as it is sailed. The
  finger's points (thinned to 8 px) are turned into a **smooth curve** (`smooth_line`: a centripetal
  Catmull-Rom spline through every reported point, resampled every 4 units) for the line on screen
  and the route alike. The screen reports a finger only so often, so a quick circle arrived as a
  handful of points; joined straight, it was a polygon the boat turned sharply at every corner of;
- a press arriving within `RESUME_MS` (300 ms) of a drawn line's release, within `RESUME_PX` of where
  it ended, **continues that line**: a phone sometimes reports a finger as lifted and pressed again in
  the middle of a drag, and the line used to vanish and restart from the finger. A second press while
  one is down is ignored;
- a **tap on the sea** sails straight there;
- a **tap on the boat** stops it: within `STOP_TAP_R_MOBILE` (52 units) on a phone, `STOP_TAP_R_DESKTOP` (36)
  with a mouse, of where the boat was at the touch or at the lift, whichever is nearer (`on_boat`). It
  was 0.9 of a boat length from where the boat was at the lift: a finger covers about 90 units and the
  boat keeps sailing, so most stop taps missed and sent the boat to the tap instead;
- **arrow keys**: left/right turn, up sails ahead, down (or stop) stops. Steering by key drops a route.
  **Read from real key presses only** (`_keys`, from InputEventKey). The app turns every drag into
  swipe steering -- simulated left/right/up/stop ACTIONS (`MainGlobals.sim_action`) -- unless a game
  switches on the shared path mode, as wolves and storm do. Lighthouse draws its own free route with
  that mode off, so reading the actions obeyed the steering fired by the very drag drawing the route:
  "up" dropped the route and sailed ahead, "left"/"right" wiped the line and turned the boat. That was
  both "the boat sails off ahead of my line" and "the line vanishes while I draw".

**A collision** (`hit_at`: the boat's circle against each obstacle's polygon, or the lighthouse rock)
puts the boat back where it was, stops it, flashes a red ring, plays the crash sound
(`art/sounds/car-crash-1.mp3`, as Pneumo's crashes) and costs a lifebuoy; 0.7 s of grace
follows. **Crash timestamps are forgotten at every round** (`_forget_crash_times`): the grace
(`_invuln_until`) and the crash ring (`_crash_t`) are stamped on `game.game_time`, which starts again
at every new level and new game. Kept across a restart they lay in the clock's future: no crash
counted at all for as long as the last level had lasted, and the ring, drawn from a negative age,
was a big red circle shrinking to a dot. The ring is also never drawn for a time not yet reached.
**One crash per obstacle until the boat has left it**: touching the thing it last crashed
into (`_last_crash`) blocks and stops the boat but is not another crash, until the boat has been
`CRASH_CLEAR` (22 units) beyond its own radius away from it -- a boat nosing along a rock it has just
hit used to rack up a crash every 0.7 s. The collision that takes the LAST lifebuoy loses the round
(the HUD at 0 means the round is over -- an earlier "0 left, one more allowed" read as a bug).

**The gesture is reset** (`_reset_gesture`) when a round starts or ends, when a level starts and when
it stops, and a button release is taken in every phase. A release that landed during a card used to
be lost, so the next round thought the finger was still down: the old line reappeared and plain mouse
motion went on drawing.

**Seen.** `_mark_seen()` marks an obstacle the first time the beam (the angle to it within the beam's
half-width there) or the boat's light (within its cone and reach) is on it. A collision with
something already seen is counted apart (`collisions_seen`): a memory slip, not a hazard nobody
could have seen.

## A level

Phases: `IDLE` -> `PLAY` -> `ROUND_OVER` (a second of "Docked!" / "Ran aground" / "Time's up") ->
`ROUND_CARD` (this round's summary, then the next round's card; closing that starts the round) -> `PLAY` ...
and after the last round, `DONE`. The time bar is the round's own clock, and runs only while sailing.
The level card lists every round in SHORT rows -- "40 s, 1 crash", "3 crashes, lost", "out of time" (a row
like "too many crashes, 3 crashes" stretched the card past a phone's width) -- the rounds that
reached the pier and the total crashes; past six rounds, five to a row.

**The HUD's lives slot** holds the round's lifebuoys, with a lifebuoy icon
(`LighthouseG.buoy_icon()`, baked at 64 px, shown at 32 in its own colors).

## What is recorded

The score row (`score_columns`): `didwin, aborted, level, last_round_ms, collisions, rounds_played,
rounds_won`.

- `last_round_ms` -- the last round's crossing time, **only when it reached the pier** (0 otherwise;
  the Speed tab skips a 0). The same time goes in the metrics as `crossing_ms` only when there is one.
- `collisions` -- in the whole level
- metrics: `round_times_ms` and `round_solved` (every round -- the Charts tab's "Rounds" chart, shared
  with Mosaic, `GameInstrument.ROUND_GAMES`), `round_collisions`, `collisions_seen`, `first_round_ms`,
  `rounds_allowed`, the won rounds' times as a `round_*` block
- task signature: every level value

The Summary shows Time to reach the pier (last round) and Collisions. Points: 30 for reaching the pier,
plus up to 20 less 5 a collision.

`devtools/probe_lighthouse.gd` checks every level's sea (obstacles placed, clear of the start, the pier
and the lighthouse, a way through), a route sailed as drawn to the pier, the boat keeping to a line drawn from beside it (no
overshoot, no loop), the next round back at the start, a collision (stops the boat outside the rock, costs a lifebuoy; losing the last one loses the
round), the gesture reset after a round, seen and unseen collisions, same sea and new sea, the beam and the boat's light marking things
seen, the pass rule, the briefing, the round card, and the real input (a drag draws a route, a tap on
the sea goes there, a tap on the boat stops it). `devtools/seed_demo.gd` seeds its history.

## The chooser tile

`art/game_screen_200.png` is drawn (`devtools/make_thumbs.py`, `lighthouse()`): a whole red-and-white
lighthouse on its island at night, foam at the waterline, its beam sweeping out over the
sea, stars and a crescent moon. No boat. The tower is projected from its 3-D form -- every circle of
it an ellipse of one squash, the bands curving with it, shaded by the angle round it. Its head is
built the way a real one is: the tower top flares out (a corbel) to carry a flat gallery slab with a
railing, the lantern is a glass CYLINDER with mullions, and the cap is a low cone of DARK METAL, not
red. The island is ONE mound of pale, moonlit stone with a flat top (an ellipse of the tower's own
squash), light enough to stand out from the dark sea and from the tower, and the tower rises from a
stone plinth on it. Earlier versions read as a snowman (a round dome on a round lantern on a floating
oval) and stood on a dark cluster of boulders that vanished behind the tower when small.

## The card before every round, and the instructions

**The help screen never opens over a card** (shared `scripts/help.gd`). The hamburger opens it, and
it shares the cards' layer: opened over a round card, the card was drawn on top but the help screen
took every touch, so the card's button did nothing. It now refuses itself while a card is up -- on
the next frame: hiding it from inside its own visibility signal left it invisible but still catching
touches. (A tap on the hamburger while a card is up lands on the card's backdrop, which closes the
card as Continue would.)

**Two cards between rounds.** First the **summary** of the round just played (`summary_title`,
`summary_text`): "Round 1 complete" or "Round 1 failed" -- the title gives the card its gold or warm
look and a Continue button -- with the result (docked / out of time / too many crashes), the time and
the crashes. Then the **next round's card** (`round_title`, `briefing_text(k)`), the same card round 1
opens with: obstacles, same sea, **that round's own crash limit** and its time. Facts only, short
ones (the table is as wide as its widest row, and a long row pushed the card off a phone).
How the game is played is the instructions screen's
(`set_instructions` in main.gd) and the tutorial's.

## Tutorial

`lighthouse/scripts/tutorial.gd`, entry `main.gd::start_tutorial()`, level 1, in `MainCfg.tutorials`.
Eleven steps: the beam shows things only while it is on them; the green light marks the pier;
draw a route (a demo, then the player's own); tap the boat to stop; tap the sea to go there; the
lifebuoys; a real crossing to the pier (explained on a paused card, then sailed under a one-line caption kept off the boat, the lighthouse and the pier); and last, that the sea is often the same every round, so
remember it. In tutorial_mode the level's clock does not run and a lost round simply starts again.
`devtools/probe_tut.gd` drives it (`_act_lighthouse`) and checks the freeze (the beam and the boat
stand still while a caption is up).
