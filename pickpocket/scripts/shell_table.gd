extends Node2D

# THE HUSTLER'S TABLE: a folding table with a baize top and a cloth, a hurricane lantern on it, the
# hustler behind it, his copper cups, the ball and his hands. All drawn in code, animated from the
# game clock the level passes to update().
#
# Cups stand in SLOTS (evenly spaced x positions). `cup_slot[c]` is where cup c stands; the ball is
# under cup `ball_cup`. A swap moves two cups between their slots along opposite arcs, one passing
# in front of the other (lower on screen) so the two never merge; a FEINT starts the same move,
# meets in the middle and goes back.
#
# THE HANDS ARE NEVER TELEPORTED. Every move has a LEAD: the hands travel to the cups they are
# about to move (easing, `HAND_RATE`) while the cups stay put, and only then do the cups move, with
# the hands riding on them. Between moves the hands drift toward the next cups (`set_next`) or back
# to rest. The first version snapped each hand to its next cup in one frame.
#
# THE BODY FOLLOWS THE HANDS: the arms are two-bone limbs from the shoulders, and the shoulders
# shift, rise and drop toward where the hands are (a long reach pulls that shoulder in and turns
# the torso), the head follows the torso, and a slow breath runs under it all. A body that stood
# still while the arms flew around read as a puppet.
#
# The cups are identical on purpose. Anything that told one from another (a dent, a color) would
# let a player find the ball afterwards without having followed it.

const COPPER: Color = Color(0.78, 0.45, 0.24)
const BALL_COLOR: Color = Color(0.82, 0.12, 0.12)
const BAIZE: Color = Color(0.10, 0.30, 0.20)
const CLOTH: Color = Color(0.40, 0.08, 0.11)
const FRINGE: Color = Color(0.86, 0.68, 0.30)
const SKIN: Color = Color(0.95, 0.78, 0.65)
const SHIRT: Color = Color(0.86, 0.83, 0.76)
const VEST: Color = Color(0.20, 0.13, 0.16)       # a deep plum-brown wool (it was near-black, a flat hole)
const CAP: Color = Color(0.36, 0.31, 0.26)
const KERCHIEF: Color = Color(0.72, 0.13, 0.14)   # the red neckerchief: the one loud thing he wears
const BRASS: Color = Color(0.92, 0.74, 0.34)
const WOOD: Color = Color(0.36, 0.21, 0.11)
const COOL: Color = Color(0.03, 0.04, 0.12)       # the evening's shadow, laid over a far side
const LAMP: Color = Color(1.0, 0.78, 0.45)

const HAND_RATE: float = 26.0      # 1/s: how fast a hand closes on where it is going
const LEAD_MS: float = 170.0       # the hands reach a cup this long before it moves
const LIFT: float = 0.62           # how high a cup is lifted, in cup heights: enough to show the ball

var n_cups: int = 3
var slot_x: Array = []        # x of each slot
var cup_slot: Array = []      # slot of each cup
var ball_cup: int = 0
var base_y: float = 400.0     # where a cup's rim rests on the table
var cup_h: float = 70.0
var cup_w: float = 64.0
var table_rect: Rect2 = Rect2()   # the table top, back edge to front edge
var skirt_h: float = 90.0
var hustler_top: float = 300.0
var lead_ms: float = LEAD_MS
var hs: float = 60.0          # the hustler's own unit of size (his body is drawn in it, not in cups)

var _anim: Dictionary = {}
var _lifted: Dictionary = {}  # cup -> lift height in px, for cups held up (revealed)
var _now: float = 0.0
var _last: float = -1.0
var _hand: Array = []         # current hand positions [left, right]
var _next: Array = []         # slots the hands should drift to before the next swap

# The level may hold the row of cups within `max_row_half` of the center (to the outer cup's outer
# edge), and scale the cups by `cup_k` for it -- the hustler keeps his size (see level.gd _layout).
var max_row_half: float = INF

func layout(w: float, table_top_y: float, cup_height: float, skirt: float, slots: int, cup_k: float = 1.0) -> void:
	# the hustler is drawn in his own unit (hs); the table is sized for him as much as for the cups
	hs = cup_height * 1.25
	cup_h = cup_height * cup_k
	cup_w = cup_h * 0.92
	base_y = table_top_y + cup_height * 0.30
	var tw: float = minf(w * 0.88, maxf(cup_w * 1.95 * float(slots) + cup_w * 2.6, hs * 5.2))
	table_rect = Rect2(w * 0.5 - tw * 0.5, table_top_y - cup_height * 0.30, tw, cup_height * 0.95)
	skirt_h = skirt
	# a man of ordinary build standing at a waist-high table, no wider than the middle of it
	# he STANDS at a waist-high table: his shoulders well above the cups, so his arms reach DOWN to
	# them (lower, the arms had to stick out level with the cups like a coat hanger)
	hustler_top = table_rect.position.y - hs * 3.0
	set_cups(slots)
	_hand = [_rest(0), _rest(1)]

func set_cups(n: int) -> void:
	n_cups = n
	slot_x.clear()
	cup_slot.clear()
	var cx: float = table_rect.get_center().x
	var pitch: float = minf(cup_w * 1.85, (table_rect.size.x - cup_w * 2.4) / float(maxi(1, n - 1)))
	if max_row_half < INF and n > 1:
		pitch = minf(pitch, (max_row_half - cup_w * 0.5) / (float(n - 1) * 0.5))
	for i in n:
		slot_x.append(cx + (float(i) - float(n - 1) * 0.5) * pitch)
		cup_slot.append(i)
	ball_cup = 0
	_anim = {}
	_lifted = {}
	_next = []
	if _hand.size() != 2:
		_hand = [_rest(0), _rest(1)]
	queue_redraw()

func is_lifted(c: int) -> bool:
	return _lifted.has(c)

func busy() -> bool:
	return not _anim.is_empty()

func cup_in_slot(s: int) -> int:
	for c in n_cups:
		if int(cup_slot[c]) == s:
			return c
	return -1

# --- moves -------------------------------------------------------------------
# Every move's t0 is when the CUPS start moving; the hands spend lead_ms before it getting there.

func start_peek(cup: int, now: float, up_ms: float, hold_ms: float) -> void:
	_anim = {"type": "peek", "cup": cup, "t0": now + lead_ms, "up": up_ms, "hold": hold_ms}

func start_reveal(cup: int, now: float, up_ms: float) -> void:
	_anim = {"type": "reveal", "cup": cup, "t0": now + lead_ms, "up": up_ms}

func start_swap(slot_a: int, slot_b: int, now: float, dur_ms: float, feint: bool) -> void:
	_next = []
	_anim = {"type": "swap", "a": cup_in_slot(slot_a), "b": cup_in_slot(slot_b),
		"sa": slot_a, "sb": slot_b, "t0": now + lead_ms, "dur": dur_ms, "feint": feint}

# The hands start toward these two slots as soon as the current move ends.
func set_next(slot_a: int, slot_b: int) -> void:
	_next = [slot_a, slot_b]

func lower_all() -> void:
	_lifted = {}
	_anim = {}
	_next = []
	queue_redraw()

func update(now: float) -> void:
	_now = now
	var dt: float = 0.0 if _last < 0.0 else clampf(now - _last, 0.0, 100.0) / 1000.0
	_last = now
	if not _anim.is_empty():
		var t: String = _anim["type"]
		var el: float = now - float(_anim["t0"])
		if t == "swap" and el >= float(_anim["dur"]):
			if not bool(_anim["feint"]):
				cup_slot[int(_anim["a"])] = int(_anim["sb"])
				cup_slot[int(_anim["b"])] = int(_anim["sa"])
			_anim = {}
		elif t == "peek" and el >= float(_anim["up"]) * 2.0 + float(_anim["hold"]):
			_anim = {}
		elif t == "reveal" and el >= float(_anim["up"]):
			_lifted[int(_anim["cup"])] = cup_h * LIFT
			_anim = {}
	_move_hands(dt)
	_ease_lean(dt)
	queue_redraw()

# --- the hands ---------------------------------------------------------------

# At rest his hands lie on two of the cups, one each side of him, as a hustler's do between moves.
# (Resting them on the table beyond the outer cups laid both arms across the whole row.)
func _rest(side: int) -> Vector2:
	if slot_x.is_empty():
		return Vector2(table_rect.get_center().x, base_y)
	var n: int = slot_x.size()
	var s_l: int = 0 if n <= 3 else 1
	var s_r: int = n - 1 - s_l
	var sl: int = s_l if side == 0 else s_r
	return Vector2(float(slot_x[sl]), base_y - cup_h * 0.97)

# Where each hand is headed, and whether it is riding a cup (then it is placed exactly).
func _hand_targets() -> Array:
	var cx: float = table_rect.get_center().x
	var to_l: Vector2 = _rest(0)
	var to_r: Vector2 = _rest(1)
	var ride: Array = [false, false]
	var on_move: bool = not _anim.is_empty() and _now >= float(_anim["t0"])
	var anim_hand: int = -1
	if not _anim.is_empty():
		match String(_anim["type"]):
			"swap":
				var ta: Vector2 = _grip(int(_anim["a"]))
				var tb: Vector2 = _grip(int(_anim["b"]))
				var a_left: bool = float(slot_x[int(_anim["sa"])]) <= float(slot_x[int(_anim["sb"])])
				to_l = ta if a_left else tb
				to_r = tb if a_left else ta
				ride = [on_move, on_move]
			"peek", "reveal":
				var tp: Vector2 = _grip(int(_anim["cup"]))
				if float(slot_x[int(cup_slot[int(_anim["cup"])])]) < cx:
					to_l = tp
					ride[0] = on_move
					anim_hand = 0
				else:
					to_r = tp
					ride[1] = on_move
					anim_hand = 1
	elif _next.size() == 2:
		var xa: float = float(slot_x[int(_next[0])])
		var xb: float = float(slot_x[int(_next[1])])
		var ga: Vector2 = _grip(cup_in_slot(int(_next[0])))
		var gb: Vector2 = _grip(cup_in_slot(int(_next[1])))
		to_l = ga if xa <= xb else gb
		to_r = gb if xa <= xb else ga
	# cups held up: with two, the left one in the left hand and the right one in the right
	var held: Array = _lifted.keys()
	held.sort_custom(func(p: int, q: int) -> bool: return _grip(p).x < _grip(q).x)
	if held.size() >= 2:
		to_l = _grip(int(held[0]))
		to_r = _grip(int(held[held.size() - 1]))
		ride = [true, true]
	elif held.size() == 1:
		# the hand on its side, unless that hand is busy lifting another cup
		var g: Vector2 = _grip(int(held[0]))
		var hand: int = 0 if g.x < cx else 1
		if hand == anim_hand:
			hand = 1 - hand
		if hand == 0:
			to_l = g
		else:
			to_r = g
		ride[hand] = true
	return [to_l, to_r, ride]

func _move_hands(dt: float) -> void:
	var t: Array = _hand_targets()
	var ride: Array = t[2]
	var k: float = 1.0 - exp(-HAND_RATE * dt)
	for i in 2:
		var target: Vector2 = t[i]
		var cur: Vector2 = _hand[i]
		if bool(ride[i]) and cur.distance_to(target) < cup_w * 0.6:
			_hand[i] = target
		else:
			# glide there, low over the table, easing in
			_hand[i] = cur.lerp(target, k)

# The point a hand holds a cup by: its top.
func _grip(c: int) -> Vector2:
	if c < 0:
		return _rest(0)
	var pose: Vector3 = _cup_pose(c)
	return Vector2(pose.x, pose.y - pose.z - cup_h * 0.97)

# --- cup geometry ------------------------------------------------------------

func _cup_pose(c: int) -> Vector3:
	var x: float = float(slot_x[int(cup_slot[c])])
	var y: float = base_y
	var lift: float = float(_lifted.get(c, 0.0))
	if _anim.is_empty():
		return Vector3(x, y, lift)
	var el: float = maxf(0.0, _now - float(_anim["t0"]))
	match String(_anim["type"]):
		"swap":
			var a: int = int(_anim["a"])
			var b: int = int(_anim["b"])
			if c == a or c == b:
				var u: float = clampf(el / float(_anim["dur"]), 0.0, 1.0)
				var k: float
				var arc: float
				if bool(_anim["feint"]):
					k = 0.42 * sin(u * PI)
					arc = sin(u * PI)
				else:
					k = u * u * (3.0 - 2.0 * u)
					arc = sin(k * PI)
				var xa: float = float(slot_x[int(_anim["sa"])])
				var xb: float = float(slot_x[int(_anim["sb"])])
				var depth: float = arc * cup_h * 0.30
				if c == a:
					return Vector3(lerpf(xa, xb, k), y + depth, lift)
				return Vector3(lerpf(xb, xa, k), y - depth, lift)
		"peek":
			if c == int(_anim["cup"]):
				var up: float = float(_anim["up"])
				var hold: float = float(_anim["hold"])
				var f: float
				if el < up:
					f = el / up
				elif el < up + hold:
					f = 1.0
				else:
					f = 1.0 - (el - up - hold) / up
				f = clampf(f, 0.0, 1.0)
				return Vector3(x, y, lift + cup_h * LIFT * (f * f * (3.0 - 2.0 * f)))
		"reveal":
			if c == int(_anim["cup"]):
				var f2: float = clampf(el / float(_anim["up"]), 0.0, 1.0)
				return Vector3(x, y, cup_h * LIFT * (f2 * f2 * (3.0 - 2.0 * f2)))
	return Vector3(x, y, lift)

# The cup under a point, or -1. Generous, so a finger finds it.
func cup_at(p: Vector2) -> int:
	var best: int = -1
	var best_d: float = 1.0e9
	for c in n_cups:
		var pose: Vector3 = _cup_pose(c)
		var r: Rect2 = Rect2(pose.x - cup_w * 0.65, pose.y - pose.z - cup_h * 1.15, cup_w * 1.3, cup_h * 1.45)
		if r.has_point(p):
			var d: float = absf(p.x - pose.x)
			if d < best_d:
				best_d = d
				best = c
	return best

# --- drawing -----------------------------------------------------------------

func _draw() -> void:
	if _hand.size() != 2:
		return
	var pose: Dictionary = _body_pose()
	_draw_hustler(pose)
	_draw_table()
	var order: Array = []
	for c in n_cups:
		order.append(c)
	order.sort_custom(func(p: int, q: int) -> bool: return _cup_pose(p).y < _cup_pose(q).y)
	for c in order:
		var cp: Vector3 = _cup_pose(c)
		if c == ball_cup and cp.z > 2.0:
			_draw_ball(Vector2(cp.x, cp.y))
		_draw_cup(cp)
	_draw_lantern()
	_draw_arm(pose["sl"], _hand[0], -1.0)
	_draw_arm(pose["sr"], _hand[1], 1.0)

# Where the shoulders and the head are, given the hands: each shoulder moves a share of the way
# its hand has moved from rest (in, and up or down with it), a long reach pulls it further, the
# head follows the torso, and the whole body breathes.
# How far the torso wants to lean for where the hands are: the reaches beyond an arm's length, summed.
func _lean_target() -> float:
	if _hand.size() != 2:
		return 0.0
	var u: float = hs
	var cx: float = table_rect.get_center().x
	var sh_y: float = hustler_top + u * 1.30
	var pull: float = 0.0
	for pair in [[Vector2(cx - u * 0.84, sh_y), _hand[0]], [Vector2(cx + u * 0.84, sh_y), _hand[1]]]:
		var v: Vector2 = (pair[1] as Vector2) - (pair[0] as Vector2)
		var over: float = v.length() - u * 1.80
		if over > 0.0:
			pull += v.x / v.length() * over
	return clampf(pull, -u * 0.80, u * 0.80)

const LEAN_RATE: float = 5.0     # 1/s: a torso is heavier than a hand (HAND_RATE is 26)
var _lean_now: float = 0.0

func _ease_lean(dt: float) -> void:
	_lean_now = lerpf(_lean_now, _lean_target(), 1.0 - exp(-dt * LEAN_RATE))

func _body_pose() -> Dictionary:
	var u: float = hs
	var cx: float = table_rect.get_center().x
	var breath: float = sin(_now * 0.0021) * u * 0.025
	var sh_y: float = hustler_top + u * 1.30 + breath
	# a man's shoulders: about three heads across (0.70 was narrow for arms spread over a table)
	var base_l: Vector2 = Vector2(cx - u * 0.84, sh_y)
	var base_r: Vector2 = Vector2(cx + u * 0.84, sh_y)
	# THE SHOULDERS KEEP THEIR WIDTH; THE TORSO LEANS. Each shoulder used to be dragged toward its own
	# hand, so with a hand across the body (or both to one side) the torso collapsed into a narrow
	# tube and the waistcoat's shapes folded over each other. A person reaching far LEANS: both
	# shoulders move together, by however much the longer reach is short of an arm's length, and the
	# shoulder on the reaching side dips a little.
	# The lean is EASED (update -> _ease_lean): the hands snap back to rest in a few frames, and a lean
	# that followed them exactly threw his whole torso back to the center in a jump.
	var lean: float = _lean_now
	var dip: float = absf(lean) * 0.12
	var sl: Vector2 = base_l + Vector2(lean, dip if lean < 0.0 else -dip * 0.5)
	var sr: Vector2 = base_r + Vector2(lean, dip if lean > 0.0 else -dip * 0.5)
	var mid: Vector2 = (sl + sr) * 0.5
	var tilt: float = clampf((sr.y - sl.y) / u, -0.6, 0.6)
	var head: Vector2 = Vector2(mid.x + (mid.x - cx) * 0.25, hustler_top + u * 0.70 + breath * 1.2 + (mid.y - sh_y) * 0.7)
	return {"sl": sl, "sr": sr, "head": head, "tilt": tilt}

static var _glow: GradientTexture2D = null

# A soft round falloff, white in the middle and clear at the edge, tinted by whoever draws it.
func _glow_tex() -> GradientTexture2D:
	if _glow == null:
		_glow = GradientTexture2D.new()
		_glow.fill = GradientTexture2D.FILL_RADIAL
		_glow.fill_from = Vector2(0.5, 0.5)
		_glow.fill_to = Vector2(1.0, 0.5)
		var gr: Gradient = Gradient.new()
		gr.set_color(0, Color(1, 1, 1, 1))
		gr.add_point(0.35, Color(1, 1, 1, 0.45))
		gr.set_color(gr.get_point_count() - 1, Color(1, 1, 1, 0))
		_glow.gradient = gr
		_glow.width = 128
		_glow.height = 128
	return _glow

# The lantern's flame in the level's coordinates, for its additive glow over the scene.
func lantern_world() -> Vector2:
	return position + _lantern_pos() + Vector2(0, -cup_h * 0.45)

func _lantern_pos() -> Vector2:
	return Vector2(table_rect.position.x + table_rect.size.x * 0.10, table_rect.position.y + cup_h * 0.15)

# A polygon lit by the lantern: brighter and warmer the nearer each corner is to it.
# `fade`: indices of corners drawn fully transparent, so the shape melts into what is under it there.
func _shade_poly(pts: PackedVector2Array, c: Color, light_at: Vector2, reach: float, ambient: float = 0.55, fade: Array = []) -> void:
	var cols: PackedColorArray = PackedColorArray()
	for i in pts.size():
		var p: Vector2 = pts[i]
		var k: float = ambient + (1.0 - ambient) * clampf(1.0 - p.distance_to(light_at) / reach, 0.0, 1.0)
		var cc: Color = Color(c.r * k, c.g * k, c.b * k, c.a)
		cc = cc.lerp(Color(minf(1.0, cc.r * 1.08), cc.g, cc.b * 0.85, c.a), k * 0.5)
		if fade.has(i):
			cc.a = 0.0
		cols.append(cc)
	if Geometry2D.triangulate_polygon(pts).is_empty():
		# a shape folded over itself by an extreme pose: draw its hull rather than nothing
		var hull: PackedVector2Array = Geometry2D.convex_hull(pts)
		if hull.size() >= 4:
			hull.remove_at(hull.size() - 1)
			draw_colored_polygon(hull, cols[0])
		return
	draw_polygon(pts, cols)

func _oval(c: Vector2, rx: float, ry: float, n: int = 14) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for k in n:
		var a: float = TAU * float(k) / float(n)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

func _draw_hustler(pose: Dictionary) -> void:
	var u: float = hs
	var cx: float = table_rect.get_center().x
	var sl: Vector2 = pose["sl"]
	var sr: Vector2 = pose["sr"]
	var light: Vector2 = _lantern_pos() + Vector2(0, -u * 0.6)
	var reach: float = u * 4.2
	var waist_y: float = table_rect.position.y + 6.0
	var neck: Vector2 = (sl + sr) * 0.5 + Vector2(0, -u * 0.10)
	# The shirt: the neck's base, the trapezius SLOPING down to each shoulder, a rounded deltoid cap,
	# then down the side to the waist (behind the table). The shoulders used to be the flat corners
	# of a box, with the arms stuck on as tubes.
	var shirt: PackedVector2Array = PackedVector2Array([
		neck + Vector2(-u * 0.17, -u * 0.06), sl + Vector2(u * 0.10, -u * 0.12), sl + Vector2(-u * 0.04, -u * 0.09),
		sl + Vector2(-u * 0.14, -u * 0.01), sl + Vector2(-u * 0.17, u * 0.12), sl + Vector2(-u * 0.13, u * 0.40),
		Vector2(cx - u * 0.60, waist_y), Vector2(cx + u * 0.60, waist_y),
		sr + Vector2(u * 0.13, u * 0.40), sr + Vector2(u * 0.17, u * 0.12), sr + Vector2(u * 0.14, -u * 0.01),
		sr + Vector2(u * 0.04, -u * 0.09), sr + Vector2(-u * 0.10, -u * 0.12), neck + Vector2(u * 0.17, -u * 0.06)])
	_shade_poly(shirt, SHIRT, light, reach, 0.45)
	# the waistcoat over it, open at the front, its armholes leaving the shirt's shoulders showing
	_shade_poly(PackedVector2Array([
		neck + Vector2(-u * 0.185, -u * 0.075), sl + Vector2(u * 0.10, -u * 0.135), sl + Vector2(u * 0.04, u * 0.05),
		sl + Vector2(-u * 0.02, u * 0.42), Vector2(cx - u * 0.58, waist_y), Vector2(cx - u * 0.04, waist_y),
		neck + Vector2(-u * 0.04, u * 0.55)]), VEST, light, reach, 0.6)
	_shade_poly(PackedVector2Array([
		neck + Vector2(u * 0.185, -u * 0.075), sr + Vector2(-u * 0.10, -u * 0.135), sr + Vector2(-u * 0.04, u * 0.05),
		sr + Vector2(u * 0.02, u * 0.42), Vector2(cx + u * 0.58, waist_y), Vector2(cx + u * 0.04, waist_y),
		neck + Vector2(u * 0.04, u * 0.55)]), VEST.darkened(0.15), light, reach, 0.6)
	# THE FACELIFT (2026-11-10). He was a pale shirt, a black shape and a dot-eyed oval. Now: lapels
	# on the waistcoat with a lit edge, brass buttons, a watch chain swinging to its pocket, a red
	# neckerchief knotted at the throat, and the lantern (at his right hand, screen-left) lighting one
	# side of him warm while the other falls into the evening's blue.
	var lap_l: PackedVector2Array = PackedVector2Array([neck + Vector2(-u * 0.15, -u * 0.02), neck + Vector2(-u * 0.04, u * 0.55),
		neck + Vector2(-u * 0.20, u * 0.34), neck + Vector2(-u * 0.27, u * 0.06)])
	var lap_r: PackedVector2Array = PackedVector2Array([neck + Vector2(u * 0.15, -u * 0.02), neck + Vector2(u * 0.04, u * 0.55),
		neck + Vector2(u * 0.20, u * 0.34), neck + Vector2(u * 0.27, u * 0.06)])
	_shade_poly(lap_l, VEST.lightened(0.10), light, reach, 0.62)
	_shade_poly(lap_r, VEST.lightened(0.02), light, reach, 0.62)
	draw_polyline(PackedVector2Array([lap_l[3], lap_l[2], lap_l[1]]), Color(1.0, 0.85, 0.60, 0.22), maxf(2.0, u * 0.030), true)
	draw_polyline(PackedVector2Array([lap_r[3], lap_r[2], lap_r[1]]), Color(0, 0, 0, 0.30), maxf(2.0, u * 0.030), true)
	# the front edge, four brass buttons, each with a glint
	draw_line(neck + Vector2(-u * 0.04, u * 0.55), Vector2(cx - u * 0.04, waist_y), Color(0, 0, 0, 0.45), maxf(1.0, u * 0.022))
	for k in 4:
		var bp: Vector2 = neck + Vector2(-u * 0.085, u * (0.66 + 0.15 * float(k)))
		if bp.y > waist_y - u * 0.04:
			break
		draw_circle(bp, u * 0.030, BRASS.darkened(0.25))
		draw_circle(bp + Vector2(-u * 0.008, -u * 0.008), u * 0.014, BRASS.lightened(0.35))
	# a watch chain from a buttonhole down and across to the pocket, and the pocket's welt
	var ch_a: Vector2 = neck + Vector2(-u * 0.085, u * 0.81)
	var ch_b: Vector2 = Vector2(cx + u * 0.34, minf(waist_y - u * 0.06, neck.y + u * 1.02))
	var chain: PackedVector2Array = PackedVector2Array()
	for k in 11:
		var f: float = float(k) / 10.0
		chain.append(ch_a.lerp(ch_b, f) + Vector2(0, sin(f * PI) * u * 0.10))
	if ch_b.y > ch_a.y - u * 0.3:
		# ONE smoothed line, at least two units wide: a chain a pixel wide with a thinner glint over
		# it shimmered as his breathing carried it across the pixel grid
		draw_polyline(chain, BRASS.darkened(0.05), maxf(2.2, u * 0.036), true)
		draw_line(ch_b + Vector2(-u * 0.10, 0), ch_b + Vector2(u * 0.12, -u * 0.01), Color(0, 0, 0, 0.45), maxf(1.0, u * 0.022))
	# the neck, with the jaw's shadow across it
	_shade_poly(PackedVector2Array([neck + Vector2(-u * 0.14, -u * 0.30), neck + Vector2(u * 0.14, -u * 0.30),
		neck + Vector2(u * 0.16, u * 0.05), neck + Vector2(0, u * 0.22), neck + Vector2(-u * 0.16, u * 0.05)]),
		SKIN.darkened(0.18), light, reach, 0.75)
	draw_polygon(PackedVector2Array([neck + Vector2(-u * 0.14, -u * 0.30), neck + Vector2(u * 0.14, -u * 0.30),
		neck + Vector2(u * 0.15, -u * 0.12), neck + Vector2(-u * 0.15, -u * 0.12)]),
		PackedColorArray([Color(COOL, 0.42), Color(COOL, 0.42), Color(COOL, 0.0), Color(COOL, 0.0)]))
	# the shirt's collar points
	_shade_poly(PackedVector2Array([neck + Vector2(-u * 0.20, -u * 0.06), neck + Vector2(-u * 0.05, u * 0.02), neck + Vector2(-u * 0.13, u * 0.20)]), SHIRT, light, reach, 0.6)
	_shade_poly(PackedVector2Array([neck + Vector2(u * 0.20, -u * 0.06), neck + Vector2(u * 0.05, u * 0.02), neck + Vector2(u * 0.13, u * 0.20)]), SHIRT.darkened(0.10), light, reach, 0.6)
	# the neckerchief: a band round the throat, a knot, and two short tails
	_shade_poly(PackedVector2Array([neck + Vector2(-u * 0.17, -u * 0.04), neck + Vector2(u * 0.17, -u * 0.04),
		neck + Vector2(u * 0.12, u * 0.10), neck + Vector2(0, u * 0.16), neck + Vector2(-u * 0.12, u * 0.10)]), KERCHIEF, light, reach, 0.6)
	_shade_poly(PackedVector2Array([neck + Vector2(-u * 0.02, u * 0.14), neck + Vector2(-u * 0.13, u * 0.40), neck + Vector2(-u * 0.03, u * 0.36)]), KERCHIEF.darkened(0.12), light, reach, 0.6)
	_shade_poly(PackedVector2Array([neck + Vector2(u * 0.02, u * 0.14), neck + Vector2(u * 0.10, u * 0.36), neck + Vector2(u * 0.01, u * 0.33)]), KERCHIEF.darkened(0.25), light, reach, 0.6)
	_shade_poly(_oval(neck + Vector2(0, u * 0.13), u * 0.055, u * 0.045, 10), KERCHIEF.lightened(0.08), light, reach, 0.7)
	# (a "far side in shadow" overlay across his body was here; its hard diagonal edge showed as a
	# strange line on the screen's right, and the darker right half of the waistcoat already says it)
	# and the lantern's warm rim down his near side
	draw_polyline(PackedVector2Array([sl + Vector2(-u * 0.15, u * 0.28),
		sl + Vector2(-u * 0.13, u * 0.40), Vector2(cx - u * 0.60, waist_y)]), Color(1.0, 0.82, 0.52, 0.42), maxf(1.2, u * 0.028), true)
	_draw_head(pose["head"], pose["tilt"], light, reach)

func _draw_head(hc: Vector2, tilt: float, light: Vector2, reach: float) -> void:
	# A FACE WITH A CHARACTER (2026-11-10): a showman who has done this a thousand times. A head with
	# a jaw and a chin, cheekbones, ears set back, sideburns under a newsboy cap; heavy-lidded eyes on
	# the player, one brow up; a nose with a bridge and wings; a mustache waxed to two curls over a
	# one-sided smirk. The lantern lights his right cheek (screen-left); the other side goes cool.
	var u: float = hs
	var rx: float = u * 0.33
	var ry: float = u * 0.42
	var rot: float = tilt * 0.12
	var at = func(x: float, y: float) -> Vector2: return hc + Vector2(x * rx, y * ry).rotated(rot)
	# ears, then the skull: wide at the cheekbones, narrowing to a squared chin
	_shade_poly(_oval(at.call(-1.0, 0.04), u * 0.065, u * 0.11), SKIN.darkened(0.10), light, reach, 0.75)
	_shade_poly(_oval(at.call(1.0, 0.04), u * 0.065, u * 0.11), SKIN.darkened(0.30), light, reach, 0.75)
	draw_arc(at.call(-1.0, 0.04), u * 0.04, PI * 0.6, PI * 1.6, 8, Color(0, 0, 0, 0.25), maxf(1.0, u * 0.014))
	var outline: Array = [[0.0, -1.0], [0.45, -0.94], [0.80, -0.70], [0.96, -0.30], [0.98, 0.10], [0.90, 0.42],
		[0.72, 0.70], [0.44, 0.92], [0.20, 1.0], [-0.20, 1.0], [-0.44, 0.92], [-0.72, 0.70], [-0.90, 0.42],
		[-0.98, 0.10], [-0.96, -0.30], [-0.80, -0.70], [-0.45, -0.94]]
	var face: PackedVector2Array = PackedVector2Array()
	for q in outline:
		face.append(at.call(float(q[0]), float(q[1])))
	_shade_poly(face, SKIN, light, reach * 0.9, 0.80)
	# the far side of the face in cool shadow; the near cheekbone catching the lantern
	draw_polygon(PackedVector2Array([at.call(0.15, -0.9), at.call(0.96, -0.5), at.call(0.90, 0.45), at.call(0.40, 0.95), at.call(0.15, 0.95)]),
		PackedColorArray([Color(COOL, 0.0), Color(COOL, 0.30), Color(COOL, 0.34), Color(COOL, 0.26), Color(COOL, 0.0)]))
	draw_colored_polygon(_oval(at.call(-0.58, 0.16), u * 0.085, u * 0.055, 10), Color(1.0, 0.86, 0.62, 0.16))
	draw_colored_polygon(_oval(at.call(-0.50, 0.34), u * 0.07, u * 0.05, 10), Color(0.90, 0.40, 0.30, 0.10))
	# the hollow under each cheekbone
	draw_line(at.call(-0.80, 0.30), at.call(-0.50, 0.62), Color(0, 0, 0, 0.10), u * 0.05)
	draw_line(at.call(0.80, 0.30), at.call(0.50, 0.62), Color(0, 0, 0, 0.14), u * 0.05)
	# sideburns down from under the cap
	var hair: Color = Color(0.20, 0.13, 0.09)
	for s in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([at.call(s * 0.97, -0.34), at.call(s * 0.80, -0.34), at.call(s * 0.82, 0.10), at.call(s * 0.95, 0.20)]),
			hair if s < 0.0 else hair.darkened(0.3))
	# the cap's shadow over the brow
	draw_polygon(PackedVector2Array([at.call(-0.97, -0.44), at.call(0.97, -0.44), at.call(0.95, -0.10), at.call(-0.95, -0.10)]),
		PackedColorArray([Color(0, 0, 0, 0.26), Color(0, 0, 0, 0.26), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0)]))
	# the eyes: a lidded almond, the iris half under the lid, a glint; the left brow raised
	for s in [-1.0, 1.0]:
		var e: Vector2 = at.call(s * 0.42, -0.12)
		var almond: PackedVector2Array = PackedVector2Array()
		for k in 12:
			var a2: float = TAU * float(k) / 12.0
			almond.append(e + Vector2(cos(a2) * u * 0.070, sin(a2) * u * (0.022 if sin(a2) < 0.0 else 0.030)).rotated(rot))
		draw_colored_polygon(almond, Color(0.95, 0.92, 0.88))
		draw_circle(e + Vector2(0, u * 0.004).rotated(rot), u * 0.027, Color(0.30, 0.20, 0.12))
		draw_circle(e + Vector2(0, u * 0.004).rotated(rot), u * 0.013, Color(0.05, 0.04, 0.04))
		draw_circle(e + Vector2(-u * 0.010, -u * 0.006).rotated(rot), u * 0.007, Color(1, 1, 1, 0.9))
		# the heavy upper lid, and a line under the eye
		draw_line(e + Vector2(-u * 0.078, -u * 0.012).rotated(rot), e + Vector2(u * 0.078, -u * 0.016).rotated(rot), Color(0.16, 0.10, 0.08), u * 0.022)
		draw_line(e + Vector2(-u * 0.055, u * 0.040).rotated(rot), e + Vector2(u * 0.055, u * 0.038).rotated(rot), Color(0, 0, 0, 0.12), u * 0.012)
		# the brow: thick at the nose, tapering out; the one on the lantern's side cocked up
		var lift: float = -u * 0.035 if s < 0.0 else 0.0
		draw_colored_polygon(PackedVector2Array([e + Vector2(-s * u * 0.075, -u * 0.058).rotated(rot), e + Vector2(s * u * 0.010, -u * 0.088 + lift).rotated(rot),
			e + Vector2(s * u * 0.105, -u * 0.058 + lift * 0.6).rotated(rot), e + Vector2(s * u * 0.010, -u * 0.062 + lift).rotated(rot)]), hair)
	# the nose: a lit bridge, a shadow down its far side, the tip and two wings
	draw_line(at.call(-0.03, -0.14), at.call(-0.05, 0.20), Color(1.0, 0.92, 0.80, 0.22), u * 0.03)
	draw_line(at.call(0.10, -0.10), at.call(0.13, 0.22), Color(0, 0, 0, 0.20), u * 0.04)
	_shade_poly(_oval(at.call(0.0, 0.26), u * 0.060, u * 0.045, 10), SKIN.lightened(0.04), light, reach, 0.85)
	draw_circle(at.call(-0.13, 0.30), u * 0.016, Color(0, 0, 0, 0.35))
	draw_circle(at.call(0.13, 0.30), u * 0.016, Color(0, 0, 0, 0.40))
	# stubble along the jaw
	draw_colored_polygon(PackedVector2Array([at.call(-0.90, 0.36), at.call(0.90, 0.36), at.call(0.44, 0.94), at.call(-0.44, 0.94)]), Color(0.22, 0.16, 0.13, 0.16))
	# the mustache: full under the nose, waxed out to a curl at each end
	for s in [-1.0, 1.0]:
		var m: PackedVector2Array = PackedVector2Array([at.call(0.0, 0.37), at.call(s * 0.22, 0.34), at.call(s * 0.50, 0.42),
			at.call(s * 0.66, 0.36), at.call(s * 0.62, 0.48), at.call(s * 0.40, 0.52), at.call(s * 0.14, 0.47), at.call(0.0, 0.46)])
		draw_colored_polygon(m, hair if s < 0.0 else hair.darkened(0.25))
		draw_arc(at.call(s * 0.66, 0.40), u * 0.028, (PI * 0.2 if s > 0.0 else PI * 0.8), (PI * 1.6 if s > 0.0 else -PI * 0.6), 8, hair, maxf(1.0, u * 0.016))
	draw_line(at.call(-0.30, 0.40), at.call(-0.10, 0.40), Color(1, 1, 1, 0.10), u * 0.012)
	# the smirk: up at one corner, the lower lip's light under it, a crease beside it
	draw_polyline(PackedVector2Array([at.call(-0.26, 0.60), at.call(0.0, 0.62), at.call(0.24, 0.58), at.call(0.34, 0.53)]), Color(0.40, 0.16, 0.14, 0.9), maxf(1.0, u * 0.024), true)
	draw_line(at.call(-0.14, 0.68), at.call(0.14, 0.67), Color(1.0, 0.80, 0.70, 0.16), u * 0.02)
	draw_arc(at.call(0.40, 0.52), u * 0.05, -PI * 0.35, PI * 0.35, 6, Color(0, 0, 0, 0.18), maxf(1.0, u * 0.012))
	draw_line(at.call(-0.08, 0.86), at.call(0.08, 0.86), Color(0, 0, 0, 0.12), u * 0.014)
	# THE NEWSBOY CAP: a full soft crown in panels meeting at a button, drooping over a short peak
	var crown: PackedVector2Array = PackedVector2Array()
	for k in 17:
		var a3: float = PI * 1.0 + PI * 1.0 * float(k) / 16.0
		crown.append(at.call(cos(a3) * 1.22, sin(a3) * 0.80 - 0.40))
	crown.append(at.call(1.12, -0.30))
	crown.append(at.call(-1.12, -0.30))
	_shade_poly(crown, CAP, light, reach, 0.55)
	for k in 5:
		var px: float = -0.8 + 0.4 * float(k)
		draw_line(at.call(0.0, -1.18), at.call(px, -0.34), Color(0, 0, 0, 0.16), maxf(1.0, u * 0.012))
	draw_polygon(PackedVector2Array([at.call(0.1, -1.18), at.call(1.20, -0.55), at.call(1.12, -0.30), at.call(0.1, -0.30)]),
		PackedColorArray([Color(COOL, 0.0), Color(COOL, 0.36), Color(COOL, 0.36), Color(COOL, 0.0)]))
	draw_circle(at.call(0.0, -1.18), u * 0.035, CAP.lightened(0.15))
	# the peak: a curved brim, its top catching light, its underside dark
	# (its lower edge is a real ARC: three nearly collinear points along it sometimes failed to
	# triangulate as he breathed, and the peak flickered between its shading and a flat fallback)
	var peak: PackedVector2Array = PackedVector2Array([at.call(-1.02, -0.34), at.call(1.02, -0.34)])
	for k in 9:
		var pa: float = PI * float(k) / 8.0
		peak.append(at.call(cos(pa) * 1.00, -0.26 + sin(pa) * 0.17))
	_shade_poly(peak, CAP.darkened(0.30), light, reach, 0.6)
	draw_line(at.call(-1.00, -0.33), at.call(1.00, -0.33), Color(1.0, 0.90, 0.70, 0.20), maxf(2.0, u * 0.03), true)

# Two bones from the shoulder to the hand, the elbow bending outward. A rolled shirt sleeve to the
# elbow, a bare forearm, and the hand cupped over the cup's top.
func _draw_arm(sh: Vector2, hand: Vector2, side: float) -> void:
	var u: float = hs
	# seen from the front, an arm reaching forward to the table is FORESHORTENED: drawn at its full
	# length, the elbows had to stick out like wings to make up the distance
	var l1: float = u * 1.00
	var l2: float = u * 0.92
	# a reach longer than the arm (across the table, even after the lean) is drawn a little longer:
	# from the front, an arm coming toward the viewer and across shows more of its length
	var want: float = sh.distance_to(hand)
	if want > l1 + l2 - 0.5:
		var grow: float = minf(1.45, (want + 0.5) / (l1 + l2))
		l1 *= grow
		l2 *= grow
	var d: float = clampf(want, 0.01, l1 + l2 - 0.5)
	var dirv: Vector2 = (hand - sh).normalized()
	var a: float = acos(clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0))
	# Of the two ways the arm can bend, always the one with the elbow OUT to the side (then down).
	# Choosing by whether the hand was above or below the shoulder flipped the elbow from one side
	# to the other mid-move, which is what made the arms thrash.
	# Each arm always bends the SAME way round (its elbow on its own outer side of the line from
	# the shoulder to the hand), so the elbow moves continuously. Picking whichever of the two
	# solutions lay further out flipped it across in one frame when the arm was nearly straight.
	var elbow: Vector2 = sh + dirv.rotated(a * -side) * l1
	var light: Vector2 = _lantern_pos() + Vector2(0, -u * 0.6)
	# a slim sleeve from inside the shoulder's cap, rolled at the elbow, then the bare forearm
	# (the shoulder line SLOPES DOWN from the neck to the arm: the joint sits below the neck's base)
	# THE SHOULDER CAP TURNS WITH THE ARM. The sleeve's round end at the joint, drawn bare, was a pale
	# ball on the dark waistcoat; a strap fixed in place over it cut off an arm crossing his chest (or,
	# drawn under such an arm, let the ball show again -- and switching between the two made the layers
	# swap mid-move). So the waistcoat covers the HALF of the joint that faces AWAY from the arm,
	# whichever way the arm points: its inner top for an arm hanging out to the side (the strap), its
	# outer top for one reaching across (his shoulder). It rotates continuously; nothing swaps.
	var joint: Vector2 = sh + Vector2(0, u * 0.07)
	_limb(joint, elbow, u * 0.165, u * 0.125, SHIRT.darkened(0.04), light)
	var adir: Vector2 = (elbow - joint).normalized()
	var th: float = adir.angle()
	var cap: PackedVector2Array = PackedVector2Array()
	for k in 13:
		var ca: float = th + PI * 0.5 + PI * float(k) / 12.0
		cap.append(joint + adir * u * 0.035 + Vector2(cos(ca), sin(ca)) * u * 0.178)
	_shade_poly(cap, VEST if side < 0.0 else VEST.darkened(0.15), light, hs * 4.2, 0.6)
	# the armhole's seam across the sleeve, in shadow
	draw_line(cap[0], cap[12], Color(0, 0, 0, 0.38), maxf(1.0, u * 0.022), true)
	# the sleeve is ROLLED to the elbow (a thick fold with a lit top), and held by a garter above it
	var along: Vector2 = (elbow - sh).normalized()
	var acr: Vector2 = along.orthogonal()
	_shade_poly(_oval(elbow, u * 0.135, u * 0.125, 12), SHIRT.darkened(0.16), light, cup_h * 4.0, 0.55)
	draw_arc(elbow, u * 0.112, 0.0, TAU, 12, Color(0, 0, 0, 0.22), maxf(1.0, u * 0.016))
	var gp: Vector2 = sh.lerp(elbow, 0.58)
	draw_line(gp - acr * u * 0.15, gp + acr * u * 0.15, KERCHIEF.darkened(0.25), maxf(1.5, u * 0.045))
	draw_line(gp - acr * u * 0.15 - along * u * 0.012, gp + acr * u * 0.15 - along * u * 0.012, Color(1, 1, 1, 0.16), maxf(1.0, u * 0.010))
	# the forearm, tapering to the wrist
	var fdir: Vector2 = (hand - elbow).normalized()
	var wrist: Vector2 = hand - fdir * u * 0.17
	_limb(elbow, wrist, u * 0.105, u * 0.070, SKIN.darkened(0.05), light, 0.75)
	# THE HAND, resting on the cup: the back of the hand widening from the wrist to the knuckles,
	# four fingers draped over the cup's near edge (each its own length, a knuckle on each), and the
	# thumb down its inner side. It was an oval with four sticks.
	# fn points to the hand's OUTER side: a quarter turn from the forearm, the same way round always
	# (choosing by its sign flipped the whole hand over whenever the forearm came level)
	var fn: Vector2 = fdir.rotated(-side * PI * 0.5)
	var back: PackedVector2Array = PackedVector2Array([
		wrist - fn * u * 0.070, wrist + fn * u * 0.070,
		hand + fn * u * 0.135 - fdir * u * 0.02, hand + fn * u * 0.150 + fdir * u * 0.05,
		hand + fn * u * 0.05 + fdir * u * 0.085, hand - fn * u * 0.07 + fdir * u * 0.080,
		hand - fn * u * 0.150 + fdir * u * 0.04, hand - fn * u * 0.130 - fdir * u * 0.03])
	_shade_poly(back, SKIN, light, u * 4.0, 0.78)
	var down: Vector2 = (fdir * 0.35 + Vector2(0, 1.0)).normalized()
	var lens: Array = [0.150, 0.180, 0.170, 0.135]
	for f in 4:
		var kx: float = -0.118 + 0.079 * float(f)
		var k0: Vector2 = hand + fn * u * kx + fdir * u * 0.065
		var fd: Vector2 = down.rotated((float(f) - 1.5) * 0.10 * side)
		var mid: Vector2 = k0 + fd * u * float(lens[f]) * 0.55
		var tip: Vector2 = mid + (fd * 0.75 + Vector2(0, 0.45)).normalized() * u * float(lens[f]) * 0.45
		_limb(k0, mid, u * 0.040, u * 0.036, SKIN.darkened(0.03), light, 0.78)
		_limb(mid, tip, u * 0.036, u * 0.030, SKIN.darkened(0.09), light, 0.75)
		draw_arc(k0, u * 0.030, PI * 1.1, PI * 1.9, 5, Color(0, 0, 0, 0.14), maxf(1.0, u * 0.010))
	# the thumb, from the heel of the hand down the inner side
	var t0: Vector2 = wrist - fn * u * 0.075 + fdir * u * 0.05
	var t1: Vector2 = t0 - fn * u * 0.085 + down * u * 0.09
	var t2: Vector2 = t1 + down * u * 0.085
	_limb(t0, t1, u * 0.050, u * 0.040, SKIN.darkened(0.06), light, 0.78)
	_limb(t1, t2, u * 0.040, u * 0.030, SKIN.darkened(0.10), light, 0.75)

func _limb(a: Vector2, b: Vector2, ra: float, rb: float, c: Color, light: Vector2, ambient: float = 0.5) -> void:
	var dv: Vector2 = b - a
	if dv.length() < 0.01:
		return
	var un: Vector2 = dv.normalized()
	var n: Vector2 = un.orthogonal()
	var pts: PackedVector2Array = PackedVector2Array()
	for k in 6:
		var ang: float = PI * float(k) / 5.0
		pts.append(b + (n * cos(ang) + un * sin(ang)) * rb)
	for k in 6:
		var ang2: float = PI * float(k) / 5.0
		pts.append(a + (-n * cos(ang2) - un * sin(ang2)) * ra)
	_shade_poly(pts, c, light, cup_h * 4.0, ambient)

func _draw_table() -> void:
	var r: Rect2 = table_rect
	var inset: float = r.size.x * 0.05
	var light: Vector2 = _lantern_pos()
	var top: PackedVector2Array = PackedVector2Array([
		Vector2(r.position.x + inset, r.position.y), Vector2(r.end.x - inset, r.position.y),
		Vector2(r.end.x, r.end.y), Vector2(r.position.x, r.end.y)])
	var cols: PackedColorArray = PackedColorArray()
	for p in top:
		var k: float = 0.55 + 0.45 * clampf(1.0 - p.distance_to(light) / (r.size.x * 0.9), 0.0, 1.0)
		cols.append(Color(BAIZE.r * k * 1.15, BAIZE.g * k, BAIZE.b * k))
	draw_polygon(top, cols)
	# a soft pool of light where the cups stand
	var pc: Vector2 = Vector2(r.get_center().x, base_y - cup_h * 0.05)
	draw_texture_rect(_glow_tex(), Rect2(pc - Vector2(r.size.x * 0.42, r.size.y * 0.55), Vector2(r.size.x * 0.84, r.size.y * 1.1)), false, Color(0.95, 0.85, 0.55, 0.16))
	# THE TABLE (2026-11-10 facelift): a shadow on the pavement under it; worn rings in the baize
	# where the cups always stand; a wooden rail along its front edge with a lit top and brass
	# corners; the stakes -- a short stack of coins and a folded note -- at its far end.
	draw_colored_polygon(_oval(Vector2(r.get_center().x, r.end.y + skirt_h + 6.0), r.size.x * 0.56, maxf(8.0, skirt_h * 0.16), 22), Color(0, 0, 0, 0.42))
	for sx in slot_x:
		var ring: PackedVector2Array = _oval(Vector2(float(sx), base_y), cup_w * 0.62, cup_w * 0.62 * VIEW_TILT, 22)
		ring.append(ring[0])
		draw_polyline(ring, Color(1, 1, 1, 0.07), maxf(1.0, cup_w * 0.05), true)
	var speck: RandomNumberGenerator = RandomNumberGenerator.new()
	speck.seed = 77
	for k in 70:
		var fy: float = speck.randf()
		var fx2: float = speck.randf()
		var sp: Vector2 = Vector2(lerpf(r.position.x + inset * (1.0 - fy), r.end.x - inset * (1.0 - fy), fx2), lerpf(r.position.y, r.end.y, fy))
		draw_rect(Rect2(sp, Vector2(1.5, 1.0)), Color(1, 1, 1, 0.05) if speck.randf() < 0.5 else Color(0, 0, 0, 0.10))
	# the stakes
	var st: Vector2 = Vector2(r.end.x - r.size.x * 0.085, r.position.y + r.size.y * 0.52)
	var note: PackedVector2Array = PackedVector2Array([st + Vector2(-cup_w * 0.52, -cup_w * 0.10), st + Vector2(cup_w * 0.10, -cup_w * 0.16),
		st + Vector2(cup_w * 0.16, cup_w * 0.02), st + Vector2(-cup_w * 0.46, cup_w * 0.08)])
	draw_colored_polygon(note, Color(0.55, 0.66, 0.50))
	draw_polyline(PackedVector2Array([note[0], note[1], note[2], note[3], note[0]]), Color(0.25, 0.35, 0.25, 0.8), 1.0, true)
	draw_line(note[0].lerp(note[3], 0.5), note[1].lerp(note[2], 0.5), Color(0.25, 0.35, 0.25, 0.5), 1.0)
	for k in 4:
		var cc: Vector2 = st + Vector2(cup_w * 0.16, cup_w * 0.02 - float(k) * cup_w * 0.045)
		draw_colored_polygon(_oval(cc, cup_w * 0.17, cup_w * 0.17 * VIEW_TILT, 14), BRASS.darkened(0.30 - 0.06 * float(k)))
		draw_colored_polygon(_oval(cc + Vector2(0, -cup_w * 0.018), cup_w * 0.17, cup_w * 0.17 * VIEW_TILT, 14), BRASS.darkened(0.08 - 0.02 * float(k)))
	draw_colored_polygon(_oval(st + Vector2(cup_w * 0.14, cup_w * 0.02 - 3.0 * cup_w * 0.045 - cup_w * 0.03), cup_w * 0.07, cup_w * 0.07 * VIEW_TILT, 10), Color(1.0, 0.96, 0.78, 0.55))
	draw_colored_polygon(_oval(st + Vector2(-cup_w * 0.22, cup_w * 0.16), cup_w * 0.14, cup_w * 0.14 * VIEW_TILT, 14), Color(0.78, 0.78, 0.80))
	# the front rail
	var rail_h: float = maxf(5.0, cup_h * 0.13)
	var rail: Rect2 = Rect2(r.position.x - 3.0, r.end.y - 1.0, r.size.x + 6.0, rail_h)
	var wl: float = 0.60 + 0.40 * clampf(1.0 - absf(rail.position.x - light.x) / (r.size.x * 0.9), 0.0, 1.0)
	draw_polygon(PackedVector2Array([rail.position, Vector2(rail.end.x, rail.position.y), rail.end, Vector2(rail.position.x, rail.end.y)]),
		PackedColorArray([WOOD.lightened(0.12) * wl, WOOD.darkened(0.25), WOOD.darkened(0.50), WOOD.darkened(0.15) * wl]))
	draw_line(rail.position, Vector2(rail.end.x, rail.position.y), Color(1.0, 0.86, 0.60, 0.40), 1.5)
	for cxp in [rail.position.x + rail_h * 0.7, rail.end.x - rail_h * 0.7]:
		draw_circle(Vector2(cxp, rail.position.y + rail_h * 0.5), rail_h * 0.28, BRASS.darkened(0.2))
		draw_circle(Vector2(cxp - 0.6, rail.position.y + rail_h * 0.5 - 0.6), rail_h * 0.12, BRASS.lightened(0.3))
	# the cloth down the front: soft folds, shaded from the lantern, a gold fringe
	var sk: Rect2 = Rect2(r.position.x, r.end.y + maxf(5.0, cup_h * 0.13) - 1.0, r.size.x, skirt_h)
	var folds: int = 14
	for k in folds:
		var x0: float = sk.position.x + sk.size.x * float(k) / float(folds)
		var x1: float = sk.position.x + sk.size.x * float(k + 1) / float(folds)
		var xm: float = (x0 + x1) * 0.5
		var lite: float = 0.62 + 0.38 * clampf(1.0 - absf(xm - light.x) / (r.size.x * 0.9), 0.0, 1.0)
		var cl: Color = Color(CLOTH.r * lite, CLOTH.g * lite, CLOTH.b * lite)
		draw_polygon(PackedVector2Array([Vector2(x0, sk.position.y), Vector2(xm, sk.position.y), Vector2(xm, sk.end.y), Vector2(x0, sk.end.y)]),
			PackedColorArray([cl.darkened(0.35), cl.lightened(0.05), cl.lightened(0.05), cl.darkened(0.35)]))
		draw_polygon(PackedVector2Array([Vector2(xm, sk.position.y), Vector2(x1, sk.position.y), Vector2(x1, sk.end.y), Vector2(xm, sk.end.y)]),
			PackedColorArray([cl.lightened(0.05), cl.darkened(0.35), cl.darkened(0.35), cl.lightened(0.05)]))
	draw_rect(Rect2(sk.position.x, sk.position.y, sk.size.x, 7.0), Color(0, 0, 0, 0.35))
	var fringe_y: float = sk.end.y
	var x: float = sk.position.x + 3.0
	while x < sk.end.x - 2.0:
		draw_line(Vector2(x, fringe_y - 5.0), Vector2(x + 0.5, fringe_y + 6.0), FRINGE.darkened(0.1), 1.5)
		x += 4.0
	draw_rect(Rect2(sk.position.x, fringe_y - 8.0, sk.size.x, 4.0), FRINGE.darkened(0.2))
	draw_rect(Rect2(sk.position.x, fringe_y - 8.0, sk.size.x, 1.5), FRINGE.lightened(0.2))
	# a gold braid above the fringe: two lines and a run of small scallops between them
	var braid_y: float = fringe_y - 8.0 - maxf(9.0, skirt_h * 0.16)
	draw_line(Vector2(sk.position.x, braid_y), Vector2(sk.end.x, braid_y), FRINGE.darkened(0.15), 1.5)
	draw_line(Vector2(sk.position.x, braid_y + maxf(6.0, skirt_h * 0.10)), Vector2(sk.end.x, braid_y + maxf(6.0, skirt_h * 0.10)), FRINGE.darkened(0.15), 1.5)
	var sc_w: float = maxf(8.0, skirt_h * 0.14)
	var sxp: float = sk.position.x + sc_w * 0.5
	while sxp < sk.end.x:
		draw_arc(Vector2(sxp, braid_y + 1.0), sc_w * 0.42, 0.0, PI, 8, FRINGE.darkened(0.05), 1.3)
		sxp += sc_w
	# a tassel at each front corner
	for tx in [sk.position.x + 4.0, sk.end.x - 4.0]:
		draw_line(Vector2(tx, sk.position.y + 2.0), Vector2(tx, sk.position.y + skirt_h * 0.34), FRINGE.darkened(0.1), 2.0)
		draw_circle(Vector2(tx, sk.position.y + skirt_h * 0.36), maxf(3.0, skirt_h * 0.045), FRINGE)
		draw_colored_polygon(PackedVector2Array([Vector2(tx - skirt_h * 0.035, sk.position.y + skirt_h * 0.38), Vector2(tx + skirt_h * 0.035, sk.position.y + skirt_h * 0.38),
			Vector2(tx + skirt_h * 0.06, sk.position.y + skirt_h * 0.56), Vector2(tx - skirt_h * 0.06, sk.position.y + skirt_h * 0.56)]), FRINGE.darkened(0.18))

func _draw_lantern() -> void:
	var u: float = cup_h
	var p: Vector2 = _lantern_pos()
	var g: Vector2 = p + Vector2(0, -u * 0.50)
	draw_texture_rect(_glow_tex(), Rect2(g - Vector2(u * 2.4, u * 2.4), Vector2(u * 4.8, u * 4.8)), false, Color(LAMP, 0.30))
	draw_texture_rect(_glow_tex(), Rect2(g - Vector2(u * 0.7, u * 0.7), Vector2(u * 1.4, u * 1.4)), false, Color(LAMP, 0.45))
	draw_colored_polygon(_oval(p + Vector2(0, u * 0.02), u * 0.30, u * 0.07), Color(0, 0, 0, 0.35))
	# base, glass chimney with the flame, cap, wire guards and the handle
	draw_rect(Rect2(p.x - u * 0.20, p.y - u * 0.16, u * 0.40, u * 0.16), Color(0.20, 0.18, 0.16))
	draw_rect(Rect2(p.x - u * 0.20, p.y - u * 0.16, u * 0.40, u * 0.03), Color(0.45, 0.40, 0.32))
	var glass: PackedVector2Array = PackedVector2Array()
	for k in 16:
		var a: float = TAU * float(k) / 16.0
		glass.append(p + Vector2(cos(a) * u * 0.17, -u * 0.48 + sin(a) * u * 0.32))
	draw_colored_polygon(glass, Color(1.0, 0.88, 0.62, 0.55))
	draw_colored_polygon(_oval(p + Vector2(0, -u * 0.40), u * 0.08, u * 0.16), Color(1.0, 0.70, 0.30, 0.45))
	draw_colored_polygon(_oval(p + Vector2(0, -u * 0.44), u * 0.05, u * 0.11), Color(1.0, 0.96, 0.80))
	draw_rect(Rect2(p.x - u * 0.14, p.y - u * 0.86, u * 0.28, u * 0.08), Color(0.20, 0.18, 0.16))
	draw_arc(p + Vector2(0, -u * 0.86), u * 0.16, PI, TAU, 12, Color(0.25, 0.23, 0.20), 2.0)
	draw_line(p + Vector2(-u * 0.19, -u * 0.16), p + Vector2(-u * 0.19, -u * 0.80), Color(0.20, 0.18, 0.16), 2.0)
	draw_line(p + Vector2(u * 0.19, -u * 0.16), p + Vector2(u * 0.19, -u * 0.80), Color(0.20, 0.18, 0.16), 2.0)

# A polished copper cup, upside down, drawn as the ROUND solid it is, seen a little from above:
# the body is built from strips around its FRONT half, each following the curve of the rim (the
# rim's front edge bows toward the viewer, it is not a straight line), shaded by which way that
# strip faces -- a sharp highlight where it faces the lantern, a dark reflection, a warm second
# reflection, darkening toward the silhouette. The top (the cup's base) is a full ellipse.
const VIEW_TILT: float = 0.30      # how far from above the table is seen: ellipse height / width

func _draw_cup(pose: Vector3) -> void:
	var x: float = pose.x
	var yb: float = pose.y - pose.z
	var rb: float = cup_w * 0.5
	var rt: float = cup_w * 0.32
	var yt: float = yb - cup_h
	var tilt: float = VIEW_TILT
	# its shadow on the baize, wider and softer as it rises
	var sa: float = clampf(0.45 - pose.z / cup_h * 0.35, 0.08, 0.45)
	draw_colored_polygon(_oval(Vector2(x + rb * 0.12, pose.y + rb * 0.05), rb * (1.12 + pose.z / cup_h * 0.3), rb * tilt * 1.25, 28), Color(0, 0, 0, sa))
	var light_left: bool = _lantern_pos().x < x
	var n: int = 28
	for k in n:
		var th0: float = PI - PI * float(k) / float(n)
		var th1: float = PI - PI * float(k + 1) / float(n)
		var thm: float = (th0 + th1) * 0.5
		var c0: Color = _metal(thm, light_left, 0.0)
		var c1: Color = _metal(thm, light_left, 1.0)
		var pts: PackedVector2Array = PackedVector2Array([
			Vector2(x + rt * cos(th0), yt + rt * tilt * sin(th0)), Vector2(x + rt * cos(th1), yt + rt * tilt * sin(th1)),
			Vector2(x + rb * cos(th1), yb + rb * tilt * sin(th1)), Vector2(x + rb * cos(th0), yb + rb * tilt * sin(th0))])
		draw_polygon(pts, PackedColorArray([c1, c1, c0, c0]))
	# THE TOP (the cup's base, upside down) has STRUCTURE, like a turned cup's foot: a rounded
	# shoulder where the side meets it, a raised foot ring catching the light on its far side, and a
	# slightly recessed center lit the opposite way (it is concave). A single flat oval, light or
	# dark, read as a disc stuck on top.
	var tt: float = tilt * 1.12                     # seen a little more open than the rim
	var top: PackedVector2Array = _oval(Vector2(x, yt), rt, rt * tt, 32)
	var tc: PackedColorArray = PackedColorArray()
	for p in top:
		var f: float = clampf(0.5 + (p.x - x) / rt * (-0.5 if light_left else 0.5), 0.0, 1.0)
		tc.append(COPPER.darkened(0.35).lerp(COPPER.darkened(0.08), f))
	draw_polygon(top, tc)
	# the shoulder: a soft band just inside the edge, lit on the near side where it curves toward us
	var sh_band: PackedVector2Array = PackedVector2Array()
	for k in 17:
		var t: float = PI * float(k) / 16.0
		sh_band.append(Vector2(x + cos(t) * rt * 0.97, yt + sin(t) * rt * tt * 0.97))
	draw_polyline(sh_band, Color(COPPER.lightened(0.15), 0.55), maxf(1.5, cup_w * 0.04), true)
	# the foot ring: a raised ring, its far half catching the light
	var ring_far: PackedVector2Array = PackedVector2Array()
	var ring_near: PackedVector2Array = PackedVector2Array()
	for k in 17:
		var t2: float = PI + PI * float(k) / 16.0
		ring_far.append(Vector2(x + cos(t2) * rt * 0.80, yt + sin(t2) * rt * tt * 0.80))
		var t3: float = PI * float(k) / 16.0
		ring_near.append(Vector2(x + cos(t3) * rt * 0.80, yt + sin(t3) * rt * tt * 0.80))
	draw_polyline(ring_far, COPPER.lightened(0.18), maxf(1.5, cup_w * 0.035), true)
	draw_polyline(ring_near, COPPER.darkened(0.45), maxf(1.2, cup_w * 0.025), true)
	# the recessed center, lit from the side away from the lantern
	var inner: PackedVector2Array = _oval(Vector2(x, yt + rt * tt * 0.05), rt * 0.70, rt * tt * 0.66, 24)
	var ic: PackedColorArray = PackedColorArray()
	for p2 in inner:
		var g: float = clampf(0.5 - (p2.x - x) / (rt * 0.7) * (-0.5 if light_left else 0.5), 0.0, 1.0)
		ic.append(COPPER.darkened(0.40).lerp(COPPER.darkened(0.18), g))
	draw_polygon(inner, ic)
	# the outline where the base turns down into the side
	var edge: PackedVector2Array = _oval(Vector2(x, yt), rt, rt * tt, 32)
	edge.append(edge[0])
	draw_polyline(edge, COPPER.darkened(0.5), 1.0, true)
	# the rolled lip along the rim's front curve
	var lip: PackedVector2Array = PackedVector2Array()
	for k in 25:
		var th: float = PI - PI * float(k) / 24.0
		lip.append(Vector2(x + rb * 1.01 * cos(th), yb + rb * tilt * sin(th) - 2.0))
	draw_polyline(lip, COPPER.darkened(0.30), 5.0, true)
	var lip_hi: PackedVector2Array = PackedVector2Array()
	for k in 25:
		var th2: float = PI - PI * float(k) / 24.0
		lip_hi.append(Vector2(x + rb * cos(th2), yb + rb * tilt * sin(th2) - 5.0))
	draw_polyline(lip_hi, COPPER.lightened(0.25), 1.5, true)

# The copper's color for a strip facing direction th (PI = facing left, PI/2 = facing the viewer,
# 0 = facing right), at height v (0 rim .. 1 top). The lantern stands to one side and in front.
func _metal(th: float, light_left: bool, v: float) -> Color:
	var face: float = th if light_left else PI - th          # PI = toward the lantern's side
	var spec: float = exp(-pow((face - 0.72 * PI) / 0.09, 2.0))
	var warm: float = exp(-pow((face - 0.30 * PI) / 0.16, 2.0)) * 0.40
	var core: float = exp(-pow((face - 0.50 * PI) / 0.16, 2.0)) * 0.45
	var rim: float = pow(absf(cos(th)), 6.0) * 0.50          # toward the silhouette
	var k: float = 0.80 + 0.55 * warm - core - rim + v * 0.06
	var c: Color = Color(COPPER.r * k, COPPER.g * k, COPPER.b * k)
	return c.lerp(Color(1.0, 0.93, 0.80), clampf(spec, 0.0, 1.0) * 0.85)

func _draw_ball(at: Vector2) -> void:
	var r: float = cup_w * 0.25       # was 0.18: too small to spot at a glance
	draw_colored_polygon(_oval(at + Vector2(r * 0.2, 0), r * 1.1, r * 0.3), Color(0, 0, 0, 0.4))
	for k in 6:
		var f: float = 1.0 - float(k) / 6.0
		draw_circle(at - Vector2(r * 0.25 * (1.0 - f), r + r * 0.25 * (1.0 - f)), r * f,
			BALL_COLOR.darkened(0.45).lerp(BALL_COLOR.lightened(0.15), 1.0 - f))
	draw_circle(at - Vector2(r * 0.40, r * 1.42), r * 0.18, Color(1, 0.95, 0.9, 0.8))
