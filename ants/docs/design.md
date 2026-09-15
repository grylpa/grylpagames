# Ants — design

A colony simulation. There is no task for the player yet: you watch ants leave a nest, find food
they were never told the location of, and wear a trail between the two. Everything the colony does
emerges from one ant's local rules — nothing anywhere plans a route.

**Status: not yet a game.** What it will ask of a player is undecided, so it measures nothing and
saves nothing (see *Scoring*, below). The category in `MainCfg.games` is provisional.

## Files

| File | What |
|---|---|
| `scripts/globals.gd` | `AntsG` autoload: the `GenericGameUtil` and the settings |
| `scripts/level_config.gd` | `AntsLevelConfig` autoload: world size, colonies, speed range, populations |
| `scripts/main.gd` | the standard orchestrator (menu, HUD, instructions, help) |
| `scripts/level.gd` | the world rect, the camera, the colonies, the tick, and all the drawing |
| `scripts/colony.gd` | `AntColony`: a nest, its ants, and **its own** scent field |
| `scripts/ant.gd` | `Ant`: one ant's state and one tick of its sensing and movement |
| `scripts/scent_marks.gd` | `ScentMarks`: the trail, as points rather than cells |
| `scripts/ant_grid.gd` | `AntGrid`: sparse spatial hash, for "who is next to me" |
| `scripts/ants_art.gd` | `AntsArt`: soil, nest, food, trail and ants, all drawn |
| `scripts/tutorial.gd` | a placeholder, deliberately not wired up |

`Level` is a bare `Node2D`. There is no board, no cell and no tile: the world is a `Rect2` in world
units and an ant's position is a `Vector2` anywhere inside it.

## The world

`"world": [x, y]` in the level config is a **multiple of the 680-unit screen width** — `[1,1]` is
680×680, `[10,10]` is 6800×6800. Nothing in the simulation is sized against the world, so there is
no hard cap; a bigger number costs only what the extra ants and longer trails cost.

The camera fits the world to the screen, but **only down to `MIN_ZOOM` (0.42)**. A 10×10 world fits
at zoom 0.1, where an 11-unit ant is one pixel and there is nothing to watch; past the floor the
camera shows part of the world, starts on colony 0 and pans by drag. Level 1 is 1×1 precisely so
that the whole world *is* the screen and nothing has to be panned to see the trail form.

## Why the scent field has no grid

The textbook pheromone implementation is a raster: an array of cells over the world, each holding a
concentration, with an ant reading its neighbours for a gradient. It was rejected for two reasons.

1. **It quantises the field.** An ant crossing a cell boundary gets a step change in what it
   smells, and steers in visible little jerks. The movement here is meant to read as real.
2. **It allocates the world.** A 10×10 world is 722,500 cells at 8px, every one of which has to be
   evaporated ten times a second whether an ant has ever been near it or not.

So a mark is a **point** — a real position and a strength, dropped where the ant actually was.
Sensing sums the marks within `SENSE_R` (26 units) of the sample point, weighted linearly by
distance: a smooth scalar field with no cells in it, sampled at whatever arbitrary point an antenna
happens to be. Cost scales with **ground walked**, not with world area, which is why the same code
serves 1×1 and 10×10. The `Dictionary` inside `ScentMarks` is a lookup accelerator that decides
which handful of marks are worth measuring; it never rounds a position or a strength.

Two details keep the store bounded:

- **Merging.** A drop within `MERGE_R` (6 units) of an existing mark strengthens it instead of
  adding another. Without it a trail walked for ten minutes holds ten minutes of marks; with it a
  well-used trail holds a fixed number that simply grow stronger — which is also the behavior
  wanted, since strength *is* the recruitment.
- **Saturation.** `MAX_STRENGTH` caps a mark, so one trail cannot out-shout every alternative
  forever.

The falloff is linear in distance, not in distance squared. A squared falloff is nearly flat across
most of the sensing disc, and a flat field carries no gradient for the ant to read.

## What one ant does

`SEARCHING` → (reaches food) → `HOMING` → (reaches nest) → `SEARCHING`.

**Outbound**, the ant asks one of two different questions depending on where it is standing.

*Off* a trail it climbs a slope: three samples ahead of its head (±0.55 rad, 17 units out), turning
toward the strongest, proportionally — a faint difference gives a faint correction. Below
`FOLLOW_THRESHOLD` the field is noise and the ant explores. Exploration is **correlated**: a wander
bias that eases toward a new random value rather than being redrawn each frame, because redrawing
per frame gives a jitter that reads as a bug.

*On* a trail it follows a **ridge** instead, and this is a genuinely different problem. Three
antennae 32° apart can climb a gradient but cannot recognize a ridge: an ant crossing an
established trail at right angles reads the same strength left and right the whole way over, gets
no turn at all, and walks straight across a road its entire colony is using. A ridge has no slope
along it and a symmetric slope across it, so there is nothing for a gradient-follower to find.

So an ant standing on a trail (`sense(pos) >= JOIN_SCENT`) stops asking about slope and asks which
way the thing *runs*: it fans nine rays across ±100° of its heading and takes the strongest. The
arc is limited so a crosser swings onto whichever end it was already facing rather than doubling
back — which is also what keeps the two streams on a trail from collapsing into one.

Two details matter more than they look:

- **The peak is refined between rays.** Nine rays across 200° quantize the answer to 0.44 rad, and
  re-picking one every `JOIN_EVERY` made an ant on a trail weave between two of them. A parabola
  through the peak and its neighbours gives a bearing that moves continuously as the ant does; the
  measured worst turn in the colony fell from 5.38 to 4.11 rad/s when this went in. A weighted mean
  of all nine rays cannot be used instead — a crosser sees **both** ends of the trail inside the
  arc and they would cancel.
- **The two ends smell identical**, so something has to break the tie. The ant's own reckoning
  does: a forager wants the end away from home and already knows which that is (`JOIN_AWAY_BIAS`).

### The trail carries no direction, and is not meant to

A mark is `(x, y, strength)`. There is nothing in it that says which end is food — a trail laid by
a laden ant looks exactly the same from both sides. **Polarity comes from the ant, not from the
trail**: the away-bias above, plus the ±100° arc, which keeps an ant going roughly the way it was
already facing. That is the mainstream answer for real ants too; most species orient by path
integration and landmarks rather than by reading direction out of the trail itself, though some
(Pharaoh ants, famously) lay geometrically polarized networks whose forks encode it.

The weakness is worth knowing: an ant whose home vector has gone bad has no bias left, and the arc
restriction is doing more of the work than the bias is. If trail polarity ever needs to be
stronger, the honest routes are a second (home) pheromone or Y-shaped trail geometry — not a
direction field baked into the mark, which would be a value no real ant could read.

**Laden**, the ant navigates by **path integration** — a home vector accumulated from its own
steps. This is instead of the usual second ("home") pheromone field, because a returning ant that
loses the field wanders forever, and one ant lost forever is the single most obvious way the whole
thing reads as broken. It also halves the field cost. The trade is that path integration walks into
walls, so **when obstacles are added, that is the moment to add the home field** — not before.

Deposition happens only while homing, every 7 units of travel, scaled by how far the ant has
already carried the crumb. **A short return lays a strong trail and a long one lays a weak one**,
so once two routes to the same food are known the shorter out-recruits the longer. That one line is
the whole of the positive feedback the colony runs on.

## Three ways of knowing where home is

Each was added because the one before it left ants stranded, and each was found by measuring rather
than by reading the code.

1. **Dead reckoning** carries the ant across the world.
2. **The nest's own plume** (`NEST_SENSE_R`, 92 units) takes over for the last stretch, blended in
   by distance rather than switched to — a hard switch makes every returning ant kink at the same
   radius. Also: *seeing home fixes home*, in any state, so a searcher that passes its own nest
   re-anchors and error cannot accumulate across trip after trip.
3. **A widening search spiral** when reckoning has run out and the nest is not in range, with a
   **give-up** at 45 s after which the ant abandons the crumb and goes back to searching.

### Where the reckoning error actually comes from

Not from `PI_DRIFT`, which looks like the culprit and is not: over 200 s it amounts to about
0.07 rad. What breaks an ant's estimate is **being shoved**. `level.gd` separates overlapping ants
by up to 4.5 units per contact and the ant has no way to know it moved, so a few hundred jostles in
a busy column random-walk its estimate some 35 units off — which matched the ants found stuck 30–34
units from where they believed home was. It is left in deliberately: a real ant cannot feel being
pushed, and the recovery is the more interesting half of the behavior.

### Three measured failures, for anyone tuning this

Every one of them ran without a single error, which is why the probe tests behavior and not
formulas:

- **No close-range homing.** Carriers reached 30–120 units of the nest, their home vector collapsed
  to 6–23 units so its *angle* was pure noise, and they milled outside the entrance. One had walked
  9,964 units on a 654-unit errand; two thirds of the colony was permanently carrying and delivery
  ran at ~10 per 30 s. Fixed by (2) above — delivery went to ~40 per 30 s.
- **The spiral did not latch.** A lost ant spiralled away from its phantom nest, which made the home
  vector grow back past `LOST_R`, so it stopped searching and walked back to the phantom, forever.
  Three ants of forty orbited at 135–161 units out. Once reckoning has lied there is no information
  left in it, so being lost now latches and only the nest itself clears it.
- **No give-up.** Three ants still carrying after three minutes with the pile long empty held the
  level open — `_is_finished` waits for the last carrier — and kept laying trail, so the "unused"
  trail *grew* while they circled.

## Getting to the food, and into the nest

**Food smells.** Nothing used to attract an ant to a pile at all: the only thing drawing it in was
the scent trail, and a trail *ends* at the pile rather than pointing into it, so an ant passing at
31 units had no reason to turn and sailed straight by. Ants were reported coming right up to the
food and circling away empty-handed, and that is why. `FOOD_SENSE_R` (78 units) is the counterpart
of the nest's own plume: `level.gd` tells each searching ant whether a stocked pile is in range,
and the ant steers at it and stands its wander down. Measured after: **47 ants reached the pile in
30 s and every one of them left with a crumb.**

**A crumb can only be taken from where a crumb can be seen.** The pile shrinks as it is carried
away — it is the only readout of progress the world itself gives — but pickup used to be a fixed
30-unit disc while the drawing shrank with `√(what is left)`, so a nearly-empty pile went on
handing out food from bare ground. `AntsArt.pile_radius()` and `AntsArt.pile_edge()` are now the
single source for both: the same two functions decide where the pile is drawn and whether an ant is
standing on it, so they cannot drift apart again. `MIN_PILE_R` keeps the last few crumbs reachable.

**A pile is not a disc.** Its outline is three harmonics on the radius, seeded per pile, so each is
lopsided in its own way. The crumbs are scattered against that lobed edge rather than inside a
circle, so the shape is the real shape and not a ragged skin painted around a round one.

**A crumb is deposited down the hole, not on the doorstep.** Arriving anywhere on the 26-unit mound
used to count, so the crumb vanished a body length short of the entrance and the ant turned round
in the open — which read as the food evaporating rather than as the ant delivering it. Delivery now
needs `AntColony.at_hole()`, inside the drawn entrance, and the ant waits there before turning back
out (`DEPOSIT_PAUSE`). Picking a crumb up takes a moment too (`PICKUP_PAUSE`). Both were
instantaneous, and an instantaneous action looks like a teleport rather than like work.

## Obstacles

The player taps anywhere in the world and gets a ring of choices — **stone, twig, water, and remove**
if there is something under the tap. The pattern is storm's (`storm/scripts/level.gd`,
`create_actions_popup`): a `PopupPanel` centered on the tap with a transparent background, and
**the center cell left empty**, so the spot being acted on stays visible while the choice is made.
That is the whole point of the design and the reason it is not a bottom bar — you are choosing what
to drop on top of ants you can still see. A press that travels more than `TAP_SLOP` is a pan
instead, so both gestures live on one input without a mode switch.

Each choice draws its own swatch through `AntsArt.draw_obstacle` from a real `AntObstacle`, so the
button is the thing itself rather than an icon standing in for it.

**One shape serves all three kinds**: an oriented ellipse whose radius is modulated by a few
harmonics, seeded per obstacle — a stone is fat and lopsided, a twig long and thin, water wide and
irregular. `contains()` and the drawing read the same geometry, so what an ant cannot walk through
and what the player sees cannot disagree. That is the food pile's lesson applied before the fact.

An obstacle is refused if it would sit on a nest or a pile (which would strand a colony for good
rather than making it work), if it would **overlap** an existing one, or if the player has none of
that kind left. A refused drop costs nothing.

Overlap is refused for a reason beyond tidiness: two obstacles sharing ground make a combined shape
whose outline is neither one's outline, and edge following reads exactly that outline to get round.

**Each kind is a limited stock**, set per level (`"stock": [stone, twig, water]`). Placing spends
one, picking the thing up again returns it — a budget for the level rather than a rate. A kind with
none left stays in the menu, dimmed whole (swatch, frame and count together, the way storm dims a
spent action), so the player can see that it exists and that they are out of it.

`place_obstacle` takes an optional angle. A tap gives no orientation, so a random one per drop is
what keeps a field of stones from looking stamped — but a twig is 152 units long and 18 wide, so its
angle is most of what it does, and anything laying a deliberate wall needs to be able to say.

### What ants do about them, and why it is the natural answer

Nothing plans a path. Three mechanisms the colony already had turn out to be enough, and they are
the same three the real animal uses.

**What is still a simplification**, so nobody has to rediscover it: a real ant maintains *antennal
contact* rather than a gap, and touches the surface repeatedly; it learns a detour visually after a
few trips instead of rediscovering it every time (here the pheromone trail is the colony's memory
instead, which is defensible for a mass-recruiting species and is the double-bridge result, but it
does mean each ant is dumber than the real thing); and all three obstacles are equally impassable
when a real ant would climb a twig and only genuinely be stopped by water.

1. **Thigmotaxis — edge following.** An ant that meets something solid fans whiskers out from the
   heading it wanted and takes the nearest one that is clear, so it deviates as little as it must.
   The side it hugs is **latched** for `WALL_HOLD` after the last contact; re-deciding every tick
   makes an ant oscillate where it touched and never get round — the same failure, and the same
   fix, as the latched `lost` flag.

   Two things make it *following* rather than repeated collision, and both were added after
   watching it fail:

   - **The goal is damped while in contact** (`WALL_GOAL_DAMP`). The steering re-aimed at home
     every tick, so an ant in one of water's concave pockets turned back into it the instant a
     feeler read clear, and sat there oscillating. Getting out of a cranny means going the wrong
     way for a moment, and a greedy ant will never choose that. While an edge is being followed the
     goal is damped almost out and the contour decides. Real ants do the same — a detouring ant
     suppresses its vector-directed course while following a barrier and resumes when clear, with
     the path integrator running throughout — and the damping is a weighting rather than a hard
     mode switch, which is closer to the observed compromise between barrier and goal.
   - **It is a PD controller on antennal contact, not a scan.** The first version fanned whiskers
     out and took the first clear heading. That is bang-bang control, and it traces a
     mathematically exact offset curve — the unnaturalness was the *regularity* of the track at
     least as much as its closeness, which is why simply standing further off did not fix it. Wall
     following in insects has been modelled as proportional-derivative control on antennal distance
     (the cockroach work of Camhi & Johnson, and Cowan et al.), and that is what `_edge_turn` now
     is: hold `WALL_GAP`, correct on error and on closing speed. A PD loop can run *close* to a
     surface without scraping it, which is both what was asked for and what the animal does.

   **One animal, one antenna.** The obstacle feeler used to be a separate 30-unit probe — nearly
   three body lengths, sized by a turning-radius sum rather than by anatomy — while the same ant
   smelled at 17. Both are `ANTENNA_REACH` now, a little over one body length, which is about right
   for a real one.

   **The antennae sweep** (`ANTENNA_SWEEP_RATE`, `ANTENNA_SWEEP_AMP`), several times a second, as a
   real ant's do, and each ant's phase is drawn at spawn so the colony does not sweep as one
   animal. This is not decoration: a fixed pair of feelers gives continuous contact and therefore a
   smooth curve, while a swept pair makes contact intermittently and the track wavers.

   `AVOID_TURN` is still a sharp recoil, but it now fires only on real contact in front
   (`REACT_AHEAD`) rather than on a distant prediction — an ant that walks into something does turn
   sharply.

   - **It lets go once its own way is open.** Following had no exit condition at all — an ant
     stayed glued until it ran out of wall, and a **twig never runs out**. At 152 units long and 18
     wide, an ant reaching a tip loses contact, `WALL_SEEK` curls it back, and on something that
     thin it re-acquires the *opposite face*; then it follows back down, round the far tip, and
     round again. A single twig across a road left 22 of 39 ants clinging to it with the delivery
     rate falling away — 57 crumbs per 40 s down to `[35, 27, 20]` — while a stone and a pool
     dropped on the same spot cost almost nothing. Fat shapes hide this, because losing their
     surface for `WALL_HOLD` is easy; a thin one is a racetrack. So while following, if the bearing
     the ant actually wants (`_goal_bearing`: the nest, the pile it can smell, or the trail it has
     joined) is clear within antenna reach, it drops the wall and goes. This is the exit condition
     every wall-following algorithm has and this one was missing; with it the twig gives
     `[47, 40, 48]`, in line with the other two.

   **Measured**, sampling alongside a pool that blocks the road: the scan gave 6,146 samples
   alongside in 30 s with 17.9% of them within 2 units of the surface, and the most patient ant
   spent 23.4 s working round it. The PD loop with a swept antenna gives 12,997 samples alongside
   with 14.9% within 2 units, and 9.4 s for the worst ant. Ants engage obstacles more than twice as
   often while scraping proportionally less, and get round far quicker. The exit condition then
   recovered what the PD loop had seemed to cost elsewhere: recovery behind the twig wall went from
   `[19, 24, 30, 32]` back to `[35, 34, 36, 31]` — level with the best the scan ever managed, and
   without its too-perfect track.

2. **Dead reckoning survives the detour.** The home vector is accumulated from steps *actually
   taken*, so walking an ant the long way round a stone leaves it still pointing at the nest from
   wherever it comes out. Path integration cannot plan a detour but it is robust to one, and that
   is exactly the division of labor in the real animal.
3. **The trail re-routes by reinforcement.** Marks are laid on ground that was walked, so a new
   road appears around the obstacle by itself, and the old one into the stone evaporates because
   nobody renews it. This is Goss's double-bridge result and the origin of Ant Colony Optimization;
   the `FADE_LENGTH` term already had the half that makes the shorter way round win.

Scent under a newly-placed obstacle is **erased** — scent under a stone is under a stone, and
leaving it would have ants steering at a smell they can no longer reach.

`PROBE_AHEAD` and `AVOID_TURN` are **one decision, not two**: an ant has `PROBE_AHEAD / speed`
seconds to turn away from what it has found, so a short probe forces a violent turn. At 20 units and
5.0 rad/s the worst measured turn was 8.8 rad/s — 500°/s, a flick rather than a movement. Feeling
further ahead (30) bought the time to make it an arc at 3.5.

**Measured:** three stones dropped across a working trail, and the colony went from 63 crumbs per
40 s to `[40, 40, 35, 38]` — about 61%. It does not come back to the old rate and should not be
asked to: the road is genuinely longer, and a longer return lays a weaker trail by design.

### Why the popup has no panel behind it

Storm frames its action popup with a transparent **fill** and a visible **border**, and that split
is the right one to copy. The fill has to stay clear: this menu opens over a live colony, and the
whole reason it is a ring around an empty middle is that you are choosing what to drop on ants you
can still see — a filled 3x3 panel would hide the thing being decided about. But an unframed set of
floating buttons has no edge, and nothing tells the player where the menu stops and the world
starts. So: transparent fill, faint border, rounded corners. Storm's frame without storm's panel.

### Ants killed

Dropping an obstacle crushes any ant standing where it lands. `AntColony.killed` counts them per
colony and `level.ants_killed()` totals them. **Nothing reads it yet** — it exists so that dropping
something on a busy road is not free, and so the cost is already being recorded whenever it is
decided what to do with it.

### Dismissing the menu

A tap outside the popup must close it and nothing else. Godot closes the popup itself on the
press — which clears `MainGlobals.popup_open`, so the **release** then reached `_end_press` with
nothing open and built a fresh menu at the very spot the player was trying to dismiss to. The
deadtime is therefore armed on the menu's own `popup_hide`, not on a choice being made, so it
covers every way a menu can close.

### Three failures the obstacles surfaced

None of them was an obstacle bug. All three were faults that already existed and that a blocked road
was simply the first thing to trigger.

- **An ant could orbit its own front door.** Delivery needs the ant inside the entrance
  (`at_hole`, 13 units), but a full-speed ant's tightest turn is `speed / HOME_TURN` — about 23
  units across. One that overshot could circle the hole forever, never able to turn tightly enough
  to enter. Ants now slow as they come into the mouth (`NEST_CREEP`), which shrinks the turning
  circle below the hole and reads better besides.
- **An ant could be pinned against the world's rim.** Found at `(11, 180)` with its reckoning
  insisting home was 193 units away when it was 121: it steered into the edge, the edge turned it
  back, and it did that for a whole 180-second level, still carrying, keeping its trail alive.
  `LOST_R` never caught it because that only fires when the vector has shrunk to nothing, and this
  one was confidently wrong. There is now a second, more general condition (`HOME_STALE`): **a
  homing ant whose home vector has not got shorter in twenty seconds is not going home**, whatever
  the reason, and it goes into the search spiral.
- **`push_out` took the long way out.** It exited along the radial direction in the shape's own
  frame, which for a twig can mean 76 units lengthwise instead of 9 sideways — so a clipped ant was
  slid *along the inside* of the twig for dozens of ticks. One measured 29.7 units deep in something
  it should never have been able to enter. The exit is now searched for: eight bearings in the
  shape's frame, so the short axis is always among them, marched outwards, nearest wins.

## Contact, and the greeting

One pass over an `AntGrid` (cell = `CONTACT_D`) does both jobs, because both are answers to "who is
next to me" and the hash is the expensive part:

- **Ants are solid.** Overlaps are gathered first and applied after, so an ant caught between two
  neighbours gets one bounded move rather than being knocked twice in a tick by whichever pairs
  happened to be visited — and so the order ants appear in the array stops mattering.
- **Two meeting head-on stop and touch antennae** for 0.10–0.22 s. `contact_cd` is not decoration:
  without a cooldown a busy trail is a standing crowd, because every pair re-greets the moment the
  last greeting ends and nothing moves again.

## Why the movement was jumpy, and got jumpier

Three separate causes, all of which happened to scale with how crowded the trail was — which is why
it looked like the simulation degrading over a session rather than three fixed faults.

1. **The shove was a teleport.** A separation was applied in full the instant it was computed, up to
   4.5 units in one tick — half an ant's length. Separation is now a **speed** (`MAX_PUSH_RATE`,
   90 units/s): an overlap still clears, over two or three ticks. Measured worst step in a tick fell
   to 1.31 units, and the tight non-overlap bound still holds.
2. **The greeting was a dead freeze** — one frame walking, nine frames stock still, one frame
   walking, each a velocity discontinuity, and they multiply with trail density. The ant now eases
   down and back up over `PAUSE_EASE` and goes on steering while it slows, which also lets the two
   of them turn to face each other as they meet.
3. **The simulation ran in `_physics_process` while the drawing happened at the display's refresh
   rate.** There is no physics engine in this game — no bodies, no shapes, no collision server — so
   the physics tick bought nothing, and whenever the two cadences drifted apart every ant repeated
   or skipped a position at once. It steps in `_process` now, so a drawn frame is always the frame
   that was just simulated.

Two turn caps came down with them. `MAX_TURN` was 5.2 rad/s, which at 56 units/s is a turning circle
of 10.8 units — **tighter than the ant is long**, so a correction read as a twitch rather than a
turn. And a shove's lean is a rate (`SHOVE_TURN`) rather than a flat fraction of the angle, since a
fraction is just the positional jump moved into the heading.

## Drawing

Everything is drawn, in world space, by `level.gd`'s single `_draw()` — no sprite, no tile. Ants are
plain `RefCounted`, not nodes: a colony is tens to hundreds of them and a `Node2D` apiece (let alone
a physics body) buys nothing.

The ground follows the same principle as the eleven lawns (`scripts/grass_field.gd`): one continuous
surface, never a repeated image. It differs in how it is produced, because a lawn covers a board of
known size and this world may be 6800 units across — so the grain is generated on demand from a hash
of its own cell coordinates (deterministic, so it never crawls) and only for the part of the world
on screen. The grain cell is picked from a fixed ladder, so it is **anchored in the world**: panning
never shifts the grain, and it only changes size when the zoom does, which happens once at level
start. Fine grain is skipped entirely when it would be under ten pixels.

An ant is drawn at two levels of detail — three body segments, six legs in a tripod gait and two
antennae up close. **The legs are not parallel**: the front pair reaches forward, the middle pair
straight out and the hind pair sweeps back, so from above the front and hind legs cross into an X
with the middle pair through it, and the knee splays less than the foot so a leg has an elbow
rather than being a straight spoke. Drawn as three parallel oars, which is what they were, an ant
reads like a woodlouse. `devtools/make_ants_thumb.py` carries the same three constants; a dash with a crumb on it when `LENGTH * zoom` drops below 5 px, since 200 smears
cost more than they show. The gaster carries one highlight, which is what keeps a near-black ant off
a dark soil. The food pile **shrinks as it is carried away**: it is the only readout of progress the
world itself gives.

## Scoring — deliberately none

`GenericGameUtil.add_score_and_time(1, 0, false)` counts a crumb in the HUD with
`is_actual_score = false`, so `score_was_changed` stays clear and `save_score()` returns before
writing anything. A session therefore writes no row, the Scores screen stays empty, and the stats
screen is never told this game measures something it does not.

`ants` is listed in `probe_audit.gd`'s `NOT_MEASURED` for the same reason, and that check is
symmetric: a game on the list that *has* started recording is reported as a gap too, so the
exemption cannot quietly outlive its reason. When Ants acquires a task it leaves the list at the
same time as it gains a `SUMMARY_ROWS` entry in `scripts/game_instrument.gd` — and not before.

## Tutorial

`scripts/tutorial.gd` is a placeholder and is **not wired up**: `ants` is absent from
`MainCfg.tutorials` and `main.gd` defines no `start_tutorial()`, which is what the instructions
screen and the main menu test before offering the "Interactive tutorial" button. Defining the
method with no steps behind it would put the button in front of players and open an empty coached
session — worse than not offering one.

When it is written: spotlights must be **measured, not authored**. This game runs under a camera
whose zoom depends on the world size, so a `spot_radius` in screen units means something different
on every level. See the `_tight()` note in `gorilla/docs/design.md`, which is the worked example.

## The probes

`devtools/probe_obstacles.gd` drops **one obstacle of each kind on the same trail, at the same spot,
against the same seeded colony**, and reports what each costs. It exists because the twig bug was
invisible from any single run: the colony still delivered, just less and less, and only the
side-by-side comparison showed that one shape was doing something the others were not.

Its capture measure is the **longest unbroken time any single ant spends beside the surface**. The
first version counted how many ants were within `bound_radius + 30` of the *centre*, which is a zone
covering 8% of the world for a twig and 3% for a stone — it was measuring the size of the shape, and
it duly reported a failure for water that was nothing but geometry.

## The main probe

`devtools/probe_ants.gd` (symlinked as `main/probe_ants.gd`) drives the colony headlessly and asks
the only question that matters about an emergent system: **does the loop close?** It tests no
formula — every formula here is individually plausible and they can still add up to a colony that
wanders forever, which is what happened twice during development without anything erroring. It
checks that food is found by searching, that it comes home, that an ant reaching the pile leaves
with a crumb, that no crumb comes from bare ground, that an ant meeting a trail joins it, that
nothing turns or steps further in a tick than it could have, that a trail nobody renews evaporates,
that a level can be finished, that no ant stands inside another, and that the 10×10 world still
simulates faster than real time. It prints its measurements as well as its verdicts.

**Recruitment is proved by a controlled experiment, not by a threshold.** The same level, the same
ants, the same food, run twice — once normally, once with the scent field wiped every tick so no ant
can ever follow one. Everything else still works: they search, they smell a pile in range, they
carry home by dead reckoning. Only recruitment is removed. Measured: **215 crumbs home with a trail,
84 without.**

That shape was arrived at the hard way. Before-and-after comparisons of the colony's own delivery
rate had their thresholds re-tuned twice, because each improvement to the ants made the colony
organize *sooner* and so ate into the "before" the test was measuring against — the check kept
failing a strictly better colony. Two other checks are likewise shaped by the probe's own mistakes:
measuring recruitment against a **finite** pile cannot tell a colony that is speeding up from a pile
that is running out, and the evaporation check has to be taken from the trail's height rather than
after it has already gone.

The joining check has a **control**: the same ant, same heading, on bare ground, must carry straight
on. Without it the check would pass just as well on an ant that always curves, and would be
measuring geometry rather than recruitment.

**The probe drives the simulation itself** (`_take_the_wheel` switches the level's `_process` off),
and it must do so **before** `new_game`, not after — called after, the frames awaited while the
level builds itself have already advanced the colony by however long they happened to take. That is
how this came back a second time, two runs apart on kills and on recovery, after appearing fixed.
`level.gd` steps itself in `_process`, so every awaited frame after `new_game()` advanced the colony
by a wall-clock delta and no seed could make that reproducible: the same recovery measurement read
39, 32 and 18 on three runs, and its threshold was being fitted to noise. With `sim_step` the only
thing that moves an ant, two consecutive runs print identical numbers.

The obstacle checks also had to be **moved**: they were first written after the evaporation test,
which runs the level to completion — so they were measuring a colony with no food and no trail, and
"before the stones" was zero crumbs. A test can be green, or red, for reasons that have nothing to
do with the thing it names.

The sharpest example of that came from `overlaps()`. A careless text replacement deleted the whole
method, and the check named **"one may not be dropped on top of another" went on passing** — because
the missing method raised a runtime error, a GDScript function that errors returns its return type's
default, and `false` is exactly what that test wanted to see. It was caught only because a *different*
check (laying a wall) started failing with no reason printed. Assert on what a thing does, and be
suspicious of a pass whose mechanism you have not seen.

**Where a test object is put decides whether it can test anything.** The pool used to check for
trapped ants was first dropped a wall-pitch off to one side of the road, where ants pass thirty
units clear of it — neither the trapping nor the hugging can happen there, and it duly reported a
flawless result twice, under two different settings. Likewise the daylight histogram first selected
ants within 81 units of the pool's *centre*, which is mostly ants walking past in open ground, and
reported that every single sample was comfortably clear. Both now select on distance to the
**surface**, with the pool **on** the road.

Geometry in the tests is **computed from the shapes**, not guessed. Two versions of the wall test
laid overlapping obstacles — stones at 52 apart when they are 68 wide, then twigs at 155 apart when
their lobed tips reach 161 — and each time the refusal was correct and the test was wrong. The
spacing now comes from `AntObstacle.SHAPE`.

The non-overlap bound is **one tick of separation**, not zero. Separation is rate-limited, so an
overlap clears over two or three ticks and a transient of about that size is the design. That check
carried a 0.75 bound from before the rate limit existed and had been passing on luck ever since.

The smoothness check excludes ants that changed state or bounced off the world's rim, because
picking up a crumb, dropping one, giving up a load and hitting the edge all turn an ant on the spot
by design, and folding them in would hide what is being measured behind four legitimate spikes.

## Art

`art/game_screen_200.png` is a **placeholder** generated by `devtools/make_ants_thumb.py`, to be
replaced with a real screenshot like every other game's tile. It is not invented: the script reads
its colors and proportions from `ants_art.gd` and `ant.gd` and lays the nest and food where
`level.gd` puts them for level 1. The chooser loads that path unguarded, so the game cannot appear
in the list without a file there.
