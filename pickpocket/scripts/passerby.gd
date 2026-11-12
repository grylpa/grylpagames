extends Node2D

# ONE PASSER-BY on Pickpocket's street, drawn in code at its FEET (position = where it stands).
# Seen from the side, walking left or right.
#
# DRAWN AS A PERSON, NOT A TOY: adult proportions (the head about an eighth of the height), limbs
# as tapered shapes that bend at the knee and the elbow, clothes and skin SHADED -- lit from above
# and from the side the street light comes from (`light_dir`, set by the level from the nearest
# lamp), dimmer between lamps, with a warm rim on the lit edge. The first version was circles and
# straight lines in flat colors, which read as a children's book.
#
# Every person must be told apart from the others at a glance, out of the corner of the eye and
# then again once the street freezes, so the look is built from several independent traits: the
# coat's color and cut, a hat or a hairstyle, a bag, the skin, the height. The level keeps coat
# colors unique among the people on the street at once.
#
# A person never carries a visible wallet. One drawn on everyone would let a player find the
# victim afterwards by scanning for the one without it, without having seen anything happen.

const COATS: Array = [
	Color(0.66, 0.17, 0.16),   # red
	Color(0.17, 0.26, 0.50),   # navy blue
	Color(0.78, 0.59, 0.19),   # mustard
	Color(0.21, 0.45, 0.28),   # green
	Color(0.44, 0.26, 0.52),   # plum
	Color(0.68, 0.53, 0.36),   # camel
	Color(0.16, 0.52, 0.56),   # teal
	Color(0.48, 0.49, 0.51),   # gray
	Color(0.82, 0.42, 0.17),   # rust orange
	Color(0.80, 0.49, 0.59),   # dusty pink
	Color(0.88, 0.85, 0.78),   # stone
	Color(0.30, 0.21, 0.16),   # brown
]
const PANTS: Array = [Color(0.13, 0.14, 0.18), Color(0.19, 0.25, 0.40), Color(0.32, 0.27, 0.22),
	Color(0.27, 0.28, 0.30), Color(0.10, 0.10, 0.11), Color(0.42, 0.38, 0.32)]
const SKINS: Array = [Color(0.93, 0.77, 0.64), Color(0.85, 0.65, 0.50), Color(0.69, 0.49, 0.34),
	Color(0.52, 0.36, 0.24), Color(0.36, 0.24, 0.17)]
const HAIRS: Array = [Color(0.09, 0.07, 0.06), Color(0.30, 0.19, 0.11), Color(0.70, 0.54, 0.30),
	Color(0.55, 0.25, 0.12), Color(0.70, 0.70, 0.70)]
const HAT_COLORS: Array = [Color(0.12, 0.12, 0.14), Color(0.45, 0.12, 0.13), Color(0.20, 0.30, 0.22),
	Color(0.70, 0.66, 0.58), Color(0.26, 0.34, 0.55)]
const BAG_COLORS: Array = [Color(0.38, 0.22, 0.12), Color(0.12, 0.12, 0.13), Color(0.55, 0.12, 0.17),
	Color(0.72, 0.58, 0.36)]

enum Hat { NONE, CAP, BEANIE, FEDORA, BOWLER }
enum Hair { SHORT, LONG, BUN, BALD, CURLY }
enum Bag { NONE, SHOULDER, BACKPACK }
enum Mark { NONE, HOVER, VICTIM, THIEF, PICKED_RIGHT, PICKED_WRONG }

const WARM: Color = Color(1.0, 0.82, 0.55)   # the street light's color, for the rim

# --- look ---
var h: float = 110.0          # height in px, feet to crown
var coat_idx: int = 0
var long_coat: bool = false
var pants: Color = PANTS[0]
var skin: Color = SKINS[0]
var hair_col: Color = HAIRS[0]
var hair: int = Hair.SHORT
var hat: int = Hat.NONE
var hat_col: Color = HAT_COLORS[0]
var bag: int = Bag.NONE
var bag_col: Color = BAG_COLORS[0]
var scarf: bool = false
var scarf_col: Color = Color.WHITE
var build: float = 1.0        # 0.9 slight .. 1.12 broad
# THE BODY IS SEEN FROM THE SIDE (2026-11-12): the head, legs and arms always were, but the coat was
# drawn at a front view's breadth -- 0.22 of the height across, where a chest seen side-on is about
# 0.15 -- so everyone looked barrel-chested. Every torso measure across the figure is scaled by this.
const DEPTH: float = 0.68

# --- motion (the level moves it; these are only what the drawing needs) ---
var dir: int = 1              # +1 faces right, -1 faces left
var phase: float = 0.0        # walk cycle, advanced by distance
var walking: bool = true
var reach: float = 0.0        # 0..1: the front arm reaching forward (the lift)
var reach_at: Vector2 = Vector2.INF   # where the reaching hand goes (local); INF = straight ahead
var jolt: float = 0.0         # 0..1: a startled start (the easy levels' cue)
var mark: int = Mark.NONE
var tag: String = ""
var tag_raise: float = 0.0    # lifts the tag a line, so two neighbors' tags do not overlap
var light_dir: float = 0.0    # -1 lit from the left .. +1 from the right
var light_amt: float = 0.5    # 0 in the dark between lamps .. 1 right under one
var idle: float = 0.0         # a slow clock for someone standing: breath and a shift of weight

# SOMEONE STANDING IS NEVER STILL (tick_idle): they breathe, shift their weight from foot to foot,
# lean, glance away and back, and every few seconds change what their hands are doing -- a hand to
# the chin, a hand on the hip, arms hanging. Each of these eases in and out. `excite` (0..1, set
# by the level for the onlookers during the shuffle) leans them in toward the table.
var excite: float = 0.0
var _w_chin: float = 0.0
var _w_hip: float = 0.0
var _w_far_hip: float = 0.0
var _lean: float = 0.0
var _glance: float = 0.0      # 0 looking the way they face .. 1 head turned the other way
var _want: Dictionary = {"chin": 0.0, "hip": 0.0, "far_hip": 0.0, "lean": 0.0, "glance": 0.0}
var _next_change: float = 0.0
var _clock: float = 0.0

func tick_idle(dt: float, rng: RandomNumberGenerator) -> void:
	_clock += dt
	idle += dt * 1.6
	if _clock >= _next_change:
		_next_change = _clock + rng.randf_range(1.8, 4.5)
		var r: float = rng.randf()
		_want["chin"] = 1.0 if r < 0.22 else 0.0
		_want["hip"] = 1.0 if r >= 0.22 and r < 0.42 else 0.0
		_want["far_hip"] = 1.0 if rng.randf() < 0.25 else 0.0
		_want["lean"] = rng.randf_range(-0.025, 0.035)
	var k: float = 1.0 - exp(-3.5 * dt)
	var ex: float = clampf(excite, 0.0, 1.0)
	_w_chin = lerpf(_w_chin, float(_want["chin"]) * (1.0 - ex), k)
	_w_hip = lerpf(_w_hip, float(_want["hip"]) * (1.0 - ex * 0.5), k)
	_w_far_hip = lerpf(_w_far_hip, float(_want["far_hip"]), k)
	_lean = lerpf(_lean, float(_want["lean"]) + ex * 0.07, k)
	queue_redraw()

# NOTHING ON A PERSON CHANGES IN ONE FRAME (2026-11-12). Three things did: the head's glance back
# flipped it from one profile to the other, a pickpocket doubling back was mirrored on the spot, and
# setting off or stopping snapped the legs between stride and stance and the arms out of a pose (a
# hand on the hip jumped to a walking swing). Now:
#   _glance  0..1 eases over TURN_S: the head narrows toward a front view, then widens the other way
#   _face    -1..1 eases toward `dir` the same way, for the whole figure (a turn on the spot)
#   _gait    0 standing .. 1 walking, eased over GAIT_S: stride, stance, swing, poses and lean blend
# All three move in tick_motion, which the level calls for everyone every frame the street is live.
const TURN_S: float = 0.24
const GAIT_S: float = 0.30
# The narrowest a figure (or a head) gets mid-turn, as a share of its width. Only a hint of the turn:
# a person seen from the front is WIDER, not thinner, so a deep squash (0.30 was tried) left a paper
# sliver in the middle of every turn.
const TURN_MIN_W: float = 0.55
const HEAD_TURN_MIN_W: float = 0.60

# A GLANCE BACK IS A MOMENT: now and then anyone, standing or walking, looks back over their shoulder
# for half a second to a second, then ahead again. It was a standing fidget held until the next change
# of pose, so one caught as they set off kept the head turned for the whole walk (someone walking
# right to left, looking right). Not while an onlooker is watching the cups.
var _glance_left: float = 0.0     # seconds left of the glance under way
var _glance_wait: float = -1.0    # seconds to the next one
var _face: float = 0.0            # 0 = not set yet (takes `dir` at the first tick)
var _gait: float = -1.0           # < 0 = not set yet (takes `walking` at the first tick)

func tick_motion(dt: float, rng: RandomNumberGenerator, may_glance: bool) -> void:
	if _glance_wait < 0.0:
		_glance_wait = rng.randf_range(2.0, 9.0)
	if not may_glance:
		_glance_left = 0.0
	elif _glance_left > 0.0:
		_glance_left -= dt
	else:
		_glance_wait -= dt
		if _glance_wait <= 0.0:
			_glance_wait = rng.randf_range(5.0, 12.0) if walking else rng.randf_range(3.0, 8.0)
			if excite < 0.3:
				_glance_left = rng.randf_range(0.5, 1.1)
	_glance = move_toward(_glance, 1.0 if _glance_left > 0.0 else 0.0, dt / TURN_S)
	if _face == 0.0:
		_face = float(dir)
	_face = move_toward(_face, float(dir), dt * 2.0 / TURN_S)
	if _gait < 0.0:
		_gait = 1.0 if walking else 0.0
	_gait = move_toward(_gait, 1.0 if walking else 0.0, dt / GAIT_S)
	queue_redraw()

# 0 standing .. 1 walking, smoothed
func _g() -> float:
	if _gait < 0.0:
		return 1.0 if walking else 0.0
	return _gait * _gait * (3.0 - 2.0 * _gait)

# The whole figure's x scale: 1 facing `dir`, through TURN_MIN_W, to -1 (still facing the old way).
func _body_sx() -> float:
	var v: float = 1.0 if _face == 0.0 else _face * float(dir)
	return (1.0 if v >= 0.0 else -1.0) * maxf(absf(v), TURN_MIN_W)

# The head: which way it faces (+1 = with the body) and how wide it is drawn, mid-glance.
func _head_turn() -> Vector2:
	var e: float = _glance * _glance * (3.0 - 2.0 * _glance)
	return Vector2(1.0 if e < 0.5 else -1.0, maxf(absf(cos(PI * e)), HEAD_TURN_MIN_W))

# --- the level's bookkeeping, kept on the node ---
var lane: int = 0
var speed: float = 60.0       # px per second while walking
var stand_until: float = -1.0 # game ms; >= 0 while standing
var stand_at_x: float = -1.0  # walk to here, then stand (a window shopper); < 0 = never
var stand_ms: float = 0.0
var role: int = 0             # 0 none, 1 victim, 2 thief (this round)
var plan: Dictionary = {}     # the thief's script

static var _shadow_tex: GradientTexture2D = null
# Every shape drawn this frame (local, before the lean): the person's exact body, for taps.
var _hits: Array = []
var _hit_rot: float = 0.0
var _hit_sx: float = 1.0

func randomize_look(rng: RandomNumberGenerator, _coat_idx: int) -> void:
	coat_idx = _coat_idx
	long_coat = rng.randf() < 0.45
	pants = PANTS[rng.randi() % PANTS.size()]
	skin = SKINS[rng.randi() % SKINS.size()]
	hair_col = HAIRS[rng.randi() % HAIRS.size()]
	hair = rng.randi() % 5
	hat = Hat.NONE if rng.randf() < 0.45 else 1 + rng.randi() % 4
	hat_col = HAT_COLORS[rng.randi() % HAT_COLORS.size()]
	if hat == Hat.NONE and hair == Hair.BALD and rng.randf() < 0.5:
		hair = Hair.SHORT
	var b: float = rng.randf()
	bag = Bag.NONE if b < 0.5 else (Bag.SHOULDER if b < 0.78 else Bag.BACKPACK)
	bag_col = BAG_COLORS[rng.randi() % BAG_COLORS.size()]
	scarf = rng.randf() < 0.3
	scarf_col = Color.from_hsv(rng.randf(), 0.45, 0.75)
	build = rng.randf_range(0.92, 1.12)

func coat() -> Color:
	return COATS[coat_idx]

# Where a hand would take a wallet from: the back pocket, at the rear hip.
func pocket_point() -> Vector2:
	return position + Vector2(-float(dir) * 0.085 * DEPTH * h * build, -0.50 * h)

# The thief's reaching hand, in street coordinates.
func hand_point() -> Vector2:
	return position + (_arm_points(true)[2] as Vector2)

# Where the near hand's fingers close on something it holds (the wallet), in street coordinates:
# a little past the palm, along the forearm.
func grip_point() -> Vector2:
	var p: Array = _arm_points(true)
	var hdir: Vector2 = ((p[2] as Vector2) - (p[1] as Vector2)).normalized()
	return position + (p[2] as Vector2) + hdir * 0.030 * h

# The thief's own coat pocket, at the front hip, in street coordinates: where a lifted wallet goes.
func stash_point() -> Vector2:
	return position + Vector2(float(dir) * 0.075 * DEPTH * h * build, -0.52 * h + _bob())

# THE TOP CENTER OF THE HEAD, in street coordinates -- of the hat when there is one -- exactly as
# drawn: following the bob, the glance and the lean. The answer tag's pointer ends here, touching
# the crown (it used to stop at a fixed height, floating above some people and inside others).
func head_top() -> Vector2:
	var hd: float = float(dir) * _head_turn().x
	var hc: Vector2 = Vector2(0.010 * h * hd, -0.925 * h + _bob())
	var crown: float = 0.066
	match hat:
		Hat.CAP:
			crown = 0.078
		Hat.BEANIE:
			crown = 0.090
		Hat.FEDORA:
			crown = 0.099
		Hat.BOWLER:
			crown = 0.096
	if hat == Hat.NONE and (hair == Hair.SHORT or hair == Hair.LONG or hair == Hair.BUN):
		crown = 0.073
	elif hat == Hat.NONE and hair == Hair.CURLY:
		crown = 0.075
	var top: Vector2 = hc + Vector2(0.0, -crown * h)
	var lean: float = _lean * (1.0 - _g())
	if absf(lean) > 0.0005:
		top = top.rotated(lean * float(dir))
	return position + top

# Is a point (street coordinates) on this person's body, exactly as drawn?
func hit(pt: Vector2) -> bool:
	var local: Vector2 = (pt - position).rotated(-_hit_rot)
	local.x /= _hit_sx
	for poly in _hits:
		if Geometry2D.is_point_in_polygon(local, poly):
			return true
	return false

# A rough box round the whole figure (a fallback for a tap that lands just off every body).
func body_rect() -> Rect2:
	return Rect2(position + Vector2(-0.20 * h, -1.02 * h), Vector2(0.40 * h, 1.04 * h))

func advance(dist: float) -> void:
	phase += dist / (0.62 * h) * PI
	queue_redraw()

func set_mark(m: int, text: String = "") -> void:
	mark = m
	tag = text
	queue_redraw()

# --- light -------------------------------------------------------------------

# A color as the street lights it at a point of the figure: brighter higher up (the lamps are
# above), brighter on the side the light comes from, dimmer in the dark between lamps, and pulled
# toward amber where the lamps reach.
func _lit(c: Color, p: Vector2) -> Color:
	var up: float = clampf(-p.y / h, 0.0, 1.0)
	var side: float = clampf(p.x / (0.13 * DEPTH * h * build), -1.0, 1.0) * light_dir
	# (2026-11-10 facelift: a wider range from the lit side to the far one, and the far side falls
	# toward the evening's blue instead of merely darker -- warm light, cool shadow)
	var k: float = 0.58 + 0.20 * up + 0.26 * side + 0.26 * light_amt
	var out: Color = Color(c.r * k, c.g * k, c.b * k, c.a)
	var warm: float = clampf(0.25 + 0.55 * side, 0.0, 1.0) * light_amt
	out = out.lerp(Color(minf(1.0, out.r * 1.14), out.g * 1.00, out.b * 0.80, c.a), warm)
	var cool: float = clampf(-side, 0.0, 1.0) * 0.55
	return out.lerp(Color(out.r * 0.78, out.g * 0.86, minf(1.0, out.b * 1.14), c.a), cool)

func _poly(pts: PackedVector2Array, c: Color) -> void:
	_hits.append(pts)
	var cols: PackedColorArray = PackedColorArray()
	for p in pts:
		cols.append(_lit(c, p))
	if Geometry2D.triangulate_polygon(pts).is_empty():
		var hull: PackedVector2Array = Geometry2D.convex_hull(pts)
		if hull.size() >= 4:
			hull.remove_at(hull.size() - 1)
			draw_colored_polygon(hull, cols[0])
		return
	draw_polygon(pts, cols)

# A limb segment: a tapered shape from a (radius ra) to b (radius rb), round at both ends.
func _limb(a: Vector2, b: Vector2, ra: float, rb: float, c: Color) -> void:
	var pts: PackedVector2Array = _limb_pts(a, b, ra, rb)
	if not pts.is_empty():
		_poly(pts, c)

# The same shape, grown by `pad` and filled flat, under a limb: its contour. Not hit-tested.
func _limb_edge(a: Vector2, b: Vector2, ra: float, rb: float, pad: float, c: Color) -> void:
	var pts: PackedVector2Array = _limb_pts(a, b, ra + pad, rb + pad)
	if not pts.is_empty():
		draw_colored_polygon(pts, c)

func _limb_pts(a: Vector2, b: Vector2, ra: float, rb: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var d: Vector2 = b - a
	if d.length() < 0.01:
		return pts
	var u: Vector2 = d.normalized()
	var n: Vector2 = u.orthogonal()
	var segs: int = 5
	for k in segs + 1:
		var ang: float = PI * float(k) / float(segs)
		pts.append(b + (n * cos(ang) + u * sin(ang)) * rb)
	for k in segs + 1:
		var ang2: float = PI * float(k) / float(segs)
		pts.append(a + (-n * cos(ang2) - u * sin(ang2)) * ra)
	return pts

func _ellipse_pts(c: Vector2, rx: float, ry: float, n: int = 18) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for k in n:
		var a: float = TAU * float(k) / float(n)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

# --- the pose ----------------------------------------------------------------

func _bob() -> float:
	var b: float = lerpf(sin(idle) * 0.004 * h, -absf(cos(phase)) * 0.014 * h, _g())
	return b - sin(jolt * PI) * 0.05 * h

# Hip, knee, ankle of one leg.
func _leg_points(front: bool) -> Array:
	var y0: float = _bob()
	var d: float = float(dir)
	var hip: Vector2 = Vector2(0.0, -0.50 * h + y0)
	var ph: float = phase + (0.0 if front else PI)
	var shift: float = sin(idle * 0.35) * 0.06
	var g: float = _g()
	var s: float = lerpf((0.10 + shift) if front else (-0.06 + shift), sin(ph), g)
	var thigh_a: float = s * 0.40                      # radians off vertical, + = forward
	# the knee bends as the leg swings through
	var bend: float = lerpf(0.04 + maxf(0.0, (shift if front else -shift)) * 2.0, maxf(0.0, cos(ph)) * 0.80 + 0.06, g)
	var knee: Vector2 = hip + Vector2(sin(thigh_a) * d, cos(thigh_a)) * 0.25 * h
	var shin_a: float = thigh_a - bend
	var ankle: Vector2 = knee + Vector2(sin(shin_a) * d, cos(shin_a)) * 0.24 * h
	if ankle.y > -0.028 * h:
		ankle.y = -0.028 * h
	return [hip, knee, ankle]

# Shoulder, elbow, hand.
func _arm_points(front: bool) -> Array:
	var y0: float = _bob()
	var d: float = float(dir)
	var sh: Vector2 = Vector2(-0.005 * h * d, -0.79 * h + y0)
	var ph: float = phase + (PI if front else 0.0)
	var g: float = _g()
	var s: float = lerpf(0.03, sin(ph) * 0.36, g)
	var elbow: Vector2 = sh + Vector2(sin(s) * d, cos(s)) * 0.165 * h
	var fa: float = s + 0.22 + maxf(0.0, s) * 0.55
	var hand: Vector2 = elbow + Vector2(sin(fa) * d, cos(fa)) * 0.15 * h
	# the standing poses fade as they walk (and come back as they stop); the hip is at the side-on body's
	# edge (DEPTH), not the old front-view one
	var st: float = 1.0 - g
	if st > 0.0:
		var y1: float = y0
		if front:
			var chin_h: Vector2 = Vector2(0.055 * h * d, -0.865 * h + y1)
			var chin_e: Vector2 = Vector2(0.06 * h * d, -0.64 * h + y1)
			var hip_h: Vector2 = Vector2(0.058 * h * d * build, -0.53 * h + y1)
			var hip_e: Vector2 = Vector2(0.11 * h * d, -0.65 * h + y1)
			elbow = elbow.lerp(chin_e, _w_chin * st).lerp(hip_e, _w_hip * st)
			hand = hand.lerp(chin_h, _w_chin * st).lerp(hip_h, _w_hip * st)
		else:
			var fh_h: Vector2 = Vector2(-0.058 * h * d * build, -0.53 * h + y1)
			var fh_e: Vector2 = Vector2(-0.11 * h * d, -0.65 * h + y1)
			elbow = elbow.lerp(fh_e, _w_far_hip * st)
			hand = hand.lerp(fh_h, _w_far_hip * st)
	if front and reach > 0.0:
		var out_e: Vector2 = sh + Vector2(0.09 * h * d, 0.14 * h)
		var out_h: Vector2 = Vector2(0.26 * h * d, -0.52 * h + y0)
		if reach_at != Vector2.INF:
			out_h = reach_at
			out_e = (sh + out_h) * 0.5 + Vector2(-0.03 * h * d, 0.06 * h)
		elbow = elbow.lerp(out_e, reach)
		hand = hand.lerp(out_h, reach)
	return [sh, _elbow_for(sh, hand, elbow), hand]

const UPPER_ARM: float = 0.165   # in h
const FOREARM: float = 0.15

# THE ELBOW FROM THE SHOULDER AND THE HAND (2026-11-12): two-bone IK at the arm's true lengths, the
# elbow always on the side an elbow bends -- behind and below the line from shoulder to hand, for
# someone facing `dir`. Each pose used to place its elbow by hand: the hand on the hip put it in front
# of that line (an elbow bent backwards), and blending between poses could swing it across. `hint`
# (the pose's own elbow) is used only for a hand right at the shoulder, where any side will do.
func _elbow_for(sh: Vector2, hand: Vector2, hint: Vector2) -> Vector2:
	var a: float = UPPER_ARM * h
	var b: float = FOREARM * h
	var v: Vector2 = hand - sh
	var dist: float = v.length()
	if dist < 0.001 * h:
		return hint
	var u: Vector2 = v / dist
	if dist >= a + b:
		return sh + u * (dist * a / (a + b))          # out of reach: a straight arm
	dist = maxf(dist, absf(a - b) + 0.001 * h)
	var x: float = (a * a - b * b + dist * dist) / (2.0 * dist)
	var y: float = sqrt(maxf(0.0, a * a - x * x))
	# n: the side for which cross(v, elbow - sh) * dir > 0 (y grows downward)
	var n: Vector2 = Vector2(-u.y, u.x) * float(dir)
	return sh + u * x + n * y

# --- drawing -----------------------------------------------------------------

func _draw() -> void:
	var y0: float = _bob()
	var d: float = float(dir)
	var c: Color = coat()
	var bw: float = build * DEPTH

	_draw_ground_marks()
	_hits.clear()
	_hit_rot = 0.0
	_hit_sx = _body_sx()
	# the whole figure leans from the feet (standing), and narrows through a turn on the spot
	var lean: float = _lean * (1.0 - _g())
	if absf(lean) > 0.0005:
		_hit_rot = lean * float(dir)
	if _hit_rot != 0.0 or _hit_sx != 1.0:
		draw_set_transform(Vector2.ZERO, _hit_rot, Vector2(_hit_sx, 1.0))

	# the far leg and arm first, in shade
	_draw_leg(_leg_points(false), pants.darkened(0.28))
	_draw_arm(_arm_points(false), c.darkened(0.32), false)
	if bag == Bag.BACKPACK:
		var bx: float = -d * 0.15 * h * bw
		_poly(_round_box(Vector2(bx, -0.66 * h + y0), Vector2(0.07 * h, 0.12 * h), 0.03 * h), bag_col)
		_poly(_round_box(Vector2(bx - d * 0.02 * h, -0.60 * h + y0), Vector2(0.05 * h, 0.04 * h), 0.015 * h), bag_col.darkened(0.2))
	_draw_leg(_leg_points(true), pants)

	# the coat: neck, sloping shoulders, waist, a hem that flares; lit by _lit
	var hem: float = (-0.30 if long_coat else -0.47) * h + y0
	var top: float = -0.83 * h + y0
	var waist: float = -0.58 * h + y0
	var sw: float = 0.110 * h * bw
	var ww: float = 0.082 * h * bw
	var hw: float = (0.120 if long_coat else 0.095) * h * bw
	var body: PackedVector2Array = PackedVector2Array([
		Vector2(-0.034 * h, top - 0.012 * h), Vector2(0.034 * h, top - 0.012 * h),
		Vector2(sw * 0.82, top + 0.010 * h), Vector2(sw, top + 0.040 * h),
		Vector2(sw * 0.94, top + 0.150 * h), Vector2(ww, waist),
		Vector2(hw * 0.95, (hem + waist) * 0.5), Vector2(hw, hem),
		Vector2(-hw, hem), Vector2(-hw * 0.95, (hem + waist) * 0.5),
		Vector2(-ww, waist), Vector2(-sw * 0.94, top + 0.150 * h),
		Vector2(-sw, top + 0.040 * h), Vector2(-sw * 0.82, top + 0.010 * h)])
	_poly(body, c)
	# the front edge of the coat and a fold, a shade darker; a belt on a long coat
	var fx: float = d * 0.042 * h * bw
	draw_line(Vector2(fx, top + 0.03 * h), Vector2(fx * 1.25, hem), Color(0, 0, 0, 0.24), maxf(1.0, 0.008 * h))
	draw_line(Vector2(-d * 0.03 * h, waist + 0.02 * h), Vector2(-d * 0.05 * h, hem), Color(0, 0, 0, 0.14), maxf(1.0, 0.006 * h))
	if long_coat:
		draw_line(Vector2(-ww, waist + 0.01 * h), Vector2(ww, waist + 0.01 * h), Color(0, 0, 0, 0.30), maxf(1.5, 0.014 * h))
	var lit_side: float = 1.0 if light_dir >= 0.0 else -1.0
	# How ONE-SIDED the light is: 1 from the side, 0 from straight above (under a lamp, or evenly
	# between two). Every effect that belongs to a side -- the form shadow, the rim, the sleeve's
	# highlight -- is scaled by it, so the side changes by fading out and in, never by a flip.
	var sided: float = clampf(absf(light_dir), 0.0, 1.0)
	# the body is ROUND: its far side turns away from the lamp into shadow, across a soft edge
	draw_polygon(PackedVector2Array([Vector2(-sw * lit_side, top + 0.04 * h), Vector2(-sw * 0.25 * lit_side, top + 0.04 * h),
		Vector2(-hw * 0.25 * lit_side, hem), Vector2(-hw * lit_side, hem)]),
		PackedColorArray([Color(0.02, 0.03, 0.10, 0.30 * sided), Color(0.02, 0.03, 0.10, 0.0), Color(0.02, 0.03, 0.10, 0.0), Color(0.02, 0.03, 0.10, 0.34 * sided)]))
	# the collar and lapels: a V at the neck, the near lapel catching the light
	var lap_c: Color = _lit(c.lightened(0.10), Vector2(fx, top))
	draw_colored_polygon(PackedVector2Array([Vector2(d * 0.004 * h, top - 0.008 * h), Vector2(d * 0.060 * h * bw, top + 0.022 * h),
		Vector2(d * 0.034 * h * bw, top + 0.105 * h)]), lap_c)
	draw_colored_polygon(PackedVector2Array([Vector2(-d * 0.004 * h, top - 0.008 * h), Vector2(-d * 0.050 * h * bw, top + 0.020 * h),
		Vector2(d * 0.020 * h * bw, top + 0.100 * h)]), _lit(c.darkened(0.16), Vector2(-fx, top)))
	draw_line(Vector2(d * 0.060 * h * bw, top + 0.022 * h), Vector2(d * 0.034 * h * bw, top + 0.105 * h), Color(0, 0, 0, 0.22), maxf(1.0, 0.005 * h))
	# buttons down the front, a pocket flap at the near hip, a shadow under the hem
	for bk in (4 if long_coat else 3):
		var by: float = lerpf(top + 0.14 * h, hem - 0.07 * h, float(bk) / (3.0 if long_coat else 2.0))
		draw_circle(Vector2(fx * (1.0 + 0.12 * float(bk)), by), maxf(1.0, 0.0075 * h), Color(0.08, 0.06, 0.05, 0.55))
		draw_circle(Vector2(fx * (1.0 + 0.12 * float(bk)) - 0.002 * h, by - 0.002 * h), maxf(0.6, 0.003 * h), Color(1, 1, 1, 0.22))
	draw_line(Vector2(d * 0.060 * h * bw, waist + 0.055 * h), Vector2(d * 0.100 * h * bw, waist + 0.062 * h), Color(0, 0, 0, 0.26), maxf(1.0, 0.008 * h))
	draw_line(Vector2(-hw * 0.96, hem - 0.004 * h), Vector2(hw * 0.96, hem - 0.004 * h), Color(0, 0, 0, 0.22), maxf(1.0, 0.010 * h))
	# the lamp's warm RIM along the lit edge: shoulder, side and hem
	var rim_a: float = 0.50 * light_amt * sided
	draw_polyline(PackedVector2Array([Vector2(sw * 0.80 * lit_side, top + 0.012 * h), Vector2(sw * 0.99 * lit_side, top + 0.042 * h),
		Vector2(sw * 0.93 * lit_side, top + 0.150 * h), Vector2(ww * 1.0 * lit_side, waist),
		Vector2(hw * 0.95 * lit_side, (hem + waist) * 0.5), Vector2(hw * 0.99 * lit_side, hem)]), Color(WARM, rim_a), maxf(1.2, 0.012 * h), true)
	# and light from above lying along both shoulders
	draw_line(Vector2(-sw * 0.78, top + 0.012 * h), Vector2(sw * 0.78, top + 0.012 * h), Color(WARM, 0.16 + 0.20 * light_amt), maxf(1.0, 0.009 * h))
	if scarf:
		_poly(PackedVector2Array([Vector2(-0.048 * h, top - 0.022 * h), Vector2(0.048 * h, top - 0.022 * h),
			Vector2(0.054 * h, top + 0.028 * h), Vector2(-0.054 * h, top + 0.028 * h)]), scarf_col)
		_poly(PackedVector2Array([Vector2(d * 0.018 * h, top + 0.02 * h), Vector2(d * 0.052 * h, top + 0.02 * h),
			Vector2(d * 0.060 * h, top + 0.17 * h), Vector2(d * 0.028 * h, top + 0.17 * h)]), scarf_col.darkened(0.12))

	if bag == Bag.SHOULDER:
		# (at the narrower, side-on body: the bag hangs at the hip, half over the coat)
		draw_line(Vector2(-d * 0.05 * h, top + 0.01 * h), Vector2(d * 0.05 * h, -0.52 * h + y0),
			_lit(bag_col.darkened(0.35), Vector2(0, -0.7 * h)), maxf(1.5, 0.013 * h))
		_poly(_round_box(Vector2(d * 0.06 * h, -0.49 * h + y0), Vector2(0.062 * h, 0.048 * h), 0.014 * h), bag_col)
		draw_line(Vector2(d * 0.002 * h, -0.512 * h + y0), Vector2(d * 0.118 * h, -0.512 * h + y0), Color(0, 0, 0, 0.25), maxf(1.0, 0.006 * h))

	# the near arm, then the head
	_draw_arm(_arm_points(true), c.lightened(0.10), true)
	# the head, narrowed about its center while it turns (a glance back): toward a front view, then out
	# the other way
	var ht: Vector2 = _head_turn()
	var hd: float = d * ht.x
	var hc: Vector2 = Vector2(0.010 * h * hd, -0.925 * h + y0)
	if ht.y < 0.999:
		var body_t: Transform2D = Transform2D(_hit_rot, Vector2(_hit_sx, 1.0), 0.0, Vector2.ZERO)
		var squash: Transform2D = Transform2D(0.0, Vector2(ht.y, 1.0), 0.0, Vector2(hc.x * (1.0 - ht.y), 0.0))
		draw_set_transform_matrix(body_t * squash)
	_draw_head(hc, hd, top)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_ground_marks() -> void:
	match mark:
		Mark.HOVER:
			_ring(Color(1, 1, 1, 0.55))
		Mark.VICTIM, Mark.PICKED_RIGHT:
			_ring(Color(0.40, 0.95, 0.50, 0.9))
		Mark.THIEF:
			_ring(Color(1.0, 0.75, 0.25, 0.9))
		Mark.PICKED_WRONG:
			_ring(Color(1.0, 0.35, 0.30, 0.9))
	# a soft contact shadow
	if _shadow_tex == null:
		_shadow_tex = GradientTexture2D.new()
		_shadow_tex.fill = GradientTexture2D.FILL_RADIAL
		_shadow_tex.fill_from = Vector2(0.5, 0.5)
		_shadow_tex.fill_to = Vector2(1.0, 0.5)
		var g: Gradient = Gradient.new()
		g.set_color(0, Color(0, 0, 0, 0.60))
		g.set_color(1, Color(0, 0, 0, 0.0))
		_shadow_tex.gradient = g
		_shadow_tex.width = 64
		_shadow_tex.height = 64
	draw_texture_rect(_shadow_tex, Rect2(-0.24 * h, -0.05 * h, 0.48 * h, 0.10 * h), false)
	# and the long shadow the nearest lamp throws, away from it, longer the more it lights them
	var reach: float = 0.55 * h * clampf(light_amt, 0.0, 1.0) * absf(light_dir)
	if reach > 0.02 * h:
		var x0: float = -0.20 * h - (reach if light_dir > 0.0 else 0.0)
		var x1: float = 0.20 * h + (reach if light_dir < 0.0 else 0.0)
		draw_texture_rect(_shadow_tex, Rect2(x0, -0.04 * h, x1 - x0, 0.08 * h), false, Color(1, 1, 1, 0.55))

func _ring(col: Color) -> void:
	var pts: PackedVector2Array = _ellipse_pts(Vector2(0, -0.005 * h), 0.27 * h, 0.065 * h, 28)
	draw_colored_polygon(pts, Color(col, 0.18))
	pts.append(pts[0])
	draw_polyline(pts, col, maxf(2.5, 0.022 * h), true)

func _draw_leg(p: Array, col: Color) -> void:
	var hip: Vector2 = p[0]
	var knee: Vector2 = p[1]
	var ankle: Vector2 = p[2]
	_limb(hip, knee, 0.048 * h * build, 0.035 * h, col)
	_limb(knee, ankle, 0.035 * h, 0.025 * h, col)
	# the shoe: a low wedge, toe forward, a sheen on top
	var d: float = float(dir)
	var shoe: PackedVector2Array = PackedVector2Array([
		ankle + Vector2(-d * 0.030 * h, -0.012 * h), ankle + Vector2(d * 0.030 * h, -0.010 * h),
		ankle + Vector2(d * 0.074 * h, 0.012 * h), ankle + Vector2(d * 0.071 * h, 0.026 * h),
		ankle + Vector2(-d * 0.034 * h, 0.026 * h)])
	_poly(shoe, Color(0.10, 0.08, 0.07))
	# the trouser's crease catching light, a cuff over the shoe, and the sole
	draw_line(hip.lerp(knee, 0.15) + Vector2(d * 0.012 * h, 0.0), ankle + Vector2(d * 0.010 * h, -0.02 * h), Color(1, 1, 1, 0.07), maxf(1.0, 0.006 * h))
	draw_line(ankle + Vector2(-d * 0.028 * h, -0.016 * h), ankle + Vector2(d * 0.030 * h, -0.014 * h), Color(0, 0, 0, 0.30), maxf(1.0, 0.008 * h))
	draw_line(ankle + Vector2(-d * 0.034 * h, 0.026 * h), ankle + Vector2(d * 0.071 * h, 0.026 * h), Color(0.30, 0.24, 0.20, 0.9), maxf(1.0, 0.007 * h))
	draw_line(ankle + Vector2(-d * 0.01 * h, -0.004 * h), ankle + Vector2(d * 0.05 * h, 0.010 * h), Color(1, 0.9, 0.75, 0.20), maxf(1.0, 0.006 * h))

func _draw_arm(p: Array, col: Color, front: bool) -> void:
	var sh: Vector2 = p[0]
	var el: Vector2 = p[1]
	var hd: Vector2 = p[2]
	var wr: Vector2 = hd + (el - hd).normalized() * 0.02 * h
	var hcol: Color = skin if front else skin.darkened(0.22)
	var hdir: Vector2 = (hd - el).normalized()
	# THE NEAR ARM HAS AN EDGE (2026-11-12): the sleeve was the coat's own color lying on the coat, so
	# an arm in front of the body vanished into it and a hand going for a pocket was never seen to
	# move. A dark contour round the sleeve and the hand (drawn first, under them) and a sleeve a
	# shade LIGHTER than the coat (see _draw) set it apart. The far arm is behind the body and needs none.
	var hk: float = 1.25          # the hands, a quarter larger than they were: a 2% of h palm was a dot
	if front:
		var pad: float = maxf(1.0, 0.007 * h)
		var edge: Color = Color(0.03, 0.03, 0.06, 0.75)
		_limb_edge(sh, el, 0.035 * h * build, 0.028 * h, pad, edge)
		_limb_edge(el, wr, 0.028 * h, 0.023 * h, pad, edge)
		_limb_edge(hd - hdir * 0.010 * h, hd + hdir * 0.046 * hk * h, 0.021 * hk * h, 0.012 * hk * h, pad, edge)
	_limb(sh, el, 0.035 * h * build, 0.028 * h, col)
	_limb(el, wr, 0.028 * h, 0.023 * h, col)
	# A HAND, not a blob (2026-11-10): a palm running on from the forearm, the fingers together as one
	# tapering shape, and a thumb on its forward side.
	_limb(hd - hdir * 0.010 * h, hd + hdir * 0.018 * hk * h, 0.019 * hk * h, 0.021 * hk * h, hcol)
	_limb(hd + hdir * 0.018 * hk * h, hd + hdir * 0.046 * hk * h, 0.019 * hk * h, 0.011 * hk * h, hcol.darkened(0.05))
	var fwd: Vector2 = Vector2(float(dir), 0.0) - hdir * hdir.dot(Vector2(float(dir), 0.0))
	if fwd.length() > 0.05:
		fwd = fwd.normalized()
		_limb(hd + fwd * 0.012 * hk * h, hd + (fwd * 0.026 + hdir * 0.020) * hk * h, 0.0085 * hk * h, 0.0065 * hk * h, hcol.darkened(0.08))
	# the cuff: a darker band where the sleeve ends
	var wrist: Vector2 = hd + (el - hd).normalized() * 0.026 * h
	var across: Vector2 = (el - hd).normalized().orthogonal() * 0.024 * h
	draw_line(wrist - across, wrist + across, Color(0, 0, 0, 0.30), maxf(1.0, 0.010 * h))
	if front:
		# a soft highlight down the sleeve's lit side
		var ls: float = 1.0 if light_dir >= 0.0 else -1.0
		draw_line(sh + Vector2(ls * 0.026 * h, 0.01 * h), el + Vector2(ls * 0.022 * h, 0.0), Color(WARM, 0.22 * light_amt * clampf(absf(light_dir), 0.0, 1.0)), maxf(1.0, 0.008 * h))

func _draw_head(hc: Vector2, d: float, neck_y: float) -> void:
	_limb(Vector2(0.004 * h * d, neck_y + 0.01 * h), hc + Vector2(-0.004 * h * d, 0.04 * h), 0.023 * h, 0.021 * h, skin.darkened(0.14))
	_hair_back(hc, d)
	# a skull a little longer than wide, the jaw coming forward and down
	var head: PackedVector2Array = PackedVector2Array()
	for k in 20:
		var a: float = TAU * float(k) / 20.0
		var p: Vector2 = Vector2(cos(a) * 0.055 * h, sin(a) * 0.065 * h)
		if sin(a) > 0.0:
			p.x += d * 0.011 * h * sin(a)
		head.append(hc + p)
	_poly(head, skin)
	# nose, eye, brow and ear: small, the way a face reads from across a street
	_poly(PackedVector2Array([hc + Vector2(d * 0.050 * h, -0.010 * h), hc + Vector2(d * 0.071 * h, 0.012 * h),
		hc + Vector2(d * 0.052 * h, 0.016 * h)]), skin.darkened(0.06))
	# A FACE, not a dot and a dash (2026-11-10): the head is round -- its back falls into shadow, its
	# cheek catches the lamp -- with an eye that has a white and a lid, a brow in the hair's color, a
	# nostril, lips, an ear with its fold, and the jaw's shadow on the neck. Every size is a share of
	# h, so the far lane's faces stay a few clean pixels and the onlookers' read as people.
	var lit_s: float = 1.0 if light_dir >= 0.0 else -1.0
	draw_polygon(PackedVector2Array([hc + Vector2(-d * 0.056 * h, -0.045 * h), hc + Vector2(-d * 0.012 * h, -0.060 * h),
		hc + Vector2(-d * 0.012 * h, 0.060 * h), hc + Vector2(-d * 0.050 * h, 0.045 * h)]),
		PackedColorArray([Color(0.05, 0.04, 0.10, 0.26), Color(0.05, 0.04, 0.10, 0.0), Color(0.05, 0.04, 0.10, 0.0), Color(0.05, 0.04, 0.10, 0.26)]))
	draw_colored_polygon(_ellipse_pts(hc + Vector2(d * 0.022 * h, 0.018 * h), 0.017 * h, 0.012 * h, 10), Color(0.95, 0.45, 0.35, 0.10 + 0.08 * light_amt))
	# the eye
	var eye: Vector2 = hc + Vector2(d * 0.033 * h, -0.006 * h)
	draw_colored_polygon(_ellipse_pts(eye, maxf(1.2, 0.0105 * h), maxf(0.9, 0.0066 * h), 10), Color(0.96, 0.94, 0.90, 0.92))
	draw_circle(eye + Vector2(d * 0.0030 * h, 0.0), maxf(0.8, 0.0054 * h), Color(0.12, 0.08, 0.06))
	draw_circle(eye + Vector2(d * 0.0045 * h, -0.0016 * h), maxf(0.3, 0.0016 * h), Color(1, 1, 1, 0.8))
	draw_line(eye + Vector2(-d * 0.011 * h, -0.006 * h), eye + Vector2(d * 0.011 * h, -0.0065 * h), Color(0.10, 0.07, 0.06, 0.75), maxf(1.0, 0.0045 * h))
	draw_line(hc + Vector2(d * 0.018 * h, -0.023 * h), hc + Vector2(d * 0.048 * h, -0.021 * h), Color(hair_col.darkened(0.25), 0.85), maxf(1.0, 0.0075 * h))
	# a nostril, and lips a shade redder than the skin
	draw_circle(hc + Vector2(d * 0.058 * h, 0.0125 * h), maxf(0.5, 0.0028 * h), Color(0, 0, 0, 0.35))
	draw_line(hc + Vector2(d * 0.030 * h, 0.0315 * h), hc + Vector2(d * 0.054 * h, 0.029 * h),
		Color(skin.r * 0.70, skin.g * 0.42, skin.b * 0.40, 0.85), maxf(1.0, 0.0065 * h))
	draw_line(hc + Vector2(d * 0.034 * h, 0.038 * h), hc + Vector2(d * 0.050 * h, 0.036 * h), Color(0, 0, 0, 0.12), maxf(1.0, 0.004 * h))
	# the ear, with the fold inside it
	_poly(_ellipse_pts(hc + Vector2(-d * 0.008 * h, 0.002 * h), 0.011 * h, 0.017 * h, 8), skin.darkened(0.14))
	draw_arc(hc + Vector2(-d * 0.008 * h, 0.002 * h), 0.006 * h, 0.0, TAU * 0.7, 8, Color(0, 0, 0, 0.22), maxf(1.0, 0.003 * h))
	# the jaw's shadow on the neck
	draw_line(hc + Vector2(-d * 0.03 * h, 0.058 * h), hc + Vector2(d * 0.04 * h, 0.056 * h), Color(0, 0, 0, 0.22), maxf(1.0, 0.014 * h))
	# the lamp's rim on the lit side of the head
	draw_arc(hc, 0.058 * h, (-PI * 0.42 if lit_s > 0.0 else PI * 0.58), (PI * 0.42 if lit_s > 0.0 else PI * 1.42), 12,
		Color(WARM, 0.42 * light_amt * clampf(absf(light_dir), 0.0, 1.0)), maxf(1.0, 0.010 * h))
	_hair_front(hc, d)
	if hat == Hat.NONE and hair != Hair.BALD:
		# a sheen across the top of the hair
		draw_arc(hc + Vector2(-d * 0.006 * h, 0.004 * h), 0.060 * h, -PI * 0.80, -PI * 0.42, 8, Color(1, 1, 1, 0.14 + 0.10 * light_amt), maxf(1.0, 0.010 * h))
	_hat(hc, d)

func _hair_back(hc: Vector2, d: float) -> void:
	if hat != Hat.NONE and hair != Hair.LONG:
		return
	match hair:
		Hair.LONG:
			_poly(PackedVector2Array([
				hc + Vector2(-d * 0.058 * h, -0.030 * h), hc + Vector2(d * 0.020 * h, -0.050 * h),
				hc + Vector2(-d * 0.010 * h, 0.060 * h), hc + Vector2(-d * 0.028 * h, 0.150 * h),
				hc + Vector2(-d * 0.082 * h, 0.140 * h), hc + Vector2(-d * 0.072 * h, 0.030 * h)]), hair_col)
		Hair.BUN:
			_poly(_ellipse_pts(hc + Vector2(-d * 0.058 * h, -0.045 * h), 0.025 * h, 0.023 * h, 12), hair_col)

func _hair_front(hc: Vector2, d: float) -> void:
	if hat != Hat.NONE:
		return
	match hair:
		Hair.SHORT, Hair.LONG, Hair.BUN:
			_poly(PackedVector2Array([
				hc + Vector2(d * 0.045 * h, -0.032 * h), hc + Vector2(d * 0.040 * h, -0.057 * h),
				hc + Vector2(0.0, -0.073 * h), hc + Vector2(-d * 0.044 * h, -0.061 * h),
				hc + Vector2(-d * 0.061 * h, -0.020 * h), hc + Vector2(-d * 0.057 * h, 0.022 * h),
				hc + Vector2(-d * 0.030 * h, 0.010 * h), hc + Vector2(-d * 0.010 * h, -0.030 * h)]), hair_col)
		Hair.CURLY:
			for k in 7:
				var a: float = PI * 0.95 + PI * 1.05 * float(k) / 6.0
				var pc: Vector2 = hc + Vector2(-cos(a) * 0.054 * h * d, sin(a) * 0.061 * h)
				_poly(_ellipse_pts(pc + Vector2(-d * 0.010 * h, 0.0), 0.021 * h, 0.020 * h, 10), hair_col)
		Hair.BALD:
			# a thin fringe round the back of the head, above the ear
			var fringe: PackedVector2Array = PackedVector2Array()
			for k in 9:
				var ang: float = PI * (0.80 + 0.45 * float(k) / 8.0)
				fringe.append(hc + Vector2(cos(ang) * 0.054 * h * d, sin(ang) * -0.040 * h + 0.012 * h))
			draw_polyline(fringe, _lit(hair_col, Vector2(0, -0.9 * h)), maxf(1.5, 0.011 * h), true)

func _hat(hc: Vector2, d: float) -> void:
	match hat:
		Hat.CAP:
			_poly(PackedVector2Array([hc + Vector2(-d * 0.060 * h, -0.020 * h), hc + Vector2(-d * 0.050 * h, -0.060 * h),
				hc + Vector2(0.0, -0.078 * h), hc + Vector2(d * 0.050 * h, -0.060 * h), hc + Vector2(d * 0.058 * h, -0.028 * h)]), hat_col)
			_poly(PackedVector2Array([hc + Vector2(d * 0.040 * h, -0.032 * h), hc + Vector2(d * 0.104 * h, -0.024 * h),
				hc + Vector2(d * 0.100 * h, -0.016 * h), hc + Vector2(d * 0.040 * h, -0.020 * h)]), hat_col.darkened(0.3))
		Hat.BEANIE:
			_poly(PackedVector2Array([hc + Vector2(-d * 0.061 * h, -0.010 * h), hc + Vector2(-d * 0.055 * h, -0.065 * h),
				hc + Vector2(-d * 0.010 * h, -0.090 * h), hc + Vector2(d * 0.040 * h, -0.075 * h), hc + Vector2(d * 0.057 * h, -0.020 * h)]), hat_col)
			draw_line(hc + Vector2(-d * 0.061 * h, -0.016 * h), hc + Vector2(d * 0.057 * h, -0.024 * h), _lit(hat_col.darkened(0.3), Vector2(0, -0.9 * h)), maxf(1.5, 0.018 * h))
		Hat.FEDORA:
			_poly(PackedVector2Array([hc + Vector2(-0.102 * h, -0.040 * h), hc + Vector2(0.102 * h, -0.040 * h),
				hc + Vector2(0.088 * h, -0.030 * h), hc + Vector2(-0.088 * h, -0.030 * h)]), hat_col.darkened(0.15))
			_poly(PackedVector2Array([hc + Vector2(-0.057 * h, -0.040 * h), hc + Vector2(-0.051 * h, -0.097 * h),
				hc + Vector2(0.0, -0.089 * h), hc + Vector2(0.051 * h, -0.099 * h), hc + Vector2(0.057 * h, -0.040 * h)]), hat_col)
			draw_line(hc + Vector2(-0.056 * h, -0.050 * h), hc + Vector2(0.056 * h, -0.050 * h), Color(0.08, 0.06, 0.05, 0.8), maxf(1.5, 0.012 * h))
		Hat.BOWLER:
			_poly(PackedVector2Array([hc + Vector2(-0.084 * h, -0.036 * h), hc + Vector2(0.084 * h, -0.036 * h),
				hc + Vector2(0.069 * h, -0.028 * h), hc + Vector2(-0.069 * h, -0.028 * h)]), hat_col.darkened(0.15))
			var dome: PackedVector2Array = PackedVector2Array()
			for k in 13:
				var a: float = PI + PI * float(k) / 12.0
				dome.append(hc + Vector2(cos(a) * 0.057 * h, -0.036 * h + sin(a) * 0.059 * h))
			_poly(dome, hat_col)

func _round_box(c: Vector2, half: Vector2, r: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var corners: Array = [Vector2(half.x - r, -half.y + r), Vector2(half.x - r, half.y - r),
		Vector2(-half.x + r, half.y - r), Vector2(-half.x + r, -half.y + r)]
	var starts: Array = [-PI * 0.5, 0.0, PI * 0.5, PI]
	for i in 4:
		for k in 4:
			var a: float = float(starts[i]) + PI * 0.5 * float(k) / 3.0
			pts.append(c + (corners[i] as Vector2) + Vector2(cos(a), sin(a)) * r)
	return pts

# The answer's tag ("Robbed", "Pickpocket", "Your pick") is drawn by the LEVEL on a layer above
# everything (draw_tag_to), never in the person's own layer: there an onlooker or the hustler could
# cover the person and leave the tag pointing at no one. The pill is kept on screen; its pointer
# still ends on the person's head.
# Where this person's tag box is drawn (screen coordinates), for keeping tags apart.
func tag_box(screen_w: float) -> Rect2:
	var font: Font = MainGlobals.get_text_font()
	var fs: int = int(clampf(0.16 * h, 16.0, float(MainGlobals.ui_font_size(20))))
	var tw: float = font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pad: float = fs * 0.45
	var box_bottom: float = head_top().y - maxf(10.0, 0.10 * h) - tag_raise * fs * 1.5
	var y: float = box_bottom - fs * 1.2
	var bw: float = tw + pad * 2.0
	var bx: float = clampf(position.x - bw * 0.5, 6.0, screen_w - bw - 6.0)
	return Rect2(Vector2(bx, y - fs * 0.15), Vector2(bw, fs * 1.35))

func draw_tag_to(ci: CanvasItem, screen_w: float) -> void:
	if tag == "":
		return
	var font: Font = MainGlobals.get_text_font()
	var fs: int = int(clampf(0.16 * h, 16.0, float(MainGlobals.ui_font_size(20))))
	var tw: float = font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pad: float = fs * 0.45
	var head: Vector2 = head_top()
	# the box sits a short pointer's length above the crown
	var box_bottom: float = head.y - maxf(10.0, 0.10 * h) - tag_raise * fs * 1.5
	var y: float = box_bottom - fs * 1.2
	var col: Color = Color(0.40, 0.95, 0.50)
	match mark:
		Mark.THIEF:
			col = Color(1.0, 0.75, 0.25)
		Mark.PICKED_WRONG:
			col = Color(1.0, 0.40, 0.35)
	var bw: float = tw + pad * 2.0
	var bx: float = clampf(position.x - bw * 0.5, 6.0, screen_w - bw - 6.0)
	var box: Rect2 = Rect2(Vector2(bx, y - fs * 0.15), Vector2(bw, fs * 1.35))
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.10, 0.90)
	sb.set_corner_radius_all(int(fs * 0.45))
	sb.border_color = Color(col, 0.7)
	sb.set_border_width_all(2)
	ci.draw_line(Vector2(clampf(head.x, box.position.x + 8.0, box.end.x - 8.0), box.end.y), head, Color(col, 0.85), 2.0)
	ci.draw_style_box(sb, box)
	ci.draw_string(font, Vector2(bx + pad, y + fs * 0.92), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
