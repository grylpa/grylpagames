extends "res://scripts/menu_poster.gd"

# STORM'S OPENING POSTER (main.gd menu_backdrop(); see scripts/menu_poster.gd): the house at night in the
# storm -- the game is keeping it dry. Richer than the first version (the user: "a perfect concept but too
# plain now"), in depth from back to front:
#   the sky       storm blue, layered clouds drifting (their undersides catching the flashes), a far curtain
#                 of fainter rain, rolling hills on the horizon
#   the house     two storeys, lit on its left by the porch lamp and in shade on its right, a shingled roof
#                 with a gutter overflowing in a line of drips, a round attic window, curtained windows lit
#                 warm with a figure passing behind one, a loose shutter swinging in the wind (eased), a
#                 porch on posts with steps, a downspout gushing into a bucket, the chimney's smoke torn
#                 sideways
#   the yard      a bending tree, a picket fence, stepping stones to the porch, the wet ground holding the
#                 windows' reflections, puddles rippling, rain splashing
#   the weather   slanting rain in two depths, leaves blowing across, and every few seconds lightning: a
#                 forked bolt behind the roof, the whole scene whitened for a moment
# "STORM" in storm-blue light that goes white in a flash. Made up, never the board.

const ACCENT: Color = Color(0.976, 0.792, 0.353)
const WARM: Color = Color(1.0, 0.80, 0.44)
const NEAR_DROPS: int = 150
const FAR_DROPS: int = 110
const LEAVES: int = 9

var _near: Array = []
var _far: Array = []
var _bolt: Array = []          # PackedVector2Array: the main stroke, then branches
var _bolt_at: float = -10.0
var _next_bolt: float = 1.4
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _setup() -> void:
	_rng.seed = 7
	for _i in NEAR_DROPS:
		_near.append([_rng.randf(), _rng.randf(), _rng.randf_range(0.9, 1.4), _rng.randf_range(0.7, 1.2)])
	for _i in FAR_DROPS:
		_far.append([_rng.randf(), _rng.randf(), _rng.randf_range(0.5, 0.8), _rng.randf_range(0.4, 0.7)])

func _tick(_delta: float) -> void:
	if t >= _next_bolt:
		_bolt_at = t
		_next_bolt = t + _rng.randf_range(4.5, 8.0)
		_make_bolt()

func _flash() -> float:
	var u: float = t - _bolt_at
	if u < 0.0 or u > 0.7:
		return 0.0
	return maxf(exp(-u * 16.0), 0.55 * exp(-absf(u - 0.17) * 20.0))

func _make_bolt() -> void:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var x: float = full.x * _rng.randf_range(0.15, 0.85)
	var y: float = full.y * 0.08
	var main: PackedVector2Array = PackedVector2Array([Vector2(x, y)])
	var end_y: float = _ground_y() - full.y * 0.16
	while y < end_y:
		y += _rng.randf_range(16.0, 30.0)
		x += _rng.randf_range(-22.0, 22.0)
		main.append(Vector2(x, y))
	_bolt = [main]
	for b in 3:
		var at: int = _rng.randi_range(2, maxi(3, main.size() - 3))
		var p: Vector2 = main[mini(at, main.size() - 1)]
		var br: PackedVector2Array = PackedVector2Array([p])
		var dirx: float = -1.0 if _rng.randf() < 0.5 else 1.0
		for _s in _rng.randi_range(3, 6):
			p += Vector2(dirx * _rng.randf_range(8.0, 20.0), _rng.randf_range(10.0, 22.0))
			br.append(p)
		_bolt.append(br)

func _ground_y() -> float:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	return bottom - (40.0 if mobile else 20.0)

# the wind: gusting, the same for everything it moves
func _wind() -> float:
	return 0.6 + 0.4 * sin(t * 0.7) * sin(t * 0.31 + 1.0)

func _paint(full: Vector2, _bottom: float) -> void:
	var fl: float = _flash()
	var ground: float = _ground_y()
	var horizon: float = ground - (100.0 if mobile else 60.0)
	# THE SKY
	var top_c: Color = Color(0.03, 0.05, 0.11).lerp(Color(0.55, 0.62, 0.80), fl * 0.6)
	var hor_c: Color = Color(0.12, 0.17, 0.27).lerp(Color(0.78, 0.82, 0.94), fl * 0.6)
	vgrad(Rect2(0.0, 0.0, full.x, horizon + 4.0), top_c, hor_c)
	# clouds in three layers, back to front, drifting at their own speeds; lit underneath in a flash
	for cl in 3:
		var speed: float = 5.0 + 5.0 * float(cl)
		var cy0: float = full.y * (0.04 + 0.06 * float(cl))
		var shade: Color = Color(0.06, 0.08, 0.13).lerp(Color(0.10, 0.12, 0.18), float(cl) * 0.5)
		for k in 6:
			var cx: float = fmod(float(k) * 180.0 + float(cl) * 60.0 + t * speed, full.x + 360.0) - 180.0
			var cy: float = cy0 + 30.0 * h01(k + cl * 10)
			for j in 5:
				var pc: Vector2 = Vector2(cx + float(j) * 42.0 - 84.0, cy + 14.0 * sin(float(j * 3 + k)))
				var rr: float = 56.0 - float(j % 2) * 14.0 + 10.0 * h01(k * 5 + j)
				# soft: each puff three faint discs, so the clouds' edges blur rather than outline circles
				for g in 3:
					cv.draw_circle(pc, rr * (1.15 - 0.2 * float(g)), Color(shade, 0.22).lerp(Color(0.62, 0.68, 0.84, 0.28), fl * 0.55))
				cv.draw_circle(pc + Vector2(0.0, rr * 0.45), rr * 0.7, Color(0.30, 0.36, 0.52, 0.05 + 0.25 * fl))
	# the bolt, behind everything on the ground, with its branches
	if fl > 0.05:
		for k in _bolt.size():
			var line: PackedVector2Array = _bolt[k]
			var w: float = 3.0 if k == 0 else 1.6
			cv.draw_polyline(line, Color(0.70, 0.82, 1.0, 0.30 * fl), w * 4.0, true)
			cv.draw_polyline(line, Color(1.0, 1.0, 1.0, fl), w, true)
	# the far rain, a fainter curtain
	_rain(_far, full, horizon + 30.0, Color(0.60, 0.70, 0.88, 0.22), 16.0, 600.0)
	# the hills on the horizon
	var hills: PackedVector2Array = PackedVector2Array([Vector2(0.0, full.y)])
	for k in 25:
		var x: float = full.x * float(k) / 24.0
		hills.append(Vector2(x, horizon - 18.0 - 26.0 * sin(float(k) * 0.55 + 1.0) - 10.0 * sin(float(k) * 1.7)))
	hills.append(Vector2(full.x, full.y))
	cv.draw_colored_polygon(hills, Color(0.05, 0.07, 0.10).lerp(Color(0.35, 0.40, 0.48), fl * 0.5))
	# THE GROUND: wet earth up to the horizon, the yard in front
	vgrad(Rect2(0.0, horizon, full.x, full.y - horizon), Color(0.06, 0.07, 0.09).lerp(Color(0.40, 0.42, 0.48), fl * 0.4),
		Color(0.03, 0.04, 0.05).lerp(Color(0.30, 0.32, 0.36), fl * 0.4))
	_tree(full, ground, fl)
	_house(full, ground, fl)
	_yard(full, ground, fl)
	_rain(_near, full, ground + 40.0, Color(0.72, 0.82, 0.96, 0.42), 28.0, 950.0)
	_leaves(full, ground)

func _rain(drops: Array, full: Vector2, floor_y: float, col: Color, length: float, speed: float) -> void:
	var slant: Vector2 = Vector2(-0.22 - 0.12 * _wind(), 1.0).normalized()
	for d in drops:
		var y: float = fmod(float(d[1]) * floor_y + t * speed * float(d[2]), floor_y + 60.0) - 40.0
		var x: float = float(d[0]) * (full.x + 160.0) + y * slant.x / slant.y + 60.0
		cv.draw_line(Vector2(x, y), Vector2(x, y) + slant * length * float(d[3]), col, 1.5)

func _tree(full: Vector2, ground: float, fl: float) -> void:
	var sway: float = 0.08 * _wind() + 0.04 * sin(t * 2.9)
	var base: Vector2 = Vector2(full.x * 0.92, ground + 6.0)
	var trunk_h: float = (ground - full.y * 0.26) * 0.78
	var tip: Vector2 = base + Vector2(trunk_h * (0.06 - sway), -trunk_h)
	var tc: Color = Color(0.05, 0.05, 0.06).lerp(Color(0.32, 0.34, 0.40), fl * 0.5)
	cv.draw_polyline(PackedVector2Array([base, base.lerp(tip, 0.5) + Vector2(10.0, 0.0), tip]), tc, 16.0, true)
	for b in 6:
		var at: Vector2 = base.lerp(tip, 0.40 + 0.11 * float(b))
		var dirx: float = -1.0 if b % 2 == 0 else 1.0
		var reach: float = 70.0 - float(b) * 9.0
		var end: Vector2 = at + Vector2(dirx * reach - sway * 160.0, -42.0 + float(b) * 4.0)
		cv.draw_line(at, end, tc, 6.0 - float(b) * 0.7, true)
		cv.draw_line(end, end + Vector2(dirx * 20.0 - sway * 60.0, -14.0), tc, 2.5, true)
	for k in 12:
		var leaf: Vector2 = tip + Vector2(cos(float(k) * 0.9) * 70.0 - sway * 180.0, sin(float(k) * 1.4) * 44.0 + 34.0)
		cv.draw_circle(leaf, 30.0 + 8.0 * h01(k), Color(0.04, 0.09, 0.07, 0.92).lerp(Color(0.30, 0.40, 0.36, 0.92), fl * 0.5))

func _house(full: Vector2, ground: float, fl: float) -> void:
	# THE HOUSE IS THE HERO: sized from the room between the name and the ground (from the strip below the
	# horizon it came out a squat bungalow under an empty sky)
	var room: float = ground - (250.0 if mobile else 160.0)
	var hh: float = room * 0.52
	var hw: float = minf(full.x * 0.62, hh * 1.45)
	var hx: float = full.x * 0.46 - hw * 0.5
	var wall: Rect2 = Rect2(hx, ground - hh, hw, hh)
	var lit_c: Color = Color(0.24, 0.20, 0.21).lerp(Color(0.62, 0.58, 0.62), fl * 0.5)
	var dark_c: Color = Color(0.13, 0.11, 0.13).lerp(Color(0.45, 0.42, 0.46), fl * 0.5)
	# the wall: lit on the left by the porch lamp, in shade toward the right
	cv.draw_polygon(PackedVector2Array([wall.position, Vector2(wall.end.x, wall.position.y), wall.end, Vector2(wall.position.x, wall.end.y)]),
		PackedColorArray([lit_c, dark_c, dark_c, lit_c]))
	var sy: float = wall.position.y + 12.0
	while sy < wall.end.y:
		cv.draw_line(Vector2(wall.position.x, sy), Vector2(wall.end.x, sy), Color(0, 0, 0, 0.22), 1.5)
		cv.draw_line(Vector2(wall.position.x, sy + 1.5), Vector2(wall.end.x, sy + 1.5), Color(1, 1, 1, 0.03), 1.0)
		sy += 15.0
	cv.draw_rect(Rect2(wall.position.x, wall.position.y, 10.0, hh), Color(0.30, 0.27, 0.28))
	cv.draw_rect(Rect2(wall.end.x - 10.0, wall.position.y, 10.0, hh), Color(0.10, 0.09, 0.10))
	# the roof
	var roof_h: float = hh * 0.55
	var eave_l: Vector2 = Vector2(wall.position.x - 30.0, wall.position.y + 6.0)
	var eave_r: Vector2 = Vector2(wall.end.x + 30.0, wall.position.y + 6.0)
	var ridge: Vector2 = Vector2(wall.get_center().x, wall.position.y - roof_h)
	var roof: PackedVector2Array = PackedVector2Array([eave_l, ridge, eave_r])
	cv.draw_colored_polygon(roof, Color(0.20, 0.10, 0.09).lerp(Color(0.58, 0.44, 0.44), fl * 0.5))
	cv.draw_colored_polygon(PackedVector2Array([eave_l, ridge, Vector2(ridge.x, eave_l.y)]), Color(0.26, 0.13, 0.11, 0.6).lerp(Color(0.7, 0.55, 0.55, 0.6), fl * 0.5))
	var rows: int = 10
	for r in range(1, rows):
		var u: float = float(r) / float(rows)
		var y: float = lerpf(ridge.y, eave_l.y, u)
		var half: float = (eave_r.x - eave_l.x) * 0.5 * u
		cv.draw_line(Vector2(ridge.x - half, y), Vector2(ridge.x + half, y), Color(0.05, 0.02, 0.02, 0.6), 2.0)
		var step: float = 20.0
		var x0: float = ridge.x - half + fmod(float(r) * 10.0, step)
		while x0 < ridge.x + half - 4.0:
			cv.draw_line(Vector2(x0, y), Vector2(x0, y - roof_h / float(rows) * 0.9), Color(0.05, 0.02, 0.02, 0.35), 1.0)
			x0 += step
	if fl > 0.05:
		cv.draw_colored_polygon(roof, Color(0.85, 0.90, 1.0, 0.20 * fl))
	cv.draw_polyline(PackedVector2Array([eave_l, ridge, eave_r]), Color(0.07, 0.03, 0.03), 6.0, true)
	# the round attic window, lit
	var attic: Vector2 = Vector2(ridge.x, ridge.y + roof_h * 0.58)
	_soft_glow(attic, 34.0, Color(WARM, 0.18))
	cv.draw_circle(attic, 16.0, Color(0.10, 0.07, 0.06))
	cv.draw_circle(attic, 12.0, WARM)
	cv.draw_line(attic + Vector2(-12, 0), attic + Vector2(12, 0), Color(0.10, 0.07, 0.06), 2.5)
	cv.draw_line(attic + Vector2(0, -12), attic + Vector2(0, 12), Color(0.10, 0.07, 0.06), 2.5)
	# the chimney, and its smoke torn sideways by the wind
	var ch: Rect2 = Rect2(wall.end.x - hw * 0.25, wall.position.y - roof_h * 0.78, hw * 0.08, roof_h * 0.48)
	cv.draw_rect(ch, Color(0.30, 0.14, 0.10).lerp(Color(0.6, 0.45, 0.42), fl * 0.5))
	cv.draw_rect(Rect2(ch.position - Vector2(4.0, 6.0), Vector2(ch.size.x + 8.0, 8.0)), Color(0.22, 0.10, 0.08))
	for k in 7:
		var u: float = fmod(t * 0.35 + float(k) / 7.0, 1.0)
		var sp: Vector2 = Vector2(ch.get_center().x, ch.position.y) + Vector2(-u * 200.0 * _wind(), -u * 50.0 - 20.0 * u * u)
		for g in 3:
			cv.draw_circle(sp, (10.0 + 22.0 * u) * (1.0 - 0.25 * float(g)), Color(0.55, 0.58, 0.64, 0.08 * (1.0 - u)))
	# the gutter, overflowing in a line of drips along the eave
	cv.draw_line(eave_l + Vector2(0.0, 2.0), eave_r + Vector2(0.0, 2.0), Color(0.36, 0.40, 0.44), 6.0)
	for k in 12:
		var dx: float = lerpf(eave_l.x + 20.0, eave_r.x - 20.0, h01(k + 70))
		var u: float = fmod(t * (1.2 + h01(k) * 0.6) + h01(k + 3), 1.0)
		cv.draw_circle(Vector2(dx, eave_l.y + 6.0 + u * u * 70.0), 2.0, Color(0.75, 0.85, 1.0, 0.7 * (1.0 - u)))
	# the windows: upstairs two, downstairs one beside the door
	var ww: float = hw * 0.17
	var wh: float = hh * 0.24
	var wins: Array = [Rect2(wall.position.x + hw * 0.12, wall.position.y + hh * 0.10, ww, wh),
		Rect2(wall.position.x + hw * 0.71, wall.position.y + hh * 0.10, ww, wh),
		Rect2(wall.position.x + hw * 0.12, wall.position.y + hh * 0.56, ww, wh)]
	for k in wins.size():
		_window(wins[k], k == 1)
	# the loose shutter on the upstairs right window, swinging in the wind (eased: a sine)
	var sw_r: Rect2 = wins[1]
	var swing: float = 0.5 + 0.5 * sin(t * 1.6 + sin(t * 0.7))
	var open_w: float = sw_r.size.x * 0.55 * (0.25 + 0.75 * swing)
	var shutter_c: Color = Color(0.14, 0.24, 0.20).lerp(Color(0.5, 0.6, 0.55), fl * 0.5)
	cv.draw_colored_polygon(PackedVector2Array([Vector2(sw_r.end.x + 3.0, sw_r.position.y), Vector2(sw_r.end.x + 3.0 + open_w, sw_r.position.y + 4.0 * swing),
		Vector2(sw_r.end.x + 3.0 + open_w, sw_r.end.y - 4.0 * swing), Vector2(sw_r.end.x + 3.0, sw_r.end.y)]), shutter_c)
	cv.draw_rect(Rect2(sw_r.position.x - sw_r.size.x * 0.55 - 3.0, sw_r.position.y, sw_r.size.x * 0.55, sw_r.size.y), shutter_c)
	# THE PORCH: a roof on posts across the lower front, steps, the door, the lamp
	var porch_y: float = wall.position.y + hh * 0.46
	var porch: Rect2 = Rect2(wall.position.x + hw * 0.38, porch_y, hw * 0.64, 10.0)
	cv.draw_colored_polygon(PackedVector2Array([porch.position + Vector2(-10.0, 0.0), Vector2(porch.end.x + 14.0, porch.position.y),
		Vector2(porch.end.x + 6.0, porch.position.y - 22.0), porch.position + Vector2(-2.0, -22.0)]), Color(0.18, 0.09, 0.08).lerp(Color(0.55, 0.44, 0.44), fl * 0.5))
	cv.draw_line(porch.position + Vector2(-10.0, 0.0), Vector2(porch.end.x + 14.0, porch.position.y), Color(0.40, 0.36, 0.34), 4.0)
	for px in [porch.position.x + 6.0, porch.end.x]:
		cv.draw_rect(Rect2(px - 4.0, porch_y, 8.0, ground - porch_y), Color(0.55, 0.50, 0.46).lerp(Color(0.9, 0.88, 0.86), fl * 0.4))
	var door: Rect2 = Rect2(wall.position.x + hw * 0.52, wall.end.y - hh * 0.40, hw * 0.15, hh * 0.40)
	cv.draw_rect(door, Color(0.30, 0.15, 0.09))
	cv.draw_rect(Rect2(door.position + Vector2(door.size.x * 0.18, door.size.y * 0.12), Vector2(door.size.x * 0.64, door.size.y * 0.30)), Color(0.24, 0.12, 0.07))
	cv.draw_rect(door, Color(0.10, 0.06, 0.04), false, 3.0)
	cv.draw_circle(door.position + Vector2(door.size.x * 0.80, door.size.y * 0.56), 3.0, ACCENT)
	for s in 3:
		cv.draw_rect(Rect2(door.position.x - 14.0 - float(s) * 8.0, ground - 8.0 * float(s + 1), door.size.x + 28.0 + float(s) * 16.0, 8.0),
			Color(0.32, 0.30, 0.30).darkened(0.12 * float(s)))
	var lamp: Vector2 = Vector2(door.end.x + 22.0, door.position.y + 6.0)
	var fk: float = 0.88 + 0.12 * sin(t * 2.3) * sin(t * 0.9)
	_soft_glow(lamp, 90.0, Color(1.0, 0.78, 0.40, 0.26 * fk))
	cv.draw_rect(Rect2(lamp - Vector2(6, 9), Vector2(12, 18)), Color(1.0, 0.88, 0.58) * Color(fk, fk, fk, 1.0))
	cv.draw_rect(Rect2(lamp - Vector2(6, 9), Vector2(12, 18)), Color(0.10, 0.07, 0.06), false, 2.0)
	# the downspout down the left corner, gushing into a bucket
	var spout_x: float = wall.position.x + 4.0
	cv.draw_line(Vector2(spout_x, eave_l.y + 4.0), Vector2(spout_x, ground - 52.0), Color(0.40, 0.44, 0.48), 6.0)
	cv.draw_line(Vector2(spout_x, ground - 52.0), Vector2(spout_x - 18.0, ground - 44.0), Color(0.40, 0.44, 0.48), 6.0)
	var bucket: Rect2 = Rect2(spout_x - 46.0, ground - 36.0, 38.0, 36.0)
	for k in 6:
		var u: float = fmod(t * 2.6 + float(k) / 6.0, 1.0)
		cv.draw_circle(Vector2(spout_x - 22.0 - 6.0 * u, ground - 44.0 + u * 10.0), 3.2 - u, Color(0.78, 0.88, 1.0, 0.9))
	cv.draw_colored_polygon(PackedVector2Array([bucket.position, Vector2(bucket.end.x, bucket.position.y),
		Vector2(bucket.end.x - 5.0, bucket.end.y), Vector2(bucket.position.x + 5.0, bucket.end.y)]), Color(0.46, 0.52, 0.58))
	cv.draw_line(bucket.position, Vector2(bucket.end.x, bucket.position.y), Color(0.72, 0.78, 0.84), 3.0)
	ellipse(Vector2(bucket.get_center().x, bucket.position.y + 2.0), bucket.size.x * 0.42, 3.0, Color(0.55, 0.68, 0.85))

func _window(r: Rect2, figure: bool) -> void:
	_soft_glow(r.get_center(), r.size.x * 0.95, Color(WARM, 0.16))
	cv.draw_rect(r, WARM)
	cv.draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.4)), Color(1.0, 0.92, 0.66, 0.6))
	if figure:
		var px: float = r.position.x + r.size.x * (0.5 + 0.40 * sin(t * 0.45))
		cv.draw_circle(Vector2(px, r.position.y + r.size.y * 0.36), r.size.x * 0.12, Color(0.36, 0.22, 0.12, 0.65))
		cv.draw_rect(Rect2(px - r.size.x * 0.14, r.position.y + r.size.y * 0.48, r.size.x * 0.28, r.size.y * 0.52), Color(0.36, 0.22, 0.12, 0.65))
	# curtains drawn back
	cv.draw_colored_polygon(PackedVector2Array([r.position, r.position + Vector2(r.size.x * 0.24, 0.0), r.position + Vector2(r.size.x * 0.10, r.size.y)]), Color(0.62, 0.18, 0.16, 0.85))
	cv.draw_colored_polygon(PackedVector2Array([Vector2(r.end.x, r.position.y), Vector2(r.end.x - r.size.x * 0.24, r.position.y), Vector2(r.end.x - r.size.x * 0.10, r.end.y)]), Color(0.62, 0.18, 0.16, 0.85))
	cv.draw_rect(r, Color(0.92, 0.88, 0.80), false, 4.0)
	cv.draw_line(Vector2(r.get_center().x, r.position.y), Vector2(r.get_center().x, r.end.y), Color(0.92, 0.88, 0.80), 3.0)
	cv.draw_line(Vector2(r.position.x, r.get_center().y), Vector2(r.end.x, r.get_center().y), Color(0.92, 0.88, 0.80), 3.0)
	cv.draw_rect(Rect2(r.position.x - 6.0, r.end.y, r.size.x + 12.0, 6.0), Color(0.80, 0.76, 0.70))

# a glow with no visible rings: many very faint discs, each a little smaller
func _soft_glow(c: Vector2, radius: float, col: Color) -> void:
	var n: int = 16
	for k in n:
		var f: float = 1.0 - float(k) / float(n)
		cv.draw_circle(c, radius * f, Color(col, col.a / float(n) * 2.2))

func _yard(full: Vector2, ground: float, fl: float) -> void:
	# the wet ground's reflections of the lit windows: soft streaks straight down
	for x in [full.x * 0.26, full.x * 0.62]:
		for k in 5:
			var w: float = 14.0 - float(k) * 2.0
			cv.draw_rect(Rect2(x - w * 0.5, ground + 4.0 + float(k) * 6.0, w, 6.0), Color(WARM, 0.10 - 0.015 * float(k)))
	# stepping stones to the steps
	for k in 4:
		var u: float = float(k) / 3.0
		ellipse(Vector2(full.x * 0.53 - u * 30.0, ground + 12.0 + u * 30.0), 22.0 + u * 10.0, 6.0 + u * 3.0, Color(0.28, 0.28, 0.30).lerp(Color(0.6, 0.6, 0.64), fl * 0.4))
	# puddles rippling
	for k in 3:
		var pc: Vector2 = Vector2(full.x * (0.18 + 0.30 * float(k)), ground + 26.0 + float(k % 2) * 12.0)
		ellipse(pc, 56.0, 12.0, Color(0.18, 0.24, 0.34, 0.7).lerp(Color(0.7, 0.75, 0.9, 0.7), fl * 0.5))
		for j in 2:
			var u: float = fmod(t * 0.9 + float(k) * 0.37 + float(j) * 0.5, 1.0)
			cv.draw_set_transform(pc + Vector2(float(j) * 20.0 - 10.0, 0.0), 0.0, Vector2(1.0, 0.24))
			cv.draw_arc(Vector2.ZERO, 6.0 + u * 34.0, 0.0, TAU, 24, Color(0.78, 0.86, 1.0, 0.55 * (1.0 - u)), 2.0)
			cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# splashes where the rain lands
	for k in 18:
		var u: float = fmod(t * 2.2 + h01(k * 3), 1.0)
		var sp: Vector2 = Vector2(h01(k * 3 + 1) * full.x, ground + 8.0 + h01(k * 3 + 2) * 40.0)
		cv.draw_arc(sp, 2.0 + u * 6.0, PI, TAU, 8, Color(0.80, 0.88, 1.0, 0.5 * (1.0 - u)), 1.2)
	# the picket fence along the front, leaving the path open
	var fy: float = ground + 2.0
	var x: float = 0.0
	while x < full.x:
		if absf(x - full.x * 0.50) > 44.0:
			cv.draw_colored_polygon(PackedVector2Array([Vector2(x, fy), Vector2(x + 10.0, fy), Vector2(x + 10.0, fy - 34.0), Vector2(x + 5.0, fy - 41.0), Vector2(x, fy - 34.0)]),
				Color(0.42, 0.40, 0.40).lerp(Color(0.85, 0.85, 0.88), fl * 0.5))
		x += 22.0
	for ry in [fy - 10.0, fy - 26.0]:
		cv.draw_line(Vector2(0.0, ry), Vector2(full.x * 0.50 - 44.0, ry), Color(0.34, 0.32, 0.32), 4.0)
		cv.draw_line(Vector2(full.x * 0.50 + 44.0, ry), Vector2(full.x, ry), Color(0.34, 0.32, 0.32), 4.0)
	# grass along the fence, leaning with the wind
	var gx: float = 0.0
	var gk: int = 0
	while gx < full.x:
		var gh: float = 12.0 + float((gk * 37) % 11)
		var lean: float = 5.0 + 6.0 * _wind() + 2.0 * sin(t * 2.0 + gx * 0.05)
		cv.draw_line(Vector2(gx, ground + 30.0), Vector2(gx - lean, ground + 30.0 - gh), Color(0.08, 0.15, 0.10).lerp(Color(0.4, 0.5, 0.42), fl * 0.4), 2.0)
		gx += 6.0
		gk += 1

func _leaves(full: Vector2, ground: float) -> void:
	for k in LEAVES:
		var u: float = fmod(t * (0.12 + 0.06 * h01(k)) + h01(k + 40), 1.0)
		var p: Vector2 = Vector2(full.x * (1.1 - 1.3 * u), ground * (0.35 + 0.5 * h01(k + 80)) + sin(u * 9.0 + float(k)) * 30.0)
		var a: float = u * 18.0 + float(k)
		cv.draw_set_transform(p, a, Vector2(1.0, 0.45 + 0.4 * absf(sin(a))))
		cv.draw_circle(Vector2.ZERO, 5.0, Color(0.55, 0.42, 0.16, 0.85))
		cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _paint_top(_full: Vector2, _bottom: float) -> void:
	var fl: float = _flash()
	title("STORM", "Save your house from the storm", Color(0.80, 0.90, 1.0).lerp(Color.WHITE, fl), Color(0.02, 0.04, 0.10),
		Color(0.35, 0.55, 1.0, 0.18 + 0.35 * fl), null, 86, Color(0.88, 0.92, 1.0))
