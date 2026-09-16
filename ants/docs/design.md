# Ants — design

**Keep the colony from carrying the food home.** A nest wants a pile; you have a few stones, twigs,
pools of water and a can of repellent. Block the trail and the colony wears a new one around your
wall within a minute, so the game is not walling off a route once — it is watching where the next
road is forming and getting there first, by lifting what you already placed and moving it.

Everything the colony does emerges from one ant's local rules. Nothing anywhere plans a route,
which is exactly why interdicting it is a task: the thing you are playing against adapts, and it
adapts by a mechanism you can learn to read.

## The rules

- **The allowance is the score.** It starts at the level's `allowance` and every crumb that reaches
  a nest takes one off it. At zero the colony has had what it came for and the round is lost
  (`game_over_on_zero_score`). Survive the clock with anything left and you win — so
  `game_over_on_time_out` is **false** here and `sig_time_over` is taken as the win.
- **Crushing ants is not the job.** An obstacle dropped on an ant kills it, and each one costs
  `KILL_PENALTY` (5) off the same allowance. The way to win is to turn them, not to flatten them.
- **Clearing every pile is the colony's win.** If the last crumb reaches a nest the round ends as a
  loss however much allowance is left, because there was nothing more to protect.

Allowances are set from measurement, not taste: an unopposed colony delivers 181 / 237 / 520 / 769 /
996 over each level's time, and the allowances ask for the same **58% cut on every level**.
Difficulty is the number of routes to cover against a stock that grows more slowly — not a harder
sum. Ant counts came *down* when the game arrived (level 5 went from 400 to 120): a bigger colony
only raises the rate past anything nine obstacles could answer, and it was what made a phone
struggle.

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

`"world": [x, y]` in the level config is a size in **screenfuls** — `[1,1]` is one screen wide by
one screen tall. A screenful is 680 units wide everywhere and as tall as the **usable band**: the
canvas less the HUD above and the button bar below. So a world is square on a desktop (680×688) and
tall on a phone (680×1100), and fills the space either way. It used to take the canvas *width* for
both axes, which made every world square by accident of one constant and left about 420 units of
perfectly good ground unused below the colony on a phone. The ladder runs 1, 1.25, 1.5, 2, 3. Nothing in the simulation is
sized against the world, so 3×3 is an *intention*, not a limit: this table is the only place that
decides, and a bigger number costs only what the extra ants and longer trails cost.

## Creature scale on a phone

An ant is the same fraction of the canvas on both devices — the canvas is 680 units wide on each —
but that fraction is **4.85 mm on a desktop window and 1.13 mm on a phone**, about 2.1x smaller to
the eye at normal viewing distances. It is physical size, not resolution, and it made the ants very
hard to see on a phone. `AntsG.creature_scale` is 2.0 there.

**Only the ant grows.** The world, the nest, the piles, the obstacles, every sensing distance, the
scent field and every journey time are exactly as they are on a desktop. What follows the ant is the
two things that are genuinely about its body: `contact_d`, the room it takes from its neighbours
(or a colony at double size is a heap of overlapping bodies), and the clearance its bulk needs from
the wall.

The first attempt did it the other way — shrinking the world in units and zooming the camera, which
is the same photograph enlarged. It looked right in isolation and was wrong in two ways at once: the
nest and the pile grew with the ants, and because an ant's speed is in *units per second* it crossed
a smaller world far quicker, so journeys fell from 11.7 s to 3.9 s and the phone played a different,
much easier game. `devtools/probe_antscale.gd` plays level 1 at both scales against one seed and now
asserts what must NOT move: world size, journey length, camera zoom, nest and pile radii.

**Arriving is a question about the ant's head, not its centre.** `Ant.head_pos()` is what reaches
the food and what enters the nest. Testing the centre meant an ant had to walk its whole half-length
inside before it counted — wrong at any size, and biting at a larger one: at double scale the
contact distance is 18 units against a 13-unit nest entrance, so ants shoved each other out of the
doorway they were queueing for. Fixing it lifted phone throughput from 103 to 117 crumbs in 120 s.

**What still differs, and why it is left alone.** A bigger ant queues more at an entrance that has
not grown with it, so the phone colony delivers about 70% of the desktop rate (117 against 167 in
120 s, measured after the colony has turned out). Greetings are *not* the cause — those are the same
at both scales (310 against 340 ant-seconds) — it is simply crowding at the nest hole and the pile.
Closing that gap would mean growing the nest entrance and the pickup radius with the ant, which is
exactly the "everything got bigger" that was rejected. The levers, if it ever matters, are those two
radii or a smaller `ants_per_colony` on a phone.

**The camera never zooms out.** `cam_zoom_out` is a per-level parameter and is 1.0 everywhere, so
the camera sits at 1:1 and a world larger than the screen is **panned**, never shrunk to fit. It
used to fit the world automatically and stop only at a legibility floor, which silently made every
ant smaller on the big levels instead of letting the player move around a full-size world. Level 1
is 1×1 precisely so that the whole world *is* the screen and nothing has to be panned to see the
trail form.


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

## The level briefing, and the edge of the world

Each level opens with the shared briefing card (`GenericGameUtil.show_game_popup`, the same
"Level N" card every other game uses), listing **nests, food piles, ant speed and world size**.
Nothing has to gate on it: `paused()` is true while any screen is visible and `_process` checks
that, so the colony stands still until the card is dismissed — and the HUD clock checks the same
flag, so reading the briefing does not eat the level's time.

Three of the four lines can be **withheld** — `tell_world`, `tell_colonies` and `tell_food` in the
level config — and read "Unknown" instead. All are true today; they exist so a level can send the
player in knowing less than they would like. The ants' pace is never withheld: it is the one fact
a player can check by watching, so hiding it would be a nuisance rather than a difficulty.

The text is built by `briefing_text()` and the probe asserts on that string, so the check is about
what the player is told rather than about a CanvasLayer.

**The world has a wall.** `walkable` is the world less `AntsArt.WALL_W`, and every rule that used
to be stated against `world` is stated against that instead — so the border is a *place*, not a
painted line, and an ant is turned at its inner face with its body clear of it.

It went through two wrong versions. First it was a wide, faint band shaded *inside* the walkable
area: too dim to notice, and ants walked straight over it. Thin and loud is the combination that
works — 7 units of near-black (5.4:1 against the light soil) with a pale lip on the inner face, so
it keeps a hard edge against the ground rather than fading into it.

The wall lies **inside** the world rect, which matters: the camera is clamped to the world, so
anything drawn outside it can never be seen, and the first version's border vanished the moment you
panned to an edge. Obstacles are checked against `walkable` too — the wall is not ground.

**A wall the camera cannot bring into view might as well not be drawn**, and that took two goes to
get right. `_clamp_cam` now works against the **usable band** — the viewport less the HUD at the top
and the button bar at the bottom — not the raw viewport. Clamping against the raw viewport parked the
world's top edge at screen y = 0, underneath the HUD, so above level 1 the top wall could never be
seen at all.

The second mistake was subtler and is worth keeping in mind for any clamp of this shape: the
overshoot that keeps the wall off the bezel was folded into the same pair of numbers that decides
whether the world is big enough to pan. Level 1's world (680) only just fits the desktop band (688),
so the overshoot handed it 40 units of spurious range to slide about in, and it used them to tuck its
top edge under the HUD — which is what "the top border is very narrow on level 1" was. The fit is
decided **without** the overshoot; the overshoot is applied only after, and only when the world
really is pannable. A world that does not fill the band is centred **in the band**.

## Panning, and why it was bad on a phone in three separate ways

1. **Applied per event.** Every drag event moved the camera and asked for a redraw, so how far the
   view travelled depended on how many touch events the device happened to deliver. Deltas are
   gathered into `_pan_accum` and applied once in `_process`.
2. **Tap-or-pan was decided from the mouse.** The slop test asked the viewport for the mouse
   position — which on a touch screen is not where the finger is, so on a phone it was comparing
   against a number with nothing to do with the gesture. It uses the event's own `position` now.
3. **Every finger panned.** A second finger, or a palm on the glass, added its own drag to the same
   camera, so the view shot off at twice the speed or fought itself. `_press_index` records which
   pointer owns the gesture (-2 none, -1 mouse, >= 0 a touch index) and only that one pans.

Panning and redrawing also sit **outside** the paused guard now. They used to be behind it with the
simulation, so a drag while anything was paused piled up in `_pan_accum` and went off in one jump
when play resumed.

## Turning out

A colony does not leave home all at once. Every ant used to be created at t=0 inside an 18-unit disc
around the nest, so the whole colony set off together and spread as a single visible wavefront — a
ring expanding out of every nest at the start of every level, which is not a thing ants do.

They come up out of the hole in a trickle instead, over `EMERGE_WINDOW` (20 s), each ant's turn drawn
uniformly at random rather than evenly spaced — an even spacing is its own pattern, and a trickle is
irregular. Until then an ant sits in `AntColony.pending`: not stepped, not drawn, not in the contact
grid. Two counts therefore exist and mean different things — `ant_count()` is ants out and working,
`population()` is the size of the colony.

A ring is ants all at **the same distance from home**, so that is what `probe_ants` measures: the
spread of those distances against their mean, nine seconds in. One cohort walking out together holds
formation and scores near zero; the trickle scores 0.57.

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
rather than making it work) or if the player has none of that kind left. A refused drop costs
nothing.

Two obstacles may not share ground — the combined shape would have an outline that is neither one's
outline, and edge following reads exactly that outline to get round. But a drop that *would* overlap
is **not thrown away**: it slides outward until it fits, along the line from the blocking obstacle's
centre through the tap, so it comes to rest against the side that was tapped. Tapping the flank of
something already placed is a reasonable way to say "another one, here", and it used to do nothing
whatever — menu closed, stock untouched, no obstacle, no explanation. Steps are small, so it lands
*adjacent* rather than a shape's width away.

Only an overlap slides. A drop refused for sitting on a nest or a pile stays refused: sliding it
would put an obstacle somewhere the player never pointed at.

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

## Bait, the one tool that is not a wall

`AntObstacle.SOLID` splits them. A stone, a twig and a pool are walked around; **bait** is walked
onto, because bait is food. Nothing in the ant knows it is a trick: the colony smells it, recruits to
it, and carries it away by exactly the machinery it uses on a real pile. What it costs the colony is
**trips**; what it costs the player is nothing, because `Ant.carrying_bait` follows the crumb to the
nest and the allowance is only charged for real ones.

An ant carries bait in **the bait's own colour**, so a stream of ants working your bait is visibly
that, and not a raid on the pile you are defending.

Measured with bait on the road: **45 bait crumbs carried home against 31 real ones in the same
window, and the allowance charged exactly 31.** It has to go where ants will find it — food is
smelled from about 78 units, so bait dropped 150 units off the trail was found by one ant in seventy
seconds.

Bait is not reusable and vanishes when eaten. It is the only tool that works *with* the colony's
machinery rather than against it, and it needed no special pleading anywhere in the ant to do so.

**A fan was tried and removed.** It dispersed the scent under it, which severed the road with no
reply available: searchers stop arriving once a trail thins, so no traffic remains to hold it up,
and a carrier homes by dead reckoning — straight back through the middle — so no road formed beside
it either. Tuning the rot rate did not fix it (0.90 left a whisper, 0.95 left nothing: whether a
thinning road survives is chaotic). A floor and a draught made it *work*, at 37 crumbs per 30 s
against 23 with a fan on the road — and it still read as an arbitrary dead zone rather than a thing,
so it went. Bait does the same job by being legible.

## Laying a twig

A twig is 152 units long and 18 wide, so its angle is nearly all of what it does — and dropped at a
random angle it lands parallel to the trail as often as across it, doing nothing whatever. A tap
says *where*, and where is enough: `trail_axis()` samples the scent a little way along each bearing
and a little way back, scoring an **axis** rather than a direction (a trail has no preferred end),
and the twig is laid square to it. With no road there yet it falls back to the line from the nearest
nest to the nearest pile, which is the road the colony is going to want anyway. Measured: three
twigs dropped with no angle given land within 15° of square.

Only elongated tools get this. A stone's angle is variety and stays random.

## Tooltips

A phone has no hover, so the only gesture left that does not already mean "use this" is a **hold**:
`HOLD_MS` on a menu cell opens the tooltip instead of picking the tool. A desktop keeps its hover as
well — a mouse has one, and holding a button down to read a label is a phone's compromise rather
than a desktop's — on the same delay, cancelled if the pointer leaves.

**The menu is a CanvasLayer over the viewport, not a PopupPanel** — which is where it parts company
with storm's version, and the reason is the tooltip. A Window clips everything to its own rect, so a
tooltip has to live inside the menu's own three-by-three square: cropped, and lying across the very
tool it describes. Growing the window to make room made the menu enormous. Over the viewport there
is no rect to be clipped by, so the ring stays exactly the size it always was and the tooltip goes
wherever it reads best.

It is placed **radially outward** from the cell being held, because anywhere else needs a line back
across the middle of the menu and over the other tools. Near a screen edge, though, outward is off
the screen — and clamping it back drops the box onto the tools, sometimes onto the very one being
held. So `place_tip()` walks the whole circle, nearest bearing first, and takes the first position
that both fits the screen and touches no tool. There is always one: the ring is small and the screen
is not. It is a plain function of its inputs so it can be checked directly, and `probe_ants` checks
all 36 combinations of corner, edge and held slot rather than anyone looking at one.

The connector is **one straight segment**, from the middle of the tool to the edge of the box, drawn
*over* the tools rather than under them. It briefly elbowed outward first whenever the straight line
would cross another tool — but from a corner cell "outward" is the corner of the screen, so the line
shot up into the corner and came back down, which reads as a mistake rather than a route. Crossing a
tool is legible when the line is on top; a dog-leg never is.

The scrim underneath takes any press outside the ring, so the tap that dismisses a menu never
reaches the world behind it — and a single `acted` flag on the menu means one tap is one action.
Godot emulates a mouse click from every touch, so a tap on a phone arrives twice, once as
`InputEventScreenTouch` and again as `InputEventMouseButton`, and the menu obligingly placed two
obstacles for it.

It has to be taught, which is why the instructions say so in as many words. The tutorial is still
the placeholder described below and will need to show it too.

## Contact, and the greeting## Contact, and the greeting

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

**Drawing is split across three layers by how often each actually changes**, and the split is worth
more than everything else in this section put together. It all used to be one `_draw()` that ran
every frame because the ants had moved — and the *ground* went with it. At a phone viewport that is
**4,795 `draw_circle` calls rebuilt sixty times a second, 288,000 a second**, for a surface that does
not change at all. Godot keeps each CanvasItem's command list and re-issues it without running
`_draw()` again, so a layer that is not marked dirty is free: the ground is built once per level,
the trail redraws at `TRAIL_HZ` (12), and only the things that actually move redraw every frame.
`probe_ants` asserts the three layers and their order, because collapsing them back would be
invisible on a desktop and ruinous on a phone.

**The trail is stored coarsely and drawn cheaply.** `MERGE_R` is how finely the field is *stored* —
not how it is sensed, which is `SENSE_R` and unchanged — and raising it from 6 to 10 thinned a formed
trail from about 1,800 marks to 817 without altering its shape, since a sensed value is the sum of
everything within 26 units under a smooth falloff. That cost arrived exactly when the game got
interesting: with no trail a `sense()` call evaluates 2 marks, with one it evaluated 70, the whole
simulation tripled the moment the ants found the food, and the trail layer had 1,800 circles to
redraw eight times a second. The marks are rects now for the same reason the soil grain is.

**The ground is drawn for the WHOLE WORLD, once — not for the view.** The first version of the split
generated it for the visible rect plus a margin, and rebuilt it whenever the camera had eaten half
that margin. That is worse than it sounds: on a phone it put all 4,795 draw calls into *one frame in
the middle of a swipe*, so panning became free frames, hitch, free frames. The ants stayed smooth
throughout, because their motion is dt-based — which made it look like a camera problem when it was
a drawing problem. Covering the whole world costs 21,000 commands at the largest level, built once
behind the briefing card, after which **no camera movement can cost anything at all**.

The grains are `draw_rect`, not `draw_circle`. A circle tessellates into a fan and there are twenty
thousand of them; a rect is two triangles. At one to two units across the difference is invisible,
and it is the difference between 42,000 triangles a frame and several hundred thousand.

Worth recording how this was found, since it was twice nearly missed: profiling the *simulation* said
`Ant.step` was 79% of it, at 3.4 ms a tick for 400 ants — true, and a red herring both times. The
simulation was never the expensive half. Scheduling scent sampling at 20 Hz (`SCENT_EVERY`, also
closer to the real animal's 8–10 Hz antennal sweep) bought 7%; the drawing changes removed two
orders of magnitude more work than that.

Everything is drawn, in world space — no sprite, no tile. Ants are
plain `RefCounted`, not nodes: a colony is tens to hundreds of them and a `Node2D` apiece (let alone
a physics body) buys nothing.

**The ground is light, and that is a constraint rather than a taste.** The ant is near-black by
design, and against the original dark soil it stood at a contrast ratio of **1.46:1** — not dim,
invisible, and on a phone the game was unplayable. The palette now puts it at 5.19:1 (WCAG AA is
4.5) with the worst speckle at 3.01:1, and `probe_ants` asserts both so it cannot drift back.

Lightening it was not a one-line change. `CRUMB`, `FOOD_BODY`, `STONE_BODY` and the nest had all
been picked to read against something dark, and at the new mid luminance they landed within
1.2–1.6:1 of the soil — differing from it in **hue alone**, which is what a colour-blind player, or
a phone in sunlight, cannot use. Every one was re-picked for a luminance difference, and the probe
now checks each of them too.

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

## What it measures

Two numbers, both direct consequences of where the player put things — no derived statistics, and
nothing the game does not actually record:

- **`crumbs_through`** — what got past you. The whole game in one number.
- **`ants_killed`** — crushed under a dropped obstacle, which is not the job.

Both are in `score_columns`, in `SUMMARY_ROWS`, and registered in `StatsOverview.METRICS` (lower is
better for both). A `SUMMARY_ROWS` entry alone is not enough: the Summary tab skips any metric
`METRICS` does not know, which is why Ants first showed twenty sessions and no rows at all.

Ants has left `probe_audit`'s `NOT_MEASURED` list, which it was on while nothing was asked of the
player. That check is symmetric — a game on the list that *has* started recording is reported as a
gap too — so the exemption could not outlive its reason.

**The probes must not record.** Ants keeps a real score now, so every level a probe ends calls
`save_score` against the player's own guest profile; one suite run left 24 MB of invented sessions
in it and gave the Planning category a history it had never earned. All three Ants probes set
`tutorial_mode` before their first `new_game` — the switch the game already has for "play it,
record nothing" — and it has to be before, because `reset()` commits an ongoing score too.

## Tutorial

`scripts/tutorial.gd` is a real coached tutorial now — fourteen steps, `ants` is in
`MainCfg.tutorials`, and `main.gd` has the `start_tutorial` / `_on_tutorial_done` pair on the ptbits
model. The **instructions no longer describe the tools one by one**: they say a tool explains itself
on a long press, and the tutorial shows each one working instead.

What it teaches, in the order a player gets it wrong:

1. A wall is not permanent — block the road and the colony wears a new one round it. A player who
   never learns this places four stones, watches them become scenery, and decides the tools do not
   work. It is a `watch_only` step ended by `advance_when` on the trail re-forming, because it has
   to be seen rather than told.
2. **What you placed can be picked up and moved.** That single action is the whole loop; without it
   the stock is four decisions rather than four tools.
3. Bait, which reads as helping the enemy and is the strongest move available, so it is shown
   working rather than described.
4. Crushing ants costs five times a crumb, and nothing on screen says so until the number drops.
5. The long press.

**Spotlights are measured, never authored.** `level.tutorial_*_rect()` return screen-space boxes
built from the live nest, pile and trail through the camera transform. This game draws through a
camera whose zoom depends on the device's creature scale, so an authored radius is right on one
machine and wrong on the next — the mistake gorilla's tutorial made and had to be rebuilt to undo.

`game.initial_score` is raised to 100000 in tutorial mode: a coached run must not be able to lose on
the allowance while the coach is still talking, and the lesson about the road re-forming takes a
minute of real colony time to land.

**What the coach must never sit on**, and the trap in saying so: the runner re-places a caption only
once it buries **half of a zone's area**, so the tool menu goes into `keep_clear` **cell by cell**.
Registered as one ring-sized zone it stayed put, because a caption lying across the bottom row of
tools covers barely a third of the square. The last thing placed is a zone too — a step that says
"tap what you placed" is unusable if the balloon is on it.

**A step that names a tool opens the menu and lights that tool.** The three tool steps (twig, the
red cross, bait) carry a `setup` calling `level.tutorial_open_menu()` — `(true)` for the cross,
which only exists in a menu raised over something already placed — and a `spot` calling
`level.tutorial_menu_cell_of(kind)`. Naming a tool and leaving the player to find it among eight
small pictures teaches the ring, not the tool, and the ring was taught two steps earlier.
`tutorial_open_menu` is **idempotent**: a menu the player already has open is left where it is,
because re-opening it would move it out from under a finger already on its way to a box. The cell is
asked for **by kind, never by slot** — `obstacle_menu.gd` publishes a `cell_kinds` meta beside
`cell_rects`, since which boxes exist depends on what the player has left. `probe_ants` runs each
step's `setup` before reading its `spot`, with the menu closed first, which is the only thing in the
suite that checks a setup does what its step needs.

**A menu that has been picked from is gone the instant it is picked from** — and it is still in the
tree for the rest of the frame. `ObstacleMenu`'s cell calls `close()` (a `queue_free`) and *then*
`on_pick`, and `on_pick` is what notifies the tutorial, so the next step's `setup` runs while the
free is still pending. `is_instance_valid()` is true there, so `tutorial_open_menu()` decided a menu
was already open and returned — and the bait step came up with its caption over nothing, which is
exactly what "the caption appears before the popup" was. Every tutorial hook that asks about the
menu now goes through `level._menu_open()`, which also rules out `is_queued_for_deletion()`.

**Watch steps put the caption in the top-right corner.** The nest is top left and the food bottom
right, so the whole story of a `watch_only` step happens along that diagonal. `caption_side: right`
alone was not enough: `TutorialRunner` **centres** a side caption in its column, which still lands
on the diagonal. The runner now also takes `caption_side_align` (`"top"` / `"bottom"`, default
centred), and the three watch steps set `"right"` + `"top"`; `probe_ants` requires every `watch_only`
step to carry both.

**Captions are short on purpose.** A balloon is sized by its text, and two steps ask the player to
*watch* a road form. The first draft explained the mechanism in two paragraphs and then sat across
the very thing it was pointing at; `probe_ants` caps caption length so that cannot come back.

**The failure mode of a tutorial is not a wrong caption — it is a step waiting for ever on an event
nothing emits.** `level.TUTORIAL_EVENTS` lists every name the level passes to `tutorial_notify`, and
`probe_ants` checks every awaited event against it, along with every spotlight resolving and no step
carrying a radius. `probe_tut` carries a hardcoded list of nine games and does not cover this one, so
without that nothing would check it at all.

## The top strip

**One counter: ants crushed.** Crushing is not the job and it costs five times a crumb, and nothing
said so until the score dropped — which left the player to work out which of the two things that had
just happened was responsible.

It used to be the shared **paired** corrects/mistakes counter, whose left slot showed *bait carried
home* purely so the right one would not sit beside a stuck zero. That was a second job for a number
nobody wanted, and "correct" is the wrong word for a game with no right answers. `GenericGameHUD`
now takes `show_tally(value_fn)`, which lights the lives widget — same place, same look — and
**reads** the number every `update_all()` instead of being pushed it. Nothing in the game writes that
label, so it cannot drift from what it is meant to be showing. It is not `lives_left` and not
`packets_left`: ants crushed goes *up*, must never be decremented by the shared machinery, and is
already persisted properly as the `ants_killed` score column.

**The ant icon is drawn, not imported** (`AntsG.ant_icon()`), as a dark shape inside a light rim —
one pass over the pixels measuring distance to the shape's skeleton, so the rim comes free rather
than being a second drawing.

**The rim is load-bearing, and it is a rim, not an aura.** The counters sit inside the HUD's
`BkLabel`, a 60 px band of flat dark grey — *not* the soil, which the strip covers. On that band the
dark body alone measures **1.9:1**; the rim carries it at **9.3:1**, and 17.7:1 against the ant
itself. But the legs are `0.030` wide and the first rim was `0.085`, nearly three times what it was
outlining, so the glow between the legs merged into one white blob and the icon read as a bright
badge with an ant somewhere in it. Now `0.034` with a squared alpha falloff — opaque where it
touches the body, gone quickly after, since a linear ramp spends half its width above 50% alpha and
that is the part that shouts. Coverage went from 39% rim / 22% shape to **13% / 22%**, and
`probe_ants` requires the rim to cover no more than the shape it outlines. It measures the contrast
against the live `BkLabel` color rather than an assumed background: the first version of that check
measured the ant against the ground and proved a 5.4:1 the player never sees. It is passed with `Color.WHITE` so it keeps its own colors instead of
the strip's yellow tint, and at **half scale**: `set_lives_icon` sizes the box as *texture size x
scale*, the icon is baked at 64 px for a clean edge, and every other icon on the strip is a 32 px
box — so a scale of 1 put a double-size ant next to normal-size everything else. `probe_ants` pins
the size and the tint.

The tool menu is closed when the level is hidden and on
`MainGlobals.sig_need_to_close_info_popups`. It is a CanvasLayer on the level rather than a child of
the board, so hiding the board does not hide it: pressing M with one open left it floating over the
main menu.

## The probes## The top strip

The two counters on the HUD (`hud.show_corrects_mistakes()`) carry **bait carried home** and **ants
crushed** — both things the player caused, one wanted and one not. Crushing costs five times a crumb
and nothing said so until the score dropped, which left the player to work out which of the two
things that just happened had done it. A pair of counters with one of them stuck at zero reads as
broken, which is why both halves are used.

**Both icons are drawn, not imported** (`AntsG.ant_icon()` / `bait_icon()`), as a dark shape inside a
light halo — one pass over the pixels measuring distance to the shape's skeleton, so the halo comes
free rather than being a second drawing. The strip sits over whatever the game is drawing, which
here is pale soil: a single tinted pictogram would be a yellow ant on sandy ground, and the icon
nobody can see is the one telling the player they are crushing ants. Measured 5.4:1 against the
soil, with the halo 17.7:1 against the ant itself. They are passed with `Color.WHITE` so they keep
their own colours instead of the strip's yellow tint.

The tool menu is closed when the level is hidden and on
`MainGlobals.sig_need_to_close_info_popups`. It is a CanvasLayer on the level rather than a child of
the board, so hiding the board does not hide it: pressing M with one open left it floating over the
main menu.

`set_counter_icons()` is new on the shared HUD, alongside the lives and packets setters. It uses
full node paths rather than `%`: those two icons are the only ones on the strip without
`unique_name_in_owner` set in the scene, so the shorthand silently finds nothing and errors at
runtime.

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
