extends "res://scripts/menu_poster.gd"

# DINO N-BACK'S OPENING POSTER (main.gd menu_backdrop(); see scripts/menu_poster.gd): a TRAIL of the game's
# own cards (the shared zig-framed card) winding back into the distance along a trail through a valley at sunset --
# the newest large at the front, each one before it smaller and dimmer, further along the trail. Every few
# seconds a new card arrives at the front and the whole trail steps back one place; and when the new card
# is the same as the one N back, a golden thread of light joins the two, both glowing -- "is this the card
# from N back?". Made up, never the board.

const CARD: GDScript = preload("res://shared/scripts/card.gd")
const N_BACK: int = 2
const STEP: float = 1.1          # a card every 1.1 s (2.6 and then 1.6 were "too long" a pause, the user)
const SHOWN: int = 6
# the stream of pictures; where a card repeats the one two before it, the thread shows
const STREAM: Array = [3, 14, 3, 21, 8, 21, 11, 27, 11, 19, 5, 19]

var _layer: Node2D = null
var _cards: Array = []          # one node per slot, re-dressed as the trail steps
var _fx: Control = null
var _under: Control = null
var _dressed: int = -1

func _setup() -> void:
	# THE VALLEY (a still layer, baked): the trail of cards stands in a world now, not on a darkened backdrop
	# (the user saw this poster as sparse and dull)
	add_still(func(d: Control) -> void: _draw_valley(d))
	# the link between a matching pair is drawn UNDER the cards: it rises from behind one and sinks behind
	# the other, so it never lies across a picture
	_under = Control.new()
	_under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_under.set_anchors_preset(Control.PRESET_FULL_RECT)
	_under.draw.connect(func() -> void: _draw_link(_under))
	add_child(_under)
	_layer = Node2D.new()
	add_child(_layer)
	for k in SHOWN + 1:
		var c: Node2D = CARD.new()
		_layer.add_child(c)
		c.call("set_frame", 8, 8)
		_cards.append(c)
	_fx = Control.new()
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx.draw.connect(func() -> void: _draw_fx(_fx))
	add_child(_fx)

# the stream read from its third card, so the very first beat is a match and the thread shows at once
func _seq(i: int) -> int:
	return int(STREAM[posmod(i + 1, STREAM.size())])

func _tex(n: int) -> Texture2D:
	var p: String = "res://art/dinos/dino%d.jpg" % n
	return load(p) if ResourceLoader.exists(p) else null

# a card's width at the front: a share of the screen's width, and no more than the band's height allows (a desktop's
# short band made them crowd each other)
func _card_w() -> float:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	var top: float = 240.0 if mobile else 160.0
	return minf(full.x * 0.19, (bottom - top) * 0.30)

# a place along the trail: 0 the front, 1 one back, ... (fractions between), on screen
func _trail(pos: float) -> Dictionary:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	var top: float = 240.0 if mobile else 160.0
	var u: float = pos / float(SHOWN)
	var depth: float = pow(0.72, pos)                    # each card back is 72% the size of the one in front
	# an S across the screen: the front at the lower left, round to the right, back toward the left far off
	var x: float = full.x * (0.5 + 0.27 * sin(pos * 0.95 - 0.9))
	var front_y: float = bottom - _card_w() * 1.42 * 0.75
	var y: float = lerpf(front_y, top + 40.0, 1.0 - pow(1.0 - u, 1.8))
	return {"p": Vector2(x, y), "s": depth, "a": clampf(1.0 - u * 0.85, 0.0, 1.0)}

func _tick(_delta: float) -> void:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var n: int = int(t / STEP)
	var u: float = fmod(t, STEP) / STEP
	var shift: float = smoothstep(0.0, 0.40, u)        # the trail steps back in the first part of a beat
	var w: float = _card_w()
	for k in _cards.size():
		var c: Node2D = _cards[k]
		var idx: int = n - k + 1                           # the picture this slot shows
		if _dressed != n:
			c.call("setup", _tex(_seq(idx)), Color(1, 1, 1))
			c.call("set_width", w)
		var pos: float = float(k) - 1.0 + shift          # slot 0 is the arriving card
		var tr_: Dictionary = _trail(maxf(pos, 0.0))
		var arrive: float = clampf(pos + 1.0, 0.0, 1.0)  # the newest slides in from below
		var sc: float = float(tr_["s"])
		var half_h: float = float(c.call("card_height")) * 0.5 * sc
		c.position = Vector2(tr_["p"]) + Vector2(0.0, 140.0 * (1.0 - arrive)) - Vector2(0.0, half_h)
		c.scale = Vector2.ONE * sc
		c.rotation = sin(float(idx) * 1.7) * 0.10
		c.modulate = Color(1, 1, 1, float(tr_["a"]) * arrive).lerp(Color(0.7, 0.7, 0.75, float(tr_["a"]) * arrive), clampf(pos * 0.3, 0.0, 1.0))
	if _dressed != n:
		_dressed = n
		# the nearest in front
		for k in _cards.size():
			_layer.move_child(_cards[k], _cards.size() - 1 - k)
	_fx.queue_redraw()
	_under.queue_redraw()

# the vignette over everything (the link is _draw_link's, under the cards)
func _draw_fx(d: Control) -> void:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	for side in [0.0, 1.0]:
		var x0: float = side * full.x
		var x1: float = x0 + (full.x * 0.22 if side == 0.0 else -full.x * 0.22)
		d.draw_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(x1, 0), Vector2(x1, full.y), Vector2(x0, full.y)]),
			PackedColorArray([Color(0, 0, 0, 0.45), Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.45)]))

# THE LINK, when the front card is the same as the one N back: a luminous arc bowing out to the side between
# them -- a wide soft glow, a bright fine core, both tapering to nothing at the ends, sparkles running along
# it -- fading in as the new card settles and out before the next (the user: the link was the right idea,
# drawn badly as a flat line; a gold frame round the two instead was "super ugly")
func _draw_link(d: Control) -> void:
	# each card on its little wooden post, planted at the trail's edge (drawn under the card)
	for k in _cards.size():
		var c: Node2D = _cards[k]
		if c.modulate.a <= 0.02:
			continue
		var h: float = float(c.call("card_height")) * c.scale.y
		var foot: Vector2 = c.position + Vector2(0.0, h).rotated(c.rotation)
		var post_l: float = 26.0 * c.scale.y
		var pw: float = maxf(2.0, 7.0 * c.scale.y)
		d.draw_set_transform(foot + Vector2(0.0, post_l), 0.0, Vector2(1.0, 0.3))
		d.draw_circle(Vector2.ZERO, pw * 2.2, Color(0, 0, 0, 0.35 * c.modulate.a))
		d.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		d.draw_rect(Rect2(foot + Vector2(-pw * 0.5, -h * 0.4), Vector2(pw, post_l + h * 0.4)), Color(0.36, 0.24, 0.14, c.modulate.a))
		d.draw_rect(Rect2(foot + Vector2(-pw * 0.5, -h * 0.4), Vector2(pw * 0.35, post_l + h * 0.4)), Color(0.50, 0.36, 0.22, c.modulate.a))
	var n: int = int(t / STEP)
	var u: float = fmod(t, STEP) / STEP
	var front_idx: int = n + 1
	var back_idx: int = front_idx - N_BACK
	if _seq(front_idx) != _seq(back_idx):
		return
	var a: float = smoothstep(0.30, 0.50, u) * (1.0 - smoothstep(0.88, 1.0, u))
	if a <= 0.0:
		return
	var c0: Node2D = _cards[0]
	var c1: Node2D = _cards[N_BACK]
	var p0: Vector2 = c0.position + Vector2(0.0, float(c0.call("card_height")) * c0.scale.y * 0.5).rotated(c0.rotation)
	var p1: Vector2 = c1.position + Vector2(0.0, float(c1.call("card_height")) * c1.scale.y * 0.5).rotated(c1.rotation)
	var side: Vector2 = (p1 - p0).orthogonal().normalized()
	if side.x > 0.0:
		side = -side
	var ctrl: Vector2 = (p0 + p1) * 0.5 + side * p0.distance_to(p1) * 0.45
	var pts: Array = []
	var n_pts: int = 40
	for k in n_pts + 1:
		var f: float = float(k) / float(n_pts)
		pts.append(p0.lerp(ctrl, f).lerp(ctrl.lerp(p1, f), f))
	# the glow, then the core: each a ribbon whose width swells in the middle and tapers to the ends
	for layer_i in 4:
		var w: float = [26.0, 15.0, 7.0, 2.5][layer_i]
		var col: Color = [Color(1.0, 0.86, 0.55, 0.06), Color(1.0, 0.88, 0.60, 0.10), Color(1.0, 0.92, 0.72, 0.30), Color(1.0, 1.0, 0.95, 0.95)][layer_i]
		for k in n_pts:
			var f2: float = (float(k) + 0.5) / float(n_pts)
			var taper: float = sin(f2 * PI)
			d.draw_line(pts[k], pts[k + 1], Color(col, col.a * a), maxf(0.5, w * taper), true)
	# sparkles running along it, both ways
	for k in 5:
		var f3: float = fmod(t * 0.45 + float(k) / 5.0, 1.0)
		var dir_f: float = f3 if k % 2 == 0 else 1.0 - f3
		var sp: Vector2 = pts[int(dir_f * float(n_pts))]
		var tw: float = sin(f3 * PI)
		for g in 4:
			d.draw_circle(sp, (9.0 - 2.0 * float(g)) * tw, Color(1.0, 0.95, 0.80, 0.10 * a))
		d.draw_circle(sp, 2.0 * tw, Color(1, 1, 1, a))

# THE VALLEY at sunset: a warm sky with the low sun, three ranges of hazy hills, a smoking volcano, a long-necked
# dinosaur on the far ridge, palms and cycads, the grassy floor, and the dirt trail winding back along the cards' way,
# ferns framing the foot
func _draw_valley(d: Control) -> void:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	var far_p: Vector2 = Vector2(_trail(float(SHOWN))["p"])
	var horizon: float = far_p.y + 6.0
	# the sky
	var bands: Array = [[0.0, Color(0.20, 0.12, 0.30)], [0.5, Color(0.60, 0.28, 0.30)], [0.85, Color(0.98, 0.58, 0.30)], [1.0, Color(1.0, 0.82, 0.50)]]
	for k in bands.size() - 1:
		var y0: float = horizon * float(bands[k][0])
		var y1: float = horizon * float(bands[k + 1][0])
		d.draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(full.x, y0), Vector2(full.x, y1), Vector2(0, y1)]),
			PackedColorArray([bands[k][1], bands[k][1], bands[k + 1][1], bands[k + 1][1]]))
	var sun: Vector2 = Vector2(full.x * 0.30, horizon - 26.0)
	for g in 14:
		d.draw_circle(sun, 150.0 - float(g) * 10.0, Color(1.0, 0.80, 0.45, 0.035))
	d.draw_circle(sun, 30.0, Color(1.0, 0.92, 0.70))
	# the volcano at the right, its smoke leaning away, a glow at its mouth
	var vb: float = horizon + 6.0
	var vx: float = full.x * 0.84
	d.draw_colored_polygon(PackedVector2Array([Vector2(vx - 150.0, vb), Vector2(vx - 22.0, vb - 104.0), Vector2(vx + 18.0, vb - 104.0), Vector2(vx + 160.0, vb)]), Color(0.32, 0.18, 0.22))
	d.draw_colored_polygon(PackedVector2Array([Vector2(vx - 22.0, vb - 104.0), Vector2(vx + 18.0, vb - 104.0), Vector2(vx + 8.0, vb - 94.0), Vector2(vx - 12.0, vb - 95.0)]), Color(1.0, 0.45, 0.20, 0.8))
	for k2 in 9:
		var su: float = float(k2) / 8.0
		d.draw_circle(Vector2(vx - 2.0 + su * su * 80.0, vb - 112.0 - su * 70.0), 10.0 + su * 20.0, Color(0.40, 0.30, 0.34, 0.45 * (1.0 - su * 0.6)))
	# three ranges of hills, nearer ones darker and greener
	for r in 3:
		var col: Color = [Color(0.48, 0.30, 0.36), Color(0.30, 0.26, 0.24), Color(0.18, 0.22, 0.14)][r]
		var base_y: float = horizon + float(r) * 18.0
		var pts: PackedVector2Array = PackedVector2Array([Vector2(0.0, full.y)])
		for k3 in 33:
			var x: float = full.x * float(k3) / 32.0
			pts.append(Vector2(x, base_y - (20.0 + 14.0 * float(2 - r)) * (0.5 + 0.5 * sin(float(k3) * (0.45 + 0.2 * float(r)) + float(r) * 2.0))))
		pts.append(Vector2(full.x, full.y))
		d.draw_colored_polygon(pts, col)
	# a long-necked dinosaur on the far ridge, grazing, in silhouette
	var dn: Vector2 = Vector2(full.x * 0.58, horizon + 4.0)
	var dk: Color = Color(0.22, 0.14, 0.18)
	d.draw_set_transform(dn + Vector2(0.0, -14.0), 0.0, Vector2(1.6, 0.8))
	d.draw_circle(Vector2.ZERO, 16.0, dk)
	d.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var neck: PackedVector2Array = PackedVector2Array()
	for k4 in 9:
		var nu: float = float(k4) / 8.0
		neck.append(dn + Vector2(16.0 + nu * 40.0, -18.0 - sin(nu * 2.2) * 46.0))
	d.draw_polyline(neck, dk, 6.0, true)
	d.draw_circle(neck[8] + Vector2(4.0, 2.0), 5.0, dk)
	d.draw_polyline(PackedVector2Array([dn + Vector2(-24.0, -12.0), dn + Vector2(-60.0, -4.0), dn + Vector2(-80.0, 0.0)]), dk, 4.0, true)
	for lx in [-14.0, -4.0, 10.0, 20.0]:
		d.draw_line(dn + Vector2(lx, -8.0), dn + Vector2(lx, 4.0), dk, 5.0)
	# the valley floor, darkening toward you
	var floor_top: float = horizon + 40.0
	d.draw_polygon(PackedVector2Array([Vector2(0, floor_top), Vector2(full.x, floor_top), Vector2(full.x, full.y), Vector2(0, full.y)]),
		PackedColorArray([Color(0.26, 0.30, 0.14), Color(0.26, 0.30, 0.14), Color(0.10, 0.13, 0.06), Color(0.10, 0.13, 0.06)]))
	for k5 in 700:
		var gx: float = h01(k5 + 50) * full.x
		var gy: float = floor_top + h01(k5 + 60) * (full.y - floor_top)
		var depth: float = (gy - floor_top) / maxf(1.0, full.y - floor_top)
		d.draw_line(Vector2(gx, gy), Vector2(gx + (h01(k5 + 70) - 0.5) * 6.0, gy - 3.0 - 12.0 * depth), Color(0.36, 0.44, 0.18, 0.35), 1.0)
	# THE TRAIL along the cards' way: one smooth strip from far to near, wider as it comes, a darker verge, a few
	# stones (drawn as overlapping ovals it read as a caterpillar)
	var steps: int = 48
	var left: PackedVector2Array = PackedVector2Array()
	var right: PackedVector2Array = PackedVector2Array()
	var left_v: PackedVector2Array = PackedVector2Array()
	var right_v: PackedVector2Array = PackedVector2Array()
	var wpx: float = _card_w()
	for k6 in steps:
		var pos: float = float(SHOWN) * (1.0 - float(k6) / float(steps - 1))
		var tr_: Dictionary = _trail(pos)
		var sc: float = float(tr_["s"])
		var gp: Vector2 = Vector2(tr_["p"]) + Vector2(0.0, wpx * 0.68 * sc + 26.0 * sc)
		var rw: float = 64.0 * sc + 5.0
		left.append(gp - Vector2(rw, 0.0))
		right.append(gp + Vector2(rw, 0.0))
		left_v.append(gp - Vector2(rw + 3.0 + 4.0 * sc, 0.0))
		right_v.append(gp + Vector2(rw + 3.0 + 4.0 * sc, 0.0))
		if k6 % 6 == 3:
			d.set_meta("stone_%d" % k6, gp + Vector2((h01(k6) - 0.5) * rw * 1.4, 0.0))
	for pair in [[left_v, right_v, Color(0.26, 0.20, 0.12)], [left, right, Color(0.60, 0.47, 0.30)]]:
		var l: PackedVector2Array = pair[0]
		var r: PackedVector2Array = pair[1]
		# as quads, segment by segment (the strip bends, so one polygon could fold over itself)
		for k7 in steps - 1:
			d.draw_colored_polygon(PackedVector2Array([l[k7], l[k7 + 1], r[k7 + 1], r[k7]]), pair[2])
	for k8 in steps:
		if d.has_meta("stone_%d" % k8):
			var sp: Vector2 = d.get_meta("stone_%d" % k8)
			var ss: float = float(_trail(float(SHOWN) * (1.0 - float(k8) / float(steps - 1)))["s"])
			d.draw_circle(sp, 3.0 * ss + 1.0, Color(0.50, 0.46, 0.42))
	# palms and cycads on the slopes, smaller far off
	for k9 in 7:
		var px: float = full.x * (0.06 + 0.88 * h01(k9 + 80))
		var py: float = floor_top + (bottom - floor_top) * (0.10 + 0.35 * h01(k9 + 90))
		var ps: float = 0.4 + 0.8 * (py - floor_top) / maxf(1.0, bottom - floor_top)
		var trunk_top: Vector2 = Vector2(px + 10.0 * ps, py - 90.0 * ps)
		d.draw_line(Vector2(px, py), trunk_top, Color(0.24, 0.16, 0.10), 6.0 * ps)
		for f in 7:
			var fa: float = -PI * 0.5 + (float(f) - 3.0) * 0.48
			var tip: Vector2 = trunk_top + Vector2.from_angle(fa) * 52.0 * ps + Vector2(0.0, 18.0 * ps * absf(float(f) - 3.0) / 3.0)
			d.draw_line(trunk_top, trunk_top.lerp(tip, 0.5) + Vector2(0.0, -6.0 * ps), Color(0.16, 0.30, 0.12), 5.0 * ps)
			d.draw_line(trunk_top.lerp(tip, 0.5) + Vector2(0.0, -6.0 * ps), tip, Color(0.16, 0.30, 0.12), 3.5 * ps)
	# FERNS at the foot, framing
	for k8 in 10:
		var side: float = -1.0 if k8 < 5 else 1.0
		var fx: float = (full.x * 0.06 if side < 0.0 else full.x * 0.94) + side * 30.0 * h01(k8 + 100) - side * float(k8 % 5) * 26.0
		var fy: float = bottom + 20.0
		var fl: float = 90.0 + 60.0 * h01(k8 + 110)
		var lean: float = -side * (0.35 + 0.4 * h01(k8 + 120))
		var stem_end: Vector2 = Vector2(fx, fy) + Vector2.from_angle(-PI * 0.5 + lean) * fl
		d.draw_line(Vector2(fx, fy), stem_end, Color(0.10, 0.22, 0.08), 3.0)
		for lf in 10:
			var lu: float = float(lf + 1) / 11.0
			var lp: Vector2 = Vector2(fx, fy).lerp(stem_end, lu)
			var ll: float = (1.0 - lu) * 26.0 + 6.0
			for sgn in [-1.0, 1.0]:
				d.draw_line(lp, lp + Vector2.from_angle(-PI * 0.5 + lean + sgn * 1.1) * ll, Color(0.14, 0.30, 0.10), 2.4)

func _paint_top(_full: Vector2, _bottom: float) -> void:
	title("Dino N-Back", "Does this card match the one N cards back?", Color(0.66, 0.92, 0.36), Color(0.08, 0.14, 0.04),
		Color(0.4, 0.8, 0.2, 0.25))
