class_name Ant
extends RefCounted

# One ant. A plain RefCounted, not a Node: a colony is tens to hundreds of these, and a Node2D
# apiece (let alone a physics body) buys nothing -- they are stepped by level.gd and drawn, all of
# them, by its single _draw().
#
# The ant knows only what is under its own antennae. There is no path, no target, no route: an
# outbound ant reads the scent field at three points ahead of its head and turns toward the
# strongest, and that is the whole of its navigation.

enum State { SEARCHING, HOMING }

# --- movement ---------------------------------------------------------------
const BASE_SPEED: float = 56.0        # px/s at speed_scale 1.0; ~5 body lengths a second
# Capped so an ant arcs instead of snapping round. 5.2 rad/s was too high to read as movement: at
# 56 px/s it is a turning circle of 10.8 units, TIGHTER THAN THE ANT IS LONG, so a correction looked
# like a twitch rather than a turn.
const MAX_TURN: float = 3.8           # rad/s
const HOME_TURN: float = 3.0          # a laden ant turns more heavily
const SHOVE_TURN: float = 1.6         # rad/s: the most a shove will turn an ant. A RATE, because
									  # a shove answered as a flat fraction of the angle is just the
									  # positional jump moved into the heading
const LENGTH: float = 11.0            # nose to gaster, in world units, at desktop scale
# How much larger this device draws an ant. Set once per level from AntsG. It multiplies the drawn
# body, the room an ant takes from its neighbours and the clearance its bulk needs from the wall --
# and deliberately nothing else. Sensing, speed, the scent field and every distance in the world
# are untouched, so the colony behaves identically; the ants are simply easier to see.
static var draw_scale: float = 1.0

static func body_len() -> float:
	return LENGTH * draw_scale

# Where its head is. Arriving at the nest and reaching the food are questions about the ant
# TOUCHING something, and they used to be asked of its centre -- so an ant had to walk its whole
# half-length inside the thing before it counted. That is wrong at any size and it bites at a
# larger one: at double scale the contact distance is 18 units and the nest entrance is 13 across,
# so ants shoved each other out of the very doorway they were queueing for.
func head_pos() -> Vector2:
	return pos + Vector2.from_angle(heading) * (body_len() * 0.36)

# --- antennae ---------------------------------------------------------------
const ANTENNA_REACH: float = 17.0
const ANTENNA_SPREAD: float = 0.55    # rad off the mid-line, ~32 degrees
const FOLLOW_THRESHOLD: float = 0.12  # below this the field is noise, and the ant explores
const FOLLOW_GAIN: float = 2.6
# Scent is sampled on a SCHEDULE, not every tick, and the turn it produced is held in between.
# Sampling at 60 Hz was 79% of the whole simulation's cost at 400 ants, and it bought nothing: an
# ant moves under a unit per tick and the field barely changes. Sampling at 20 Hz is also closer to
# the animal, which sweeps its antennae at something like 8-10 Hz. The phase is per-ant so the
# colony does not all sample on the same tick and spike one frame in three.
const SCENT_EVERY: float = 0.05

# --- joining a trail --------------------------------------------------------
# Three antennae spread 32 degrees either side can CLIMB a gradient but cannot recognise a RIDGE.
# An ant crossing an established trail at right angles reads the same strength left and right the
# whole way over, so it gets no turn at all and walks straight across a road its whole colony is
# using. Which is exactly what it looked like.
#
# So an ant standing on a trail stops sampling for a slope and asks a different question: which way
# does this thing RUN? It fans rays around its head and takes the strongest, refusing any that would
# turn it back the way it came.
const JOIN_SCENT: float = 1.0         # sensed strength that counts as standing on a trail
const JOIN_ARC: float = 1.75          # rad: the widest swing it will make to join (100 degrees)
const JOIN_RAYS: int = 9
const JOIN_REACH: float = 22.0
const JOIN_EVERY: float = 0.12        # s between scans, so only ants ON a trail pay for this
const JOIN_GAIN: float = 2.2
const JOIN_AWAY_BIAS: float = 0.20    # a tie goes to the end of the trail away from home
const JOIN_SETTLE: float = 0.55       # how far each new scan moves the bearing it is steering to

# --- food, up close ---------------------------------------------------------
# Set by level.gd when a pile is within smelling distance. Food beats trail: an ant that can smell
# the pile has no further use for the road that led it there.
const FOOD_TURN: float = 4.0
# Long enough to read as picking a crumb up and as putting one down. Both were instantaneous, which
# is what made a delivered crumb look like it evaporated rather than like it was carried in.
const PICKUP_PAUSE: Array = [0.18, 0.32]
const DEPOSIT_PAUSE: Array = [0.28, 0.45]

# --- repellent ---------------------------------------------------------------
# The spray is steered AWAY from by exactly the machinery that steers toward a trail: sample either
# side of the head, turn down the gradient. So a sprayed strip bends a column aside instead of
# stopping it, and an ant with nowhere better to go will still cross rather than stand and starve.
const AVERSION: float = 3.4           # how hard it turns from the stuff
const AVERSION_FELT: float = 0.35     # below this the ground is merely stale, not sprayed

# --- obstacles: thigmotaxis -------------------------------------------------
# An ant that meets something solid does not re-plan; it FOLLOWS THE EDGE until its own way is
# clear again. That is what real ants do (thigmotaxis, the same wall-hugging that keeps them in
# crevices), and it is the only detour mechanism here -- nothing in this game computes a path
# round anything, then or now.
#
# It also happens to be the only thing dead reckoning needs, because the home vector is
# accumulated from steps ACTUALLY TAKEN: walk an ant the long way round a stone and its vector
# still points at the nest from wherever it comes out. Path integration cannot plan a detour, but
# it survives one, and that is exactly the division of labour in the real animal.
# THE ANT HAS ONE PAIR OF ANTENNAE, and they are the same pair it smells with: ANTENNA_REACH, a
# little over one body length. The obstacle feeler used to be a separate 30-unit probe -- nearly
# three body lengths, sized by a turning-radius sum rather than by anatomy -- so the same creature
# was smelling at 17 and feeling at 30. One animal, one antenna.
#
# They SWEEP, several times a second, as a real ant's do. That is not decoration: a fixed pair of
# feelers tracks a wall as a perfect offset curve, and it was the REGULARITY of that curve, more
# than its distance, that made the following look wrong. A swept antenna makes contact
# intermittently, so the track wavers the way a real one does.
const ANTENNA_SWEEP_RATE: float = 8.5   # rad/s of phase
const ANTENNA_SWEEP_AMP: float = 0.34   # rad either way
# Wall following as a PROPORTIONAL-DERIVATIVE controller on antennal contact distance, which is how
# the behaviour has actually been modelled in insects (the cockroach work of Camhi & Johnson and of
# Cowan et al.). The previous version was bang-bang -- fan out whiskers, take the first clear
# heading -- which is what drew the too-perfect offset curve. A PD loop lets an ant run CLOSE to a
# surface without scraping it, which is the thing that was wanted and is also what the animal does.
const WALL_GAP: float = 5.0             # the contact distance it tries to hold
const WALL_KP: float = 0.26             # rad/s per unit of error
const WALL_KD: float = 0.30             # rad/s per unit/s of closing speed
const WALL_SEEK: float = 1.2            # rad/s turned toward a wall it has just lost touch of
const REACT_AHEAD: float = 13.0         # contact this close in front is not a correction, it is a
										# collision, and the ant recoils
const AVOID_TURN: float = 4.5           # rad/s, the recoil. Sharp on purpose: an ant that walks
										# into something turns sharply, and this now only fires on
										# real contact rather than on a distant prediction.
const WALL_HOLD: float = 0.7            # s of no contact at all before it stops following
const WALL_GOAL_DAMP: float = 0.20

# --- wander (correlated, never per-frame random) ----------------------------
const WANDER_MAX: float = 1.5         # rad/s of turn the bias can ask for
const WANDER_LERP: float = 1.8        # how fast the bias itself drifts to a new value

# --- trail ------------------------------------------------------------------
const DEPOSIT_EVERY: float = 7.0      # px of travel between drops
const DEPOSIT_AMOUNT: float = 1.15
const FADE_LENGTH: float = 2600.0     # travel over which a return's deposit decays to its floor

# --- homing -----------------------------------------------------------------
const PI_DRIFT: float = 0.07          # rad/s of error the dead-reckoned home vector accumulates
# Inside this the ant stops trusting its dead reckoning and steers at the nest itself. It is not a
# shortcut: a nest is a mound with an odour plume and landmarks around it, and a homing ant really
# does switch to them for the last stretch. Without it the ant is left steering by the ANGLE of a
# home vector that has shrunk to a few pixels -- which is noise, not a bearing. Measured: carriers
# reached 30-120px from the nest and then milled there, one of them walking 9,964px on a 654px
# errand, and two thirds of the colony was permanently carrying.
const NEST_SENSE_R: float = 92.0
# An ant slows as it comes into the nest mouth, and this is not decoration -- it is what makes the
# last few units possible at all. Delivery needs the ant INSIDE the entrance (AntColony.at_hole,
# 13 units), but a full-speed ant's tightest turn is speed / HOME_TURN, about 23 units across, so
# one that overshoots can circle the hole forever without ever being able to turn tightly enough to
# enter it. That is not hypothetical: one ant in a run carried a crumb for the whole of a 180 s
# level doing exactly that, which also kept the trail it was laying alive.
const NEST_CREEP: float = 0.55        # how much of its speed it gives up at the entrance
# A greeting used to be a hard freeze -- one frame walking, nine frames stock still, one frame
# walking. Each of those is a velocity discontinuity, and they scale with how crowded the trail is,
# which is why the jumpiness got worse as the colony organised itself. The ant now eases down and
# back up, so it reads as an ant stopping rather than as a dropped frame.
const PAUSE_EASE: float = 0.085       # seconds to slow to a stop, and the same to pick back up
# When dead reckoning says "you are home" and the nest is nowhere in range, the ant is lost, and
# path integration has no more to offer -- its error does not shrink by walking further. Desert
# ants answer this with a systematic search: widening loops around the spot the reckoning ran out,
# which is guaranteed to sweep the true nest eventually. Measured before it existed: two ants of
# forty stuck at 107px and 150px from home having walked 3,325 and 3,647px.
const LOST_R: float = 26.0            # |home_vec| below this means the reckoning has run out
const LOST_TURN: float = 3.0          # rad/s at the tightest, first loop
const LOST_LOOSEN: float = 0.35       # how fast the loops open out
const LOST_TURN_MIN: float = 0.12     # a loop this wide is already 467px across; wider is a
									  # straight line leaving the area, not a search of it
# A search cannot go on forever, and an ant that searches forever is not a curiosity -- it holds a
# crumb that the level is waiting on, and it keeps laying trail over ground it is lost on. Real
# ants abandon loads. Measured before this existed: three ants of forty still carrying after three
# minutes with the pile long empty, and the "unused" trail GREW while they circled.
const LOST_GIVEUP: float = 45.0
# The other way dead reckoning fails. LOST_R catches an ant whose vector has shrunk to nothing in
# the wrong place; this catches one whose vector is confidently WRONG and never shrinks at all. The
# ant found in a run that needed it was pinned against the world's rim at (11, 180) with its vector
# insisting home was 193 units away when it was 121: it steered into the edge, the edge turned it
# back, and it did that for the whole of a 180 s level, still carrying, keeping its trail alive.
#
# Stated as progress rather than as a place, so it covers any way of not arriving and not just the
# rim: a homing ant whose home vector has not got shorter in this long is not going home.
const HOME_STALE: float = 20.0

var pos: Vector2 = Vector2.ZERO
var heading: float = 0.0
var speed_scale: float = 1.0
var state: int = State.SEARCHING
var colony_idx: int = 0

# Path integration: where the nest is, as the ant believes it, accumulated from its own steps.
# Real ants navigate home this way, and unlike a second pheromone field it cannot strand anyone --
# a returning ant that loses the trail is the one failure that reads as broken rather than as
# nature. It drifts (PI_DRIFT), which is both true to life and what gives the returns their
# scatter; the nest's own short-range scent (NEST_SENSE_R) cleans up the last few pixels.
var home_vec: Vector2 = Vector2.ZERO
var nest_pos: Vector2 = Vector2.ZERO   # only ever consulted within NEST_SENSE_R

var wander_bias: float = 0.0
var stop_timer: float = 0.0           # antennation: two ants meeting stop and touch feelers
var contact_cd: float = 0.0           # so a crowded trail does not lock up in permanent greetings
var deposit_accum: float = 0.0
var travel_since_food: float = 0.0
var gait: float = 0.0                 # leg phase, purely cosmetic
var nest_pull: float = 0.0            # 0..1, how far the nest's own plume has taken over
# Being lost LATCHES, and only the nest itself clears it. Without the latch the ant oscillates:
# it spirals away from the phantom nest, which makes home_vec grow back past LOST_R, so it stops
# searching and walks back to the phantom, and repeats -- three ants of forty were still orbiting
# one at 135-161px out, having walked 2,144 to 3,676px. Once dead reckoning has lied there is no
# information left in it, and going back to it is the one thing that cannot work.
var lost: bool = false
var lost_time: float = 0.0            # seconds spent in the widening search for a mislaid nest
var lost_dir: float = 1.0             # which way this ant's search spiral turns
var pause_amt: float = 0.0            # 0..1, how far into a greeting's stop the ant is
var emerge_at: float = 0.0            # seconds into the level when this one leaves the nest
# Whether the crumb it is carrying came from bait. The ant neither knows nor cares -- it is the
# PLAYER who is not charged for these -- but something has to remember it between the pile and the
# nest, and the ant is what makes the journey.
var carrying_bait: bool = false
var best_home: float = INF            # closest its own reckoning has said it is, this trip
var stale_time: float = 0.0           # how long since that improved
var scent_cd: float = 0.0
var scent_turn: float = 0.0
var join_cd: float = 0.0
var join_want: float = 0.0            # bearing of the trail it is following
var joined: bool = false
var has_smelled_food: bool = false
var smelled_food: Vector2 = Vector2.ZERO
# Which way round it is hugging, LATCHED for WALL_HOLD after the last contact. Re-deciding every tick
# makes an ant oscillate at the point it touched and never get round -- the same failure, and the
# same fix, as the latched `lost` flag above.
# +1 = the wall is on this ant's right, -1 = on its left, 0 = not following one. LATCHED, because
# re-deciding every tick makes an ant oscillate where it touched and never get round.
var wall_side: float = 0.0
var wall_time: float = 0.0
var sweep_phase: float = 0.0
var wall_err: float = INF               # last contact error, for the derivative term

func _init(start: Vector2, dir: float, scale_factor: float, which_colony: int, home_at: Vector2) -> void:
	pos = start
	heading = dir
	speed_scale = scale_factor
	colony_idx = which_colony
	nest_pos = home_at
	wander_bias = randf_range(-WANDER_MAX, WANDER_MAX)
	gait = randf() * TAU
	# Unsynchronised, or the whole colony sweeps its antennae as one animal.
	sweep_phase = randf() * TAU
	scent_cd = randf() * SCENT_EVERY

func speed() -> float:
	return BASE_SPEED * speed_scale

# One tick of sensing and movement. Food, nest and neighbours are the level's business; this is
# only "where does my own head tell me to go".
func step(dt: float, marks: ScentMarks, world: Rect2, obstacles: Array, spray: Repellent) -> void:
	contact_cd = maxf(0.0, contact_cd - dt)
	if stop_timer > 0.0:
		stop_timer -= dt
	# Eased rather than switched, and the ant goes on steering while it slows -- that is what turns
	# a freeze into a pause, and it lets the two of them face each other as they meet.
	pause_amt = move_toward(pause_amt, 1.0 if stop_timer > 0.0 else 0.0, dt / PAUSE_EASE)

	# Correlated randomness: the bias EASES toward a new random value instead of being redrawn, so
	# the track is a meander. Redrawing per frame gives a jitter that reads as a bug.
	wander_bias = lerpf(wander_bias, randf_range(-WANDER_MAX, WANDER_MAX), clampf(dt * WANDER_LERP, 0.0, 1.0))

	var turn: float = 0.0
	var turn_cap: float = MAX_TURN
	if state == State.SEARCHING:
		scent_cd -= dt
		if scent_cd <= 0.0:
			scent_cd += SCENT_EVERY
			scent_turn = _follow_scent(marks, SCENT_EVERY)
		turn = scent_turn
	else:
		turn = _steer_home(dt)
		turn_cap = HOME_TURN

	var wander_w: float = 1.0
	if state == State.HOMING:
		# The search loops are a shape, and the wander would scribble over them: its ordinary
		# homing weight is of the same size as the turn the widest loop asks for.
		wander_w = 0.12 if lost else 0.35 * (1.0 - nest_pull)
	elif has_smelled_food:
		wander_w = 0.15
	turn += wander_bias * wander_w
	if spray != null and not spray.is_empty():
		turn += _turn_from_spray(spray)
	turn = clampf(turn, -turn_cap, turn_cap)
	if wall_side != 0.0:
		turn *= WALL_GOAL_DAMP
	heading = wrapf(heading + turn * dt, -PI, PI)

	# Applied to the heading the ant has just chosen, as a reflex on top of whatever it wanted --
	# so an ant rounding a stone is still homing, or still following its trail, the whole way.
	if not obstacles.is_empty():
		heading = wrapf(heading + _edge_turn(obstacles, dt) * dt, -PI, PI)

	var pace: float = speed() * (1.0 - pause_amt)
	if state == State.HOMING:
		pace *= 1.0 - NEST_CREEP * nest_pull
	var delta: Vector2 = Vector2.from_angle(heading) * pace * dt
	pos += delta
	gait += delta.length() * 0.62

	# Dead reckoning, with its error. Rotating the accumulated vector (rather than perturbing each
	# step) is what makes the error a slowly wandering BEARING, which is how the real thing fails.
	#
	# This is NOT the main source of error, and it is worth saying so because it looks like it
	# should be: over 200 s it comes to about 0.07 rad. What actually breaks an ant's reckoning is
	# being SHOVED -- level.gd separates overlapping ants by up to 4.5px a contact and the ant has
	# no way to know it moved, so a few hundred jostles in a busy column random-walk its estimate
	# some 35px off. That matched the ants found stuck 30-34px from where they believed home was.
	# It is left in deliberately: an ant really cannot feel being pushed, and the recovery below is
	# the interesting half of the behaviour.
	home_vec = (home_vec - delta).rotated(randf_range(-1.0, 1.0) * PI_DRIFT * dt)

	# Seeing home fixes home, whatever the ant was doing. A searcher that happens past its own
	# nest re-anchors, so error cannot accumulate across trip after trip -- without this an ant
	# sets out on its NEXT errand already carrying the last one's mistake.
	if pos.distance_squared_to(nest_pos) < NEST_SENSE_R * NEST_SENSE_R:
		home_vec = nest_pos - pos
		lost = false
		lost_time = 0.0
		best_home = INF
		stale_time = 0.0
	elif state == State.HOMING and lost and lost_time > LOST_GIVEUP:
		abandon_load()

	if state == State.HOMING and not lost:
		# Measured on the ant's own belief, because that is all it has: if the number it is
		# steering by is not coming down, the steering is not working.
		var reckon: float = home_vec.length()
		if reckon < best_home - 2.0:
			best_home = reckon
			stale_time = 0.0
		else:
			stale_time += dt
			if stale_time > HOME_STALE:
				lost = true
				lost_time = 0.0
	if state == State.HOMING:
		travel_since_food += delta.length()
		deposit_accum += delta.length()
		while deposit_accum >= DEPOSIT_EVERY:
			deposit_accum -= DEPOSIT_EVERY
			# A short return lays a strong trail and a long one lays a weak one, so once two routes
			# to the same food are both known the shorter one out-recruits the longer. This one
			# line is the whole of the positive feedback the colony runs on.
			var freshness: float = clampf(1.0 - travel_since_food / FADE_LENGTH, 0.25, 1.0)
			marks.deposit(pos, DEPOSIT_AMOUNT * freshness)

	_keep_inside(world)

# Two different questions, and which one the ant asks depends on where it is standing.
#
# OFF a trail it climbs a slope: three samples ahead of the head, turn toward the strongest. No
# gradient is computed and no neighbouring cell is read, because there are no cells -- these are
# three arbitrary points in continuous space.
#
# ON a trail it follows a ridge instead, because a ridge has no slope along it and the slope across
# it is symmetric. See JOIN_SCENT above for what that symmetry did.
func _follow_scent(marks: ScentMarks, dt: float) -> float:
	if has_smelled_food:
		# Steered at directly, and the wander is stood down with it (see step) -- an ant that can
		# smell the pile but strolls past it at 31 units is the whole of what this fixes.
		joined = false
		return wrapf((smelled_food - pos).angle() - heading, -PI, PI) * FOOD_TURN
	if marks.sense(pos) >= JOIN_SCENT:
		join_cd -= dt
		if not joined:
			join_cd = JOIN_EVERY
			join_want = _trail_bearing(marks)
			joined = true
		elif join_cd <= 0.0:
			join_cd = JOIN_EVERY
			# Eased, so a scan that reads slightly differently from the last one nudges the ant
			# rather than yanking it.
			join_want = lerp_angle(join_want, _trail_bearing(marks), JOIN_SETTLE)
		return wrapf(join_want - heading, -PI, PI) * JOIN_GAIN
	joined = false

	var l: float = marks.sense(pos + Vector2.from_angle(heading - ANTENNA_SPREAD) * ANTENNA_REACH)
	var c: float = marks.sense(pos + Vector2.from_angle(heading) * ANTENNA_REACH)
	var r: float = marks.sense(pos + Vector2.from_angle(heading + ANTENNA_SPREAD) * ANTENNA_REACH)
	if maxf(c, maxf(l, r)) < FOLLOW_THRESHOLD:
		return 0.0                      # nothing to smell: pure exploration
	if c >= l and c >= r:
		return 0.0                      # already on it
	# Proportional, not a fixed flick: a faint difference gives a faint correction, which is what
	# keeps an ant ON a trail rather than weaving across it.
	var diff: float = (r - l) / maxf(l + c + r, 0.001)
	return diff * FOLLOW_GAIN

# Which way the trail under the ant runs. Rays are limited to JOIN_ARC either side of the heading,
# so a crosser swings onto whichever end it was already facing rather than doubling back, and the
# two streams on a trail stay two streams instead of collapsing into one.
func _trail_bearing(marks: ScentMarks) -> float:
	# The two ends of a trail smell identical, so something has to break the tie. The ant's own
	# reckoning does it: a forager wants the end AWAY from home, and it already knows which that is.
	var away: Vector2 = Vector2.ZERO
	if home_vec.length_squared() > 1.0:
		away = -home_vec.normalized()
	var ray_step: float = 2.0 * JOIN_ARC / float(JOIN_RAYS - 1)
	var v: PackedFloat32Array = PackedFloat32Array()
	var best: int = 0
	for i in JOIN_RAYS:
		var a: float = heading - JOIN_ARC + ray_step * float(i)
		var sc: float = marks.sense(pos + Vector2.from_angle(a) * JOIN_REACH)
		if away != Vector2.ZERO:
			sc *= 1.0 + JOIN_AWAY_BIAS * Vector2.from_angle(a).dot(away)
		v.append(sc)
		if sc > v[best]:
			best = i
	# The strongest RAY is not the strongest bearing: nine rays across 200 degrees quantise the
	# answer to 0.44 rad, and re-picking one every JOIN_EVERY made an ant on a trail weave between
	# two of them. Fitting a parabola through the peak and its neighbours gives a bearing that moves
	# continuously as the ant does. A weighted mean of all nine cannot be used instead: a crosser
	# sees BOTH ends of the trail inside the arc and they would cancel.
	var off: float = 0.0
	if best > 0 and best < JOIN_RAYS - 1:
		var denom: float = v[best - 1] - 2.0 * v[best] + v[best + 1]
		if absf(denom) > 0.0001:
			off = clampf(0.5 * (v[best - 1] - v[best + 1]) / denom, -0.5, 0.5)
	return heading - JOIN_ARC + ray_step * (float(best) + off)

func _steer_home(dt: float) -> float:
	var to_nest: Vector2 = nest_pos - pos
	var d: float = to_nest.length()
	nest_pull = clampf((NEST_SENSE_R - d) / maxf(NEST_SENSE_R - 20.0, 1.0), 0.0, 1.0)
	if nest_pull > 0.0:
		lost = false
		lost_time = 0.0
		var want: float = to_nest.angle()
		if home_vec.length_squared() >= 1.0:
			want = lerp_angle(home_vec.angle(), to_nest.angle(), nest_pull)
		return wrapf(want - heading, -PI, PI) * 4.0
	if lost or home_vec.length_squared() < LOST_R * LOST_R:
		lost = true
		lost_time += dt
		# One sign, held: alternating would retrace the same ground instead of opening outward.
		return lost_dir * maxf(LOST_TURN / (1.0 + lost_time * LOST_LOOSEN), LOST_TURN_MIN)
	return wrapf(home_vec.angle() - heading, -PI, PI) * 4.0

# The nearest heading to the one it wants that does not walk it into something. Fanning whiskers
# out to either side, in order, so the ant deviates as little as it has to -- which is what makes
# the track hug the edge instead of bouncing off it.
# How hard to turn, this tick, because of something solid. Returns a RATE.
func _edge_turn(obstacles: Array, dt: float) -> float:
	sweep_phase += ANTENNA_SWEEP_RATE * dt
	var sweep: float = sin(sweep_phase) * ANTENNA_SWEEP_AMP

	var ahead: float = _feel(obstacles, heading + sweep * 0.4, ANTENNA_REACH)
	var right: float = _feel(obstacles, heading + ANTENNA_SPREAD + sweep, ANTENNA_REACH)
	var left: float = _feel(obstacles, heading - ANTENNA_SPREAD + sweep, ANTENNA_REACH)

	# LET GO once the way it actually wants to go is open. Following had no exit condition at all:
	# an ant stayed glued until it ran out of wall, and a TWIG never runs out. It is 152 units long
	# and 18 wide, so an ant reaching a tip loses contact, WALL_SEEK curls it back, and on something
	# that thin it re-acquires the OPPOSITE FACE -- then follows back down, round the far tip, and
	# round again. Measured: a single twig across a road left 22 of 39 ants clinging to it and the
	# delivery rate falling away, 57 crumbs per 40 s down to [35, 27, 20], while a stone and a pool
	# on the same spot cost almost nothing. Fat shapes hide the bug because losing their surface for
	# WALL_HOLD is easy; a thin one is a racetrack.
	#
	# This is the exit condition every wall-following algorithm needs and this one was missing.
	if wall_side != 0.0 and ahead >= REACT_AHEAD:
		var goal: float = _goal_bearing()
		if goal != INF and is_inf(_feel(obstacles, goal, ANTENNA_REACH)):
			wall_side = 0.0
			wall_err = INF
			wall_time = 0.0
			return 0.0

	if ahead < REACT_AHEAD:
		# A collision, not a correction. Commit to a side if there is not one already -- toward
		# whichever antenna is NOT touching, or the one touching further off.
		if wall_side == 0.0:
			wall_side = 1.0 if right < left else -1.0
		wall_time = WALL_HOLD
		wall_err = INF
		return -wall_side * AVOID_TURN

	var touch: float = right if wall_side > 0.0 else left
	if wall_side == 0.0:
		if minf(left, right) >= ANTENNA_REACH:
			return 0.0                  # nothing within reach of either feeler
		wall_side = 1.0 if right < left else -1.0
		touch = minf(left, right)

	if touch >= ANTENNA_REACH:
		# Lost it. Turning gently back toward where it was is how an ant gets round the OUTSIDE of
		# a corner; it is also what lets go of a wall that has genuinely ended, once WALL_HOLD of
		# empty sweeps have passed.
		wall_time -= dt
		if wall_time <= 0.0:
			wall_side = 0.0
			wall_err = INF
			return 0.0
		wall_err = INF
		return wall_side * WALL_SEEK

	wall_time = WALL_HOLD
	var err: float = touch - WALL_GAP       # positive: drifting away from the wall
	var rate: float = 0.0
	if wall_err != INF and dt > 0.0:
		rate = clampf((err - wall_err) / dt, -60.0, 60.0)
	wall_err = err
	return clampf(wall_side * (WALL_KP * err + WALL_KD * rate), -AVOID_TURN, AVOID_TURN)

# Down the gradient of the stuff, sampled at the same two points the ant already smells with. It is
# added to whatever the ant wanted rather than replacing it, so a laden ant fighting to get home
# will push through a weak patch while an idle one is turned by it.
func _turn_from_spray(spray: Repellent) -> float:
	var l: float = spray.sense(pos + Vector2.from_angle(heading - ANTENNA_SPREAD) * ANTENNA_REACH)
	var r: float = spray.sense(pos + Vector2.from_angle(heading + ANTENNA_SPREAD) * ANTENNA_REACH)
	if maxf(l, r) < AVERSION_FELT:
		return 0.0
	var away: float = (l - r) / maxf(l + r, 0.001)
	return away * AVERSION

# Where the ant would go if nothing were in the way -- the bearing its own business gives it. INF
# when it has no opinion, in which case following simply continues.
func _goal_bearing() -> float:
	if state == State.HOMING:
		if nest_pull > 0.0:
			return (nest_pos - pos).angle()
		if home_vec.length_squared() > 1.0:
			return home_vec.angle()
		return INF
	if has_smelled_food:
		return (smelled_food - pos).angle()
	if joined:
		return join_want
	return INF

# One antenna. Marched outwards from the head until it meets something, which is the reading a real
# one gives: a contact distance, or nothing at all.
func _feel(obstacles: Array, ang: float, reach: float) -> float:
	var from: Vector2 = pos + Vector2.from_angle(heading) * (LENGTH * 0.36)
	var dir: Vector2 = Vector2.from_angle(ang)
	var d: float = 1.5
	while d <= reach:
		for o: AntObstacle in obstacles:
			if o.contains(from + dir * d):
				return d
		d += 1.5
	return INF

# The wall turns an ant back rather than stopping it dead against it. The rect passed in is the
# WALKABLE area, which is inset from the world by the wall's own width -- so an ant is turned at the
# wall's inner face and its body never overlaps the border it is being stopped by.
func _keep_inside(world: Rect2) -> void:
	var margin: float = body_len() * 0.55
	var lo: Vector2 = world.position + Vector2(margin, margin)
	var hi: Vector2 = world.position + world.size - Vector2(margin, margin)
	var bounced: bool = false
	if pos.x < lo.x or pos.x > hi.x:
		heading = PI - heading
		bounced = true
	if pos.y < lo.y or pos.y > hi.y:
		heading = -heading
		bounced = true
	if bounced:
		heading = wrapf(heading, -PI, PI)
		pos.x = clampf(pos.x, lo.x, hi.x)
		pos.y = clampf(pos.y, lo.y, hi.y)
		wander_bias = -wander_bias

func pick_up_food() -> void:
	state = State.HOMING
	joined = false
	has_smelled_food = false
	best_home = INF
	stale_time = 0.0
	travel_since_food = 0.0
	deposit_accum = 0.0
	lost = false
	lost_time = 0.0
	lost_dir = 1.0 if randf() < 0.5 else -1.0
	stop_timer = maxf(stop_timer, randf_range(PICKUP_PAUSE[0], PICKUP_PAUSE[1]))
	heading = wrapf(heading + PI + randf_range(-0.5, 0.5), -PI, PI)

func drop_food() -> void:
	state = State.SEARCHING
	home_vec = Vector2.ZERO
	joined = false
	# It waits in the entrance before turning back out, which is what makes a delivery look like
	# one. Longer than a pickup: it is going down and coming back up.
	stop_timer = maxf(stop_timer, randf_range(DEPOSIT_PAUSE[0], DEPOSIT_PAUSE[1]))
	heading = wrapf(heading + PI + randf_range(-0.9, 0.9), -PI, PI)

# The crumb is simply lost -- there is nowhere sensible for it to go, and an ant that has been
# searching for three quarters of a minute has carried it a long way from anywhere.
# A shove from a neighbour. The displacement is applied by level.gd, already rate-limited; the ant
# answers the rest of it by LEANING, so a crowded ant steps around its neighbour instead of being
# slid sideways like a piece on a board.
func shove(v: Vector2, dt: float) -> void:
	if v == Vector2.ZERO or dt <= 0.0:
		return
	pos += v
	# Weighted by how big the shove is against the ant's own stride, so a brush past a neighbour
	# barely registers and being properly barged turns the ant.
	var w: float = clampf(v.length() / maxf(speed() * dt, 0.0001), 0.0, 1.0)
	var want: float = clampf(wrapf(v.angle() - heading, -PI, PI), -1.0, 1.0)
	heading = wrapf(heading + want * SHOVE_TURN * w * dt, -PI, PI)

func abandon_load() -> void:
	state = State.SEARCHING
	lost = false
	lost_time = 0.0
	best_home = INF
	stale_time = 0.0
	home_vec = Vector2.ZERO

func greet() -> void:
	stop_timer = randf_range(0.10, 0.22)
	contact_cd = randf_range(0.8, 1.4)
