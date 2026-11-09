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
const VEST: Color = Color(0.17, 0.16, 0.19)
const CAP: Color = Color(0.30, 0.27, 0.24)
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

func layout(w: float, table_top_y: float, cup_height: float, skirt: float, slots: int) -> void:
	cup_h = cup_height
	cup_w = cup_h * 0.92
	base_y = table_top_y + cup_h * 0.30
	# the hustler is drawn in his own unit (hs); the table is sized for him as much as for the cups
	hs = cup_h * 1.25
	var tw: float = minf(w * 0.88, maxf(cup_w * 1.95 * float(slots) + cup_w * 2.6, hs * 5.2))
	table_rect = Rect2(w * 0.5 - tw * 0.5, table_top_y - cup_h * 0.30, tw, cup_h * 0.95)
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
func _body_pose() -> Dictionary:
	var u: float = hs
	var cx: float = table_rect.get_center().x
	var breath: float = sin(_now * 0.0021) * u * 0.025
	var sh_y: float = hustler_top + u * 1.30 + breath
	var base_l: Vector2 = Vector2(cx - u * 0.70, sh_y)
	var base_r: Vector2 = Vector2(cx + u * 0.70, sh_y)
	var hl: Vector2 = _hand[0]
	var hr: Vector2 = _hand[1]
	var rl: Vector2 = _rest(0)
	var rr: Vector2 = _rest(1)
	var sl: Vector2 = base_l + Vector2((hl.x - rl.x) * 0.14, clampf((hl.y - rl.y) * 0.15, -u * 0.18, u * 0.18))
	var sr: Vector2 = base_r + Vector2((hr.x - rr.x) * 0.14, clampf((hr.y - rr.y) * 0.15, -u * 0.18, u * 0.18))
	var reach_l: float = sl.distance_to(hl) - u * 1.85
	if reach_l > 0.0:
		sl += (hl - sl).normalized() * reach_l * 0.8
	var reach_r: float = sr.distance_to(hr) - u * 1.85
	if reach_r > 0.0:
		sr += (hr - sr).normalized() * reach_r * 0.8
	# within what a body can do: the shoulders never cross toward each other
	sl = Vector2(clampf(sl.x, base_l.x - u * 0.35, base_l.x + u * 0.35), clampf(sl.y, sh_y - u * 0.30, sh_y + u * 0.35))
	sr = Vector2(clampf(sr.x, base_r.x - u * 0.35, base_r.x + u * 0.35), clampf(sr.y, sh_y - u * 0.30, sh_y + u * 0.35))
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

func _lantern_pos() -> Vector2:
	return Vector2(table_rect.position.x + table_rect.size.x * 0.10, table_rect.position.y + cup_h * 0.15)

# A polygon lit by the lantern: brighter and warmer the nearer each corner is to it.
func _shade_poly(pts: PackedVector2Array, c: Color, light_at: Vector2, reach: float, ambient: float = 0.55) -> void:
	var cols: PackedColorArray = PackedColorArray()
	for p in pts:
		var k: float = ambient + (1.0 - ambient) * clampf(1.0 - p.distance_to(light_at) / reach, 0.0, 1.0)
		var cc: Color = Color(c.r * k, c.g * k, c.b * k, c.a)
		cols.append(cc.lerp(Color(minf(1.0, cc.r * 1.08), cc.g, cc.b * 0.85, c.a), k * 0.5))
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
		neck + Vector2(-u * 0.17, -u * 0.06), sl + Vector2(u * 0.10, -u * 0.17), sl + Vector2(-u * 0.04, -u * 0.15),
		sl + Vector2(-u * 0.14, -u * 0.06), sl + Vector2(-u * 0.17, u * 0.10), sl + Vector2(-u * 0.13, u * 0.40),
		Vector2(cx - u * 0.60, waist_y), Vector2(cx + u * 0.60, waist_y),
		sr + Vector2(u * 0.13, u * 0.40), sr + Vector2(u * 0.17, u * 0.10), sr + Vector2(u * 0.14, -u * 0.06),
		sr + Vector2(u * 0.04, -u * 0.15), sr + Vector2(-u * 0.10, -u * 0.17), neck + Vector2(u * 0.17, -u * 0.06)])
	_shade_poly(shirt, SHIRT, light, reach, 0.45)
	# the waistcoat over it, open at the front, its armholes leaving the shirt's shoulders showing
	_shade_poly(PackedVector2Array([
		neck + Vector2(-u * 0.15, -u * 0.02), sl + Vector2(u * 0.12, -u * 0.12), sl + Vector2(u * 0.04, u * 0.05),
		sl + Vector2(-u * 0.02, u * 0.42), Vector2(cx - u * 0.58, waist_y), Vector2(cx - u * 0.04, waist_y),
		neck + Vector2(-u * 0.04, u * 0.55)]), VEST, light, reach, 0.6)
	_shade_poly(PackedVector2Array([
		neck + Vector2(u * 0.15, -u * 0.02), sr + Vector2(-u * 0.12, -u * 0.12), sr + Vector2(-u * 0.04, u * 0.05),
		sr + Vector2(u * 0.02, u * 0.42), Vector2(cx + u * 0.58, waist_y), Vector2(cx + u * 0.04, waist_y),
		neck + Vector2(u * 0.04, u * 0.55)]), VEST.darkened(0.15), light, reach, 0.6)
	for k in 3:
		draw_circle(neck + Vector2(-u * 0.07, u * (0.70 + 0.16 * float(k))), u * 0.025, Color(0.75, 0.62, 0.35, 0.8))
	# the neck and the open collar
	_shade_poly(PackedVector2Array([neck + Vector2(-u * 0.14, -u * 0.30), neck + Vector2(u * 0.14, -u * 0.30),
		neck + Vector2(u * 0.16, u * 0.05), neck + Vector2(0, u * 0.22), neck + Vector2(-u * 0.16, u * 0.05)]),
		SKIN.darkened(0.15), light, reach, 0.75)
	draw_line(neck + Vector2(-u * 0.20, -u * 0.02), neck + Vector2(-u * 0.02, u * 0.22), SHIRT.darkened(0.25), u * 0.05)
	draw_line(neck + Vector2(u * 0.20, -u * 0.02), neck + Vector2(u * 0.02, u * 0.22), SHIRT.darkened(0.25), u * 0.05)
	_draw_head(pose["head"], pose["tilt"], light, reach)

func _draw_head(hc: Vector2, tilt: float, light: Vector2, reach: float) -> void:
	var u: float = hs
	var rx: float = u * 0.33
	var ry: float = u * 0.42
	var rot: float = tilt * 0.12
	var face: PackedVector2Array = PackedVector2Array()
	for k in 24:
		var a: float = TAU * float(k) / 24.0
		var p: Vector2 = Vector2(cos(a) * rx * (0.88 if sin(a) > 0.3 else 1.0), sin(a) * ry)
		face.append(hc + p.rotated(rot))
	_shade_poly(_oval(hc + Vector2(-rx * 0.98, u * 0.02).rotated(rot), u * 0.07, u * 0.11), SKIN.darkened(0.12), light, reach, 0.75)
	_shade_poly(_oval(hc + Vector2(rx * 0.98, u * 0.02).rotated(rot), u * 0.07, u * 0.11), SKIN.darkened(0.12), light, reach, 0.75)
	_shade_poly(face, SKIN, light, reach * 0.9, 0.78)
	# the cap's shadow over the brow
	draw_colored_polygon(PackedVector2Array([hc + Vector2(-rx, -ry * 0.42).rotated(rot), hc + Vector2(rx, -ry * 0.42).rotated(rot),
		hc + Vector2(rx * 0.95, -ry * 0.18).rotated(rot), hc + Vector2(-rx * 0.95, -ry * 0.18).rotated(rot)]), Color(0, 0, 0, 0.25))
	# eyes: dark, narrow, on the player
	for s in [-1.0, 1.0]:
		var e: Vector2 = hc + Vector2(s * rx * 0.40, -ry * 0.12).rotated(rot)
		draw_colored_polygon(_oval(e, u * 0.055, u * 0.022), Color(0.93, 0.90, 0.86, 0.85))
		draw_circle(e + Vector2(0, u * 0.002), u * 0.022, Color(0.16, 0.11, 0.08))
		draw_line(e + Vector2(-u * 0.07, -u * 0.05), e + Vector2(u * 0.07, -u * 0.06), Color(0.22, 0.15, 0.11), u * 0.035)
	# the nose: a shadow down one side and a lit tip
	draw_line(hc + Vector2(rx * 0.05, -ry * 0.05).rotated(rot), hc + Vector2(rx * 0.10, ry * 0.22).rotated(rot), Color(0, 0, 0, 0.15), u * 0.045)
	draw_circle(hc + Vector2(-rx * 0.02, ry * 0.24).rotated(rot), u * 0.035, SKIN.lightened(0.08))
	# stubble along the jaw, the mustache, the mouth
	draw_colored_polygon(PackedVector2Array([hc + Vector2(-rx * 0.85, ry * 0.25).rotated(rot), hc + Vector2(rx * 0.85, ry * 0.25).rotated(rot),
		hc + Vector2(rx * 0.45, ry * 0.92).rotated(rot), hc + Vector2(-rx * 0.45, ry * 0.92).rotated(rot)]), Color(0.25, 0.18, 0.14, 0.18))
	draw_colored_polygon(PackedVector2Array([hc + Vector2(-rx * 0.48, ry * 0.46).rotated(rot), hc + Vector2(-rx * 0.08, ry * 0.33).rotated(rot),
		hc + Vector2(rx * 0.08, ry * 0.33).rotated(rot), hc + Vector2(rx * 0.48, ry * 0.46).rotated(rot),
		hc + Vector2(rx * 0.10, ry * 0.43).rotated(rot), hc + Vector2(-rx * 0.10, ry * 0.43).rotated(rot)]), Color(0.20, 0.13, 0.09))
	draw_line(hc + Vector2(-rx * 0.20, ry * 0.58).rotated(rot), hc + Vector2(rx * 0.22, ry * 0.56).rotated(rot), Color(0.35, 0.15, 0.13, 0.8), u * 0.025)
	# the flat cap, its peak forward
	var cap: PackedVector2Array = PackedVector2Array()
	for k in 15:
		var a2: float = PI * 1.02 + PI * 0.96 * float(k) / 14.0
		cap.append(hc + Vector2(cos(a2) * rx * 1.12, sin(a2) * ry * 0.72 - ry * 0.32).rotated(rot))
	_shade_poly(cap, CAP, light, reach, 0.5)
	_shade_poly(PackedVector2Array([hc + Vector2(-rx * 1.05, -ry * 0.36).rotated(rot), hc + Vector2(rx * 1.05, -ry * 0.36).rotated(rot),
		hc + Vector2(rx * 0.95, -ry * 0.24).rotated(rot), hc + Vector2(-rx * 0.95, -ry * 0.24).rotated(rot)]), CAP.darkened(0.35), light, reach)
	draw_line(hc + Vector2(-rx * 0.2, -ry * 1.02).rotated(rot), hc + Vector2(rx * 0.1, -ry * 0.40).rotated(rot), Color(0, 0, 0, 0.18), u * 0.02)

# Two bones from the shoulder to the hand, the elbow bending outward. A rolled shirt sleeve to the
# elbow, a bare forearm, and the hand cupped over the cup's top.
func _draw_arm(sh: Vector2, hand: Vector2, side: float) -> void:
	var u: float = hs
	# seen from the front, an arm reaching forward to the table is FORESHORTENED: drawn at its full
	# length, the elbows had to stick out like wings to make up the distance
	var l1: float = u * 1.00
	var l2: float = u * 0.92
	var d: float = clampf(sh.distance_to(hand), 0.01, l1 + l2 - 0.5)
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
	_limb(sh, elbow, u * 0.15, u * 0.115, SHIRT.darkened(0.06), light)
	draw_circle(elbow, u * 0.105, SHIRT.darkened(0.28))
	var wrist: Vector2 = hand + (elbow - hand).normalized() * u * 0.16
	_limb(elbow, wrist, u * 0.095, u * 0.07, SKIN.darkened(0.05), light, 0.75)
	_shade_poly(_oval(hand + Vector2(0, -u * 0.02), u * 0.19, u * 0.12), SKIN, light, u * 4.0, 0.78)
	for f in 4:
		var fx: float = hand.x - u * 0.13 + u * 0.085 * float(f)
		_limb(Vector2(fx, hand.y), Vector2(fx + side * u * 0.01, hand.y + u * 0.11), u * 0.035, u * 0.030, SKIN.darkened(0.08), light, 0.75)

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
	draw_line(Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y), Color(0.55, 0.75, 0.55, 0.5), 2.0)
	# the cloth down the front: soft folds, shaded from the lantern, a gold fringe
	var sk: Rect2 = Rect2(r.position.x, r.end.y, r.size.x, skirt_h)
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
	var r: float = cup_w * 0.18
	draw_colored_polygon(_oval(at + Vector2(r * 0.2, 0), r * 1.1, r * 0.3), Color(0, 0, 0, 0.4))
	for k in 6:
		var f: float = 1.0 - float(k) / 6.0
		draw_circle(at - Vector2(r * 0.25 * (1.0 - f), r + r * 0.25 * (1.0 - f)), r * f,
			BALL_COLOR.darkened(0.45).lerp(BALL_COLOR.lightened(0.15), 1.0 - f))
	draw_circle(at - Vector2(r * 0.40, r * 1.42), r * 0.18, Color(1, 0.95, 0.9, 0.8))
