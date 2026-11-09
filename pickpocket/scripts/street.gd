extends Node2D

# PICKPOCKET'S STREET at dusk, drawn once, seen from the hustler's table: across the road a row of
# shopfronts with their windows lit, striped awnings and painted signs, upper floors and a narrow
# sidewalk; then the road; then the near sidewalk the table stands on, with two street lamps on its
# far edge. Nothing in it moves; the people do.
#
# EVERY PERSON IS BEHIND THE TABLE, at the scale of their distance: the far lane small on the shops'
# sidewalk, the near lane larger, just behind the hustler. A lane in front of the table had people
# smaller than the hustler behind them, which made the whole scene read at the wrong size.
#
# `setup(w, top, shop_floor, road_top, road_bottom, bottom)` takes the rows the level lays out:
# `shop_floor` is where the far lane stands, `road_bottom` the near curb.

const SKY_TOP: Color = Color(0.13, 0.14, 0.28)
const SKY_LOW: Color = Color(0.46, 0.30, 0.42)
const WINDOW_LIT: Color = Color(1.00, 0.80, 0.48)
const WINDOW_DIM: Color = Color(0.22, 0.24, 0.34)
const PAVEMENT: Color = Color(0.34, 0.33, 0.36)
const ROAD: Color = Color(0.17, 0.17, 0.20)

const SHOPS: Array = [
	{"name": "BAKERY",  "wall": Color(0.62, 0.30, 0.24), "awning": Color(0.85, 0.25, 0.22), "trim": Color(0.95, 0.90, 0.80)},
	{"name": "BOOKS",   "wall": Color(0.28, 0.38, 0.40), "awning": Color(0.20, 0.45, 0.35), "trim": Color(0.92, 0.86, 0.66)},
	{"name": "FLOWERS", "wall": Color(0.70, 0.58, 0.40), "awning": Color(0.82, 0.42, 0.58), "trim": Color(0.98, 0.95, 0.90)},
	{"name": "CAFE",    "wall": Color(0.36, 0.28, 0.40), "awning": Color(0.20, 0.30, 0.55), "trim": Color(0.95, 0.85, 0.55)},
]

var _w: float = 680.0
var _top: float = 60.0
var _floor: float = 300.0
var _road_top: float = 340.0
var _road_bottom: float = 400.0
var _bottom: float = 744.0
var _seed: int = 7

func setup(w: float, top: float, shop_floor: float, road_top: float, road_bottom: float, bottom: float) -> void:
	_w = w
	_top = top
	_floor = shop_floor
	_road_top = road_top
	_road_bottom = road_bottom
	_bottom = bottom
	queue_redraw()

func _draw() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _seed
	# the dusk sky: one smooth gradient
	var sky_bottom: float = _top + (_floor - _top) * 0.45
	_vgrad(Rect2(0.0, _top - 80.0, _w, sky_bottom - _top + 80.0), SKY_TOP, SKY_LOW)

	# the facades: four shops, each a building of its own height
	var n: int = SHOPS.size()
	var bw: float = _w / float(n)
	var face_h: float = _floor - _top
	for i in n:
		var shop: Dictionary = SHOPS[i]
		var x0: float = bw * float(i)
		var roof: float = _top + face_h * (0.02 + 0.10 * float((i * 7 + 3) % 4) / 3.0)
		var wall: Color = (shop["wall"] as Color).darkened(0.18)
		# the wall: dark at the roofline, lit warm from the shopfronts and the lamps below
		_vgrad(Rect2(x0, roof, bw + 1.0, _floor - roof), wall.darkened(0.45), Color(minf(1.0, wall.r * 1.08), wall.g, wall.b * 0.92))
		# bricks: courses, staggered joints, each brick a shade of its own
		var course: float = maxf(5.0, face_h * 0.030)
		var brick_w: float = course * 2.6
		var y: float = roof + face_h * 0.05
		var row: int = 0
		while y < _floor - face_h * 0.45:
			var off: float = 0.0 if row % 2 == 0 else brick_w * 0.5
			var bx: float = x0 - off
			while bx < x0 + bw:
				var tone: float = rng.randf_range(-0.06, 0.06)
				var bl: float = maxf(bx, x0)
				var br: float = minf(bx + brick_w, x0 + bw)
				if br > bl + 1.0:
					draw_rect(Rect2(bl, y, br - bl - 1.0, course - 1.0), Color(1, 1, 1, tone) if tone > 0.0 else Color(0, 0, 0, -tone))
				bx += brick_w
			draw_line(Vector2(x0, y + course - 0.5), Vector2(x0 + bw, y + course - 0.5), Color(0, 0, 0, 0.12), 1.0)
			y += course
			row += 1
		# the cornice
		draw_rect(Rect2(x0 - 2.0, roof, bw + 4.0, face_h * 0.03), wall.lightened(0.10))
		draw_rect(Rect2(x0 - 2.0, roof, bw + 4.0, 1.5), wall.lightened(0.35))
		draw_rect(Rect2(x0, roof + face_h * 0.03, bw, face_h * 0.014), Color(0, 0, 0, 0.35))
		# upper-floor windows: two, some lit
		var shop_top: float = _floor - face_h * 0.44
		var win_w: float = bw * 0.24
		var win_h: float = minf(face_h * 0.16, (shop_top - roof) * 0.55)
		var win_y: float = roof + (shop_top - roof) * 0.30
		for k in 2:
			var wx: float = x0 + bw * (0.18 + 0.40 * float(k))
			var lit: bool = rng.randf() < 0.55
			draw_rect(Rect2(wx - 3.0, win_y - 3.0, win_w + 6.0, win_h + 6.0), wall.lightened(0.18))
			if lit:
				_vgrad(Rect2(wx, win_y, win_w, win_h), WINDOW_LIT.darkened(0.05), WINDOW_LIT.darkened(0.35))
				# curtains drawn to the sides
				_vgrad(Rect2(wx, win_y, win_w * 0.22, win_h), Color(0.55, 0.25, 0.20), Color(0.35, 0.15, 0.12))
				_vgrad(Rect2(wx + win_w * 0.78, win_y, win_w * 0.22, win_h), Color(0.55, 0.25, 0.20), Color(0.35, 0.15, 0.12))
			else:
				_vgrad(Rect2(wx, win_y, win_w, win_h), WINDOW_DIM.lightened(0.10), WINDOW_DIM.darkened(0.3))
				draw_line(Vector2(wx + win_w * 0.15, win_y + win_h * 0.9), Vector2(wx + win_w * 0.55, win_y + win_h * 0.1), Color(1, 1, 1, 0.07), 3.0)
			draw_line(Vector2(wx + win_w * 0.5, win_y), Vector2(wx + win_w * 0.5, win_y + win_h), wall.darkened(0.3), 2.0)
			draw_line(Vector2(wx, win_y + win_h * 0.5), Vector2(wx + win_w, win_y + win_h * 0.5), wall.darkened(0.3), 2.0)
			draw_rect(Rect2(wx - 5.0, win_y + win_h + 3.0, win_w + 10.0, 4.0), wall.lightened(0.3))

		# the shopfront: a sign board, an awning, a lit display window and a door
		var trim: Color = shop["trim"]
		var sign_h: float = face_h * 0.085
		var sign_y: float = shop_top
		draw_rect(Rect2(x0 + bw * 0.06, sign_y, bw * 0.88, sign_h), Color(0.10, 0.09, 0.10))
		draw_rect(Rect2(x0 + bw * 0.06, sign_y, bw * 0.88, sign_h), trim, false, 2.0)
		_sign_text(shop["name"], Vector2(x0 + bw * 0.5, sign_y + sign_h * 0.5), sign_h * 0.62, trim)
		var aw_y: float = sign_y + sign_h + 2.0
		var aw_h: float = face_h * 0.075
		_awning(Rect2(x0 + bw * 0.03, aw_y, bw * 0.94, aw_h), shop["awning"])
		var front_top: float = aw_y + aw_h
		var door_w: float = bw * 0.24
		var door_left: bool = i % 2 == 0
		var door_x: float = x0 + (bw * 0.10 if door_left else bw * 0.66)
		var win_x: float = x0 + (bw * 0.40 if door_left else bw * 0.08)
		var dw: float = bw * 0.54
		# the display window, lit from inside, with something on show
		draw_rect(Rect2(win_x - 3.0, front_top + 4.0, dw + 6.0, _floor - front_top - 10.0), trim.darkened(0.25))
		var wr: Rect2 = Rect2(win_x, front_top + 7.0, dw, _floor - front_top - 20.0)
		_vgrad(wr, Color(1.0, 0.90, 0.66), Color(0.86, 0.58, 0.30))
		_display(i, wr, rng)
		# reflections across the glass, and a mullion
		for k in 2:
			var rx: float = wr.position.x + wr.size.x * (0.25 + 0.45 * float(k))
			draw_colored_polygon(PackedVector2Array([Vector2(rx, wr.position.y), Vector2(rx + wr.size.x * 0.10, wr.position.y),
				Vector2(rx - wr.size.x * 0.05, wr.end.y), Vector2(rx - wr.size.x * 0.15, wr.end.y)]), Color(1, 1, 1, 0.10))
		draw_line(Vector2(wr.get_center().x, wr.position.y), Vector2(wr.get_center().x, wr.end.y), trim.darkened(0.45), 2.0)
		draw_rect(Rect2(win_x - 3.0, _floor - 13.0, dw + 6.0, 13.0), wall.darkened(0.25))
		# the door, with a lit pane
		var door: Rect2 = Rect2(door_x, front_top + 4.0, door_w, _floor - front_top - 4.0)
		draw_rect(door, trim.darkened(0.45))
		draw_rect(Rect2(door.position + Vector2(door_w * 0.18, door.size.y * 0.10), Vector2(door_w * 0.64, door.size.y * 0.42)), WINDOW_LIT.darkened(0.15))
		draw_circle(Vector2(door_x + (door_w * 0.82 if door_left else door_w * 0.18), door.position.y + door.size.y * 0.62), 2.5, Color(0.95, 0.80, 0.40))
		# the joint between two buildings
		draw_line(Vector2(x0, roof), Vector2(x0, _floor), Color(0, 0, 0, 0.35), 2.0)

	# the far sidewalk along the shops, with the windows' warm spill on it
	_vgrad(Rect2(0.0, _floor, _w, _road_top - _floor), Color(0.50, 0.42, 0.36), PAVEMENT.darkened(0.1))
	draw_rect(Rect2(0.0, _floor, _w, 3.0), Color(0, 0, 0, 0.25))
	# THE ROAD. It was a flat dark band with bright even dashes and curbs drawn as two stripes, and
	# read as pasted on. Now: the far curb's lit top and its shadowed face; asphalt with a fine
	# grain, a little lighter toward us; a gutter's shadow along each curb; worn, uneven dashes; a
	# manhole cover; the lamps' warm light lying on the asphalt; the near curb's top and face.
	var rt: float = _road_top
	var rb: float = _road_bottom
	var rh: float = rb - rt
	draw_rect(Rect2(0.0, rt - 5.0, _w, 3.0), Color(0.58, 0.56, 0.55))      # far curb, its top
	draw_rect(Rect2(0.0, rt - 2.0, _w, 2.0), Color(0.30, 0.29, 0.31))      # and its face
	_vgrad(Rect2(0.0, rt, _w, rh), ROAD.darkened(0.25), ROAD.lightened(0.04))
	var grain: RandomNumberGenerator = RandomNumberGenerator.new()
	grain.seed = 91
	for k in int(_w * rh / 30.0):
		var gp: Vector2 = Vector2(grain.randf() * _w, rt + grain.randf() * rh)
		var gl: float = grain.randf_range(-1.0, 1.0)
		draw_rect(Rect2(gp, Vector2(1.5, 1.5)), Color(1, 1, 1, 0.05 * gl) if gl > 0.0 else Color(0, 0, 0, -0.10 * gl))
	draw_rect(Rect2(0.0, rt, _w, rh * 0.12), Color(0, 0, 0, 0.22))           # the far gutter
	_vgrad(Rect2(0.0, rb - rh * 0.16, _w, rh * 0.16), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.30))
	# the lamps' light on the asphalt: a warm, soft oval under each
	for lx in lamp_xs():
		for k in 8:
			var f: float = 1.0 - float(k) / 8.0
			var pts: PackedVector2Array = PackedVector2Array()
			for q in 24:
				var t: float = TAU * float(q) / 24.0
				pts.append(Vector2(float(lx) + cos(t) * _w * 0.13 * f, rb - rh * 0.25 + sin(t) * rh * 0.45 * f))
			draw_colored_polygon(pts, Color(1.0, 0.78, 0.45, 0.022))
	# the center line: worn, each dash a little different
	var x: float = 6.0
	var mid: float = rt + rh * 0.5
	while x < _w:
		var dl: float = grain.randf_range(30.0, 40.0)
		draw_rect(Rect2(x, mid - 1.2, dl, 2.4), Color(0.80, 0.74, 0.50, grain.randf_range(0.18, 0.32)))
		x += dl + grain.randf_range(36.0, 46.0)
	# a manhole cover
	var mc: Vector2 = Vector2(_w * 0.62, rt + rh * 0.70)
	var mh: PackedVector2Array = PackedVector2Array()
	for q in 20:
		var t2: float = TAU * float(q) / 20.0
		mh.append(mc + Vector2(cos(t2) * rh * 0.32, sin(t2) * rh * 0.11))
	draw_colored_polygon(mh, ROAD.darkened(0.35))
	var mh_l: PackedVector2Array = mh.duplicate()
	mh_l.append(mh[0])
	draw_polyline(mh_l, Color(1, 1, 1, 0.08), 1.0, true)
	# the near curb: its top catching the lamps, its face in shadow
	draw_rect(Rect2(0.0, rb, _w, 4.0), Color(0.34, 0.33, 0.35))
	draw_rect(Rect2(0.0, rb + 4.0, _w, 5.0), Color(0.62, 0.60, 0.58))
	# the near sidewalk, the one the table stands on: slabs in perspective
	var top_s: float = _road_bottom + 9.0
	_vgrad(Rect2(0.0, top_s, _w, _bottom - top_s + 60.0), PAVEMENT.darkened(0.15), PAVEMENT.lightened(0.05))
	var rows: int = 8
	for k in rows + 1:
		var t2: float = float(k) / float(rows)
		var yy: float = top_s + (_bottom - top_s) * (t2 * t2 * 0.7 + t2 * 0.3)
		draw_line(Vector2(0.0, yy), Vector2(_w, yy), Color(0, 0, 0, 0.10 + 0.06 * t2), 1.0 + t2)
	var vp: Vector2 = Vector2(_w * 0.5, top_s - (_bottom - top_s) * 1.2)
	for k in 15:
		var xb: float = _w * (-0.9 + 2.8 * float(k) / 14.0)
		var a: Vector2 = vp.lerp(Vector2(xb, _bottom), (top_s - vp.y) / (_bottom - vp.y))
		draw_line(a, Vector2(xb, _bottom), Color(0, 0, 0, 0.08), 1.0)

	# two street lamps on the near sidewalk's far edge
	for lx in lamp_xs():
		_lamp(Vector2(float(lx), top_s + 4.0), lamp_height())

func lamp_xs() -> Array:
	return [_w * 0.16, _w * 0.84]

func lamp_height() -> float:
	return (_road_bottom - _top) * 0.78

func lamp_head(x: float) -> Vector2:
	return Vector2(x, _road_bottom + 13.0 - lamp_height())

# A rectangle shaded from one color at its top to another at its bottom.
func _vgrad(r: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))

func _awning(r: Rect2, col: Color) -> void:
	var stripes: int = 7
	var sw: float = r.size.x / float(stripes)
	for k in stripes:
		var c: Color = col if k % 2 == 0 else Color(0.96, 0.94, 0.90)
		var pts: PackedVector2Array = PackedVector2Array([
			Vector2(r.position.x + sw * float(k), r.position.y),
			Vector2(r.position.x + sw * float(k + 1), r.position.y),
			Vector2(r.position.x + sw * float(k + 1) + 3.0, r.end.y),
			Vector2(r.position.x + sw * float(k) - 3.0, r.end.y)])
		var cd: Color = c.darkened(0.08)
		draw_polygon(pts, PackedColorArray([cd.darkened(0.45), cd.darkened(0.45), cd, cd]))
		# the scalloped valance
		draw_circle(Vector2(r.position.x + sw * (float(k) + 0.5), r.end.y), sw * 0.5, c.darkened(0.15))
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, r.size.y * 0.18), Color(0, 0, 0, 0.18))

func _display(i: int, wr: Rect2, rng: RandomNumberGenerator) -> void:
	var base: float = wr.end.y - 4.0
	draw_rect(Rect2(wr.position.x, base - 6.0, wr.size.x, 6.0), Color(0.55, 0.38, 0.22))
	var n: int = 4
	for k in n:
		var cx: float = wr.position.x + wr.size.x * (float(k) + 0.5) / float(n)
		match i:
			0:  # loaves and a cake
				draw_circle(Vector2(cx, base - 12.0), 11.0, Color(0.78, 0.52, 0.25))
				draw_line(Vector2(cx - 5.0, base - 18.0), Vector2(cx - 1.0, base - 8.0), Color(0.9, 0.7, 0.4), 2.0)
			1:  # stacks of books
				for b in 3:
					var bc: Color = Color.from_hsv(rng.randf(), 0.55, 0.65)
					draw_rect(Rect2(cx - 12.0 + float(b % 2) * 3.0, base - 6.0 - 7.0 * float(b + 1), 22.0, 6.0), bc)
			2:  # flowers in pots
				draw_rect(Rect2(cx - 7.0, base - 14.0, 14.0, 14.0), Color(0.70, 0.36, 0.22))
				for f in 3:
					var fc: Color = Color.from_hsv(fmod(0.9 + 0.13 * float(f + k), 1.0), 0.7, 0.95)
					draw_line(Vector2(cx, base - 14.0), Vector2(cx - 8.0 + 8.0 * float(f), base - 30.0), Color(0.25, 0.5, 0.25), 2.0)
					draw_circle(Vector2(cx - 8.0 + 8.0 * float(f), base - 31.0), 5.0, fc)
			3:  # cups on a counter
				draw_rect(Rect2(cx - 7.0, base - 14.0, 14.0, 14.0), Color(0.95, 0.93, 0.88))
				draw_arc(Vector2(cx + 8.0, base - 8.0), 4.0, -PI * 0.5, PI * 0.5, 8, Color(0.95, 0.93, 0.88), 2.0)

func _sign_text(text: String, c: Vector2, fs: float, col: Color) -> void:
	var font: Font = MainGlobals.get_text_font()
	var size_px: int = int(fs)
	if size_px < 1:
		return
	var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	draw_string(font, Vector2(c.x - tw * 0.5, c.y + fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)

# A cast-iron street lamp: a tapering post lit down one side by its own lantern, a fluted base, a
# collar, and a glass lantern in a cage with a cap. Its light on the ground is the level's glow
# layer (a soft pool at the foot). It was a flat black stick with a lit trapezoid on top, which
# stood apart from everything around it.
func _lamp(foot: Vector2, height: float) -> void:
	var top: Vector2 = foot - Vector2(0.0, height)
	var iron: Color = Color(0.16, 0.17, 0.20)
	var lit: Color = Color(0.42, 0.36, 0.28)
	var u: float = height / 10.0
	# the post: wider at the foot, lit along its left side by the lantern
	var post: PackedVector2Array = PackedVector2Array([top + Vector2(-u * 0.16, u * 1.2), top + Vector2(u * 0.16, u * 1.2),
		foot + Vector2(u * 0.26, -u * 0.9), foot + Vector2(-u * 0.26, -u * 0.9)])
	draw_polygon(post, PackedColorArray([lit, iron, iron.darkened(0.3), lit.darkened(0.45)]))
	# the fluted base and a collar halfway up
	draw_polygon(PackedVector2Array([foot + Vector2(-u * 0.55, 0), foot + Vector2(u * 0.55, 0),
		foot + Vector2(u * 0.32, -u * 1.0), foot + Vector2(-u * 0.32, -u * 1.0)]),
		PackedColorArray([iron.darkened(0.2), iron.darkened(0.45), iron.darkened(0.2), lit.darkened(0.3)]))
	draw_rect(Rect2(foot.x - u * 0.6, foot.y - u * 0.12, u * 1.2, u * 0.12), iron.darkened(0.3))
	draw_rect(Rect2(top.x - u * 0.24, top.y + u * 4.2, u * 0.48, u * 0.20), iron.lightened(0.08))
	# the lantern: a glowing glass in a cage, under a cap with a finial
	var g0: Vector2 = top + Vector2(0, u * 0.15)
	draw_polygon(PackedVector2Array([g0 + Vector2(-u * 0.42, -u * 0.55), g0 + Vector2(u * 0.42, -u * 0.55),
		g0 + Vector2(u * 0.28, u * 0.85), g0 + Vector2(-u * 0.28, u * 0.85)]),
		PackedColorArray([Color(1.0, 0.93, 0.72), Color(1.0, 0.93, 0.72), Color(1.0, 0.75, 0.42), Color(1.0, 0.75, 0.42)]))
	for side in [-1.0, 0.0, 1.0]:
		draw_line(g0 + Vector2(side * u * 0.42, -u * 0.55), g0 + Vector2(side * u * 0.28, u * 0.85), iron, maxf(1.0, u * 0.07))
	draw_rect(Rect2(g0.x - u * 0.34, g0.y + u * 0.85, u * 0.68, u * 0.32), iron)
	draw_polygon(PackedVector2Array([g0 + Vector2(-u * 0.62, -u * 0.55), g0 + Vector2(u * 0.62, -u * 0.55),
		g0 + Vector2(u * 0.18, -u * 0.95), g0 + Vector2(-u * 0.18, -u * 0.95)]),
		PackedColorArray([iron.lightened(0.15), iron, iron, iron.lightened(0.1)]))
	draw_circle(g0 + Vector2(0, -u * 1.02), u * 0.1, iron)
