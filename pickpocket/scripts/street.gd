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

const SKY_TOP: Color = Color(0.07, 0.09, 0.24)
const SKY_MID: Color = Color(0.30, 0.20, 0.42)
const SKY_LOW: Color = Color(0.86, 0.46, 0.36)
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
# The lit display windows and doors, gathered while the facades are drawn: [center x, width, color].
# Their light lies on the far sidewalk and reaches a little way onto the road.
var _spills: Array = []
var _window_glows: Array = []   # Rect2 of each lit pane, for the level's additive glow

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
	_spills = []
	_window_glows = []
	# THE DUSK SKY (2026-11-10 facelift): deep blue overhead, through violet, to the last orange of the
	# sunset behind the roofs; a few stars, a moon with a halo, and a far row of rooftops with their
	# own small lit windows, so the street has a town behind it.
	# the sunset has to show ABOVE the roofs (they start 11-24% down), so the colors are spent there
	var sky_bottom: float = _top + (_floor - _top) * 0.30
	var sky_mid: float = _top + (sky_bottom - _top) * 0.42
	_vgrad(Rect2(0.0, _top - 80.0, _w, sky_mid - _top + 80.0), SKY_TOP, SKY_MID)
	_vgrad(Rect2(0.0, sky_mid, _w, sky_bottom - sky_mid), SKY_MID, SKY_LOW)
	var sky: RandomNumberGenerator = RandomNumberGenerator.new()
	sky.seed = 41
	for k in 46:
		var sp: Vector2 = Vector2(sky.randf() * _w, _top + sky.randf() * (sky_mid - _top) * 0.95)
		var sa: float = sky.randf_range(0.25, 0.9) * (1.0 - (sp.y - _top) / maxf(1.0, sky_mid - _top) * 0.7)
		draw_circle(sp, sky.randf_range(0.6, 1.3), Color(1.0, 0.97, 0.88, sa))
	# over the lowest roof (the bakery's), where there is the most sky
	var moon: Vector2 = Vector2(_w * 0.13, _top + (_floor - _top) * 0.085)
	var mr: float = maxf(7.0, (_floor - _top) * 0.045)
	for k in 6:
		draw_circle(moon, mr * (1.0 + 0.55 * float(6 - k)), Color(1.0, 0.95, 0.80, 0.022))
	draw_circle(moon, mr, Color(0.99, 0.96, 0.86))
	draw_circle(moon + Vector2(mr * 0.28, -mr * 0.18), mr * 0.82, Color(0.93, 0.90, 0.80))
	# the far rooftops: a dark, uneven line against the glow, a window lit here and there
	var far_c: Color = Color(0.13, 0.10, 0.22)
	var fx: float = -10.0
	while fx < _w:
		var fw: float = sky.randf_range(_w * 0.05, _w * 0.11)
		var fh: float = sky.randf_range(0.10, 0.34) * (sky_bottom - _top)
		var fy: float = sky_bottom - fh
		draw_rect(Rect2(fx, fy, fw, fh + 2.0), far_c)
		if sky.randf() < 0.5:    # a pitched roof
			draw_colored_polygon(PackedVector2Array([Vector2(fx, fy), Vector2(fx + fw * 0.5, fy - fw * 0.28), Vector2(fx + fw, fy)]), far_c)
		if sky.randf() < 0.6:    # a chimney
			draw_rect(Rect2(fx + fw * sky.randf_range(0.15, 0.7), fy - fw * 0.30, fw * 0.12, fw * 0.32), far_c)
		for k in 3:
			if sky.randf() < 0.45:
				draw_rect(Rect2(fx + fw * (0.18 + 0.27 * float(k)), fy + fh * 0.30, fw * 0.10, fh * 0.16), Color(1.0, 0.78, 0.42, 0.75))
		fx += fw + sky.randf_range(-2.0, 3.0)

	# the facades: four shops, each a building of its own height
	var n: int = SHOPS.size()
	var bw: float = _w / float(n)
	var face_h: float = _floor - _top
	for i in n:
		var shop: Dictionary = SHOPS[i]
		var x0: float = bw * float(i)
		var roof: float = _top + face_h * (0.11 + 0.13 * float((i * 7 + 3) % 4) / 3.0)
		# a chimney or two on the roof, against the sky
		for k in 1 + (i % 2):
			var cx: float = x0 + bw * (0.18 + 0.52 * float(k) + 0.06 * float(i % 3))
			var ch_h: float = face_h * (0.07 + 0.02 * float((i + k) % 2))
			var ch_c: Color = (shop["wall"] as Color).darkened(0.50)
			draw_rect(Rect2(cx, roof - ch_h, bw * 0.09, ch_h + 2.0), ch_c)
			draw_rect(Rect2(cx - 2.0, roof - ch_h, bw * 0.09 + 4.0, 3.0), ch_c.lightened(0.18))
			draw_rect(Rect2(cx + bw * 0.02, roof - ch_h - 4.0, bw * 0.02, 4.0), ch_c.darkened(0.2))
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
		_shop_sign(i, Rect2(x0 + bw * 0.05, sign_y - sign_h * 0.12, bw * 0.90, sign_h * 1.24))
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
		_spills.append([wr.get_center().x, wr.size.x, Color(1.0, 0.80, 0.50)])
		_window_glows.append(wr)
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
		_spills.append([door.get_center().x, door_w * 0.64, Color(1.0, 0.76, 0.46)])
		# the joint between two buildings
		draw_line(Vector2(x0, roof), Vector2(x0, _floor), Color(0, 0, 0, 0.35), 2.0)

	# the far sidewalk along the shops, with the windows' warm spill on it
	_vgrad(Rect2(0.0, _floor, _w, _road_top - _floor), Color(0.50, 0.42, 0.36), PAVEMENT.darkened(0.1))
	draw_rect(Rect2(0.0, _floor, _w, 3.0), Color(0, 0, 0, 0.25))
	# each lit window's and door's light lying on the sidewalk: widening, fading toward the curb
	for sp_v in _spills:
		var scx: float = float(sp_v[0])
		var sw2: float = float(sp_v[1])
		var sc: Color = sp_v[2]
		draw_polygon(PackedVector2Array([Vector2(scx - sw2 * 0.50, _floor + 2.0), Vector2(scx + sw2 * 0.50, _floor + 2.0),
			Vector2(scx + sw2 * 0.72, _road_top - 5.0), Vector2(scx - sw2 * 0.72, _road_top - 5.0)]),
			PackedColorArray([Color(sc, 0.34), Color(sc, 0.34), Color(sc, 0.06), Color(sc, 0.06)]))
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
	# A DRY road (a wet one, with every window standing in it as a reflection, was tried and read as
	# odd: nothing else here says rain). The shops' light only reaches a little way onto the asphalt
	# from the far curb, soft and wide.
	for sp_v2 in _spills:
		var rcx: float = float(sp_v2[0])
		var rw: float = float(sp_v2[1]) * 1.5
		var rc: Color = sp_v2[2]
		draw_polygon(PackedVector2Array([Vector2(rcx - rw * 0.5, rt), Vector2(rcx + rw * 0.5, rt),
			Vector2(rcx + rw * 0.62, rt + rh * 0.42), Vector2(rcx - rw * 0.62, rt + rh * 0.42)]),
			PackedColorArray([Color(rc, 0.07), Color(rc, 0.07), Color(rc, 0.0), Color(rc, 0.0)]))
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
	# FLAGSTONES in perspective, each a tone of its own (it was one flat gray with a faint grid), the
	# joints dark. Dry, like the road: puddles were tried with the wet road and went with it.
	var rows: int = 8
	var cols: int = 14
	var vp: Vector2 = Vector2(_w * 0.5, top_s - (_bottom - top_s) * 1.2)
	var slab: RandomNumberGenerator = RandomNumberGenerator.new()
	slab.seed = 23
	var row_y: Array = []
	for k in rows + 1:
		var t2: float = float(k) / float(rows)
		row_y.append(top_s + (_bottom - top_s) * (t2 * t2 * 0.7 + t2 * 0.3))
	for r in rows:
		var ya: float = float(row_y[r])
		var yb: float = float(row_y[r + 1])
		var shift: float = 0.5 if r % 2 == 1 else 0.0     # staggered courses
		for c in cols + 1:
			var xa: float = _w * (-0.9 + 2.8 * (float(c) - shift) / float(cols))
			var xb2: float = _w * (-0.9 + 2.8 * (float(c) + 1.0 - shift) / float(cols))
			var fa: float = (ya - vp.y) / (_bottom - vp.y)
			var fb: float = (yb - vp.y) / (_bottom - vp.y)
			var quad: PackedVector2Array = PackedVector2Array([
				Vector2(vp.x + (xa - vp.x) * fa, ya), Vector2(vp.x + (xb2 - vp.x) * fa, ya),
				Vector2(vp.x + (xb2 - vp.x) * fb, yb), Vector2(vp.x + (xa - vp.x) * fb, yb)])
			var tone2: float = slab.randf_range(-0.07, 0.07)
			draw_colored_polygon(quad, Color(1, 1, 1, tone2) if tone2 > 0.0 else Color(0, 0, 0, -tone2 * 1.4))
			draw_line(quad[0], quad[3], Color(0, 0, 0, 0.16), 1.0)
		draw_line(Vector2(0.0, ya), Vector2(_w, ya), Color(0, 0, 0, 0.14 + 0.06 * float(r) / float(rows)), 1.0 + float(r) / float(rows))
	# two street lamps on the near sidewalk's far edge
	for lx in lamp_xs():
		_lamp(Vector2(float(lx), top_s + 4.0), lamp_height())

# The lit display panes, for the level's additive glow over them.
func window_glows() -> Array:
	return _window_glows

# At the joints between buildings, so a post never stands across a shop's sign.
func lamp_xs() -> Array:
	return [_w * 0.25, _w * 0.75]

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

# EACH SHOP HAS ITS OWN SIGN, in the manner of its trade (2026-11-09: four identical black boards
# with the name in the trim color did not read as shop signs at all):
#   bakery   a cream board with rounded ends, warm red lettering, a loaf painted at each end
#   books    a deep green board, gilt capitals spaced wide, a double gold rule, an open book each end
#   flowers  a white oval with pink lettering and blooms painted at both ends
#   cafe     a dark board with the name in warm neon, glowing, beside a steaming cup
static var _fonts: Dictionary = {}

func _font(path: String) -> Font:
	if not _fonts.has(path):
		var f: Font = load(path) as Font
		_fonts[path] = f if f != null else MainGlobals.get_text_font()
	return _fonts[path]

func _shop_sign(i: int, r: Rect2) -> void:
	var c: Vector2 = r.get_center()
	var h: float = r.size.y
	match i:
		0:
			var cream: Color = Color(0.95, 0.88, 0.72)
			_rounded_board(r, h * 0.5, cream, Color(0.55, 0.32, 0.18))
			_text_fit("Bakery", c, r.size.x * 0.62, h * 0.70, Color(0.70, 0.18, 0.14), _font("res://art/fonts/Exo2.ttf"))
			for sx in [-1.0, 1.0]:
				_loaf(c + Vector2(sx * r.size.x * 0.40, 0.0), h * 0.30)
		1:
			var green: Color = Color(0.10, 0.27, 0.19)
			draw_rect(r, green)
			var gold: Color = Color(0.86, 0.70, 0.36)
			draw_rect(r.grow(-2.0), gold, false, 1.5)
			draw_rect(r.grow(-5.0), Color(gold, 0.6), false, 1.0)
			_text_fit("B O O K S", c, r.size.x * 0.60, h * 0.62, gold, _font("res://art/fonts/SpaceGrotesk.ttf"))
			for sx in [-1.0, 1.0]:
				_open_book(c + Vector2(sx * r.size.x * 0.40, 0.0), h * 0.30, gold)
		2:
			var white: Color = Color(0.97, 0.95, 0.93)
			var oval: PackedVector2Array = PackedVector2Array()
			for k in 32:
				var t: float = TAU * float(k) / 32.0
				oval.append(c + Vector2(cos(t) * r.size.x * 0.5, sin(t) * h * 0.55))
			draw_colored_polygon(oval, white)
			oval.append(oval[0])
			draw_polyline(oval, Color(0.30, 0.55, 0.32), 2.0, true)
			_text_fit("Flowers", c, r.size.x * 0.56, h * 0.66, Color(0.82, 0.28, 0.48), _font("res://art/fonts/OpenSans-SemiBold.ttf"))
			for sx in [-1.0, 1.0]:
				_bloom(c + Vector2(sx * r.size.x * 0.36, 0.0), h * 0.20, sx)
		3:
			_rounded_board(r, 4.0, Color(0.08, 0.07, 0.09), Color(0.25, 0.20, 0.18))
			var neon: Color = Color(1.0, 0.62, 0.30)
			var tc: Vector2 = c + Vector2(r.size.x * 0.06, 0.0)
			for k in 4:
				_text_fit("Cafe", tc, r.size.x * 0.58, h * 0.70, Color(neon, 0.20), _font("res://art/fonts/Orbitron.ttf"), Vector2(float(k % 2) * 2.0 - 1.0, float(k / 2) * 2.0 - 1.0) * 2.0)
			_text_fit("Cafe", tc, r.size.x * 0.58, h * 0.70, Color(1.0, 0.86, 0.66), _font("res://art/fonts/Orbitron.ttf"))
			_cup(c + Vector2(-r.size.x * 0.34, h * 0.12), h * 0.30, neon)

func _rounded_board(r: Rect2, rad: float, fill: Color, edge: Color) -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(int(rad))
	sb.border_color = edge
	sb.set_border_width_all(2)
	sb.anti_aliasing = true
	draw_style_box(sb, r)

# A word centered on c, as large as fits max_w x max_h.
func _text_fit(text: String, c: Vector2, max_w: float, max_h: float, col: Color, font: Font, off: Vector2 = Vector2.ZERO) -> void:
	var fs: int = maxi(1, int(max_h))
	var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if tw > max_w:
		fs = maxi(1, int(float(fs) * max_w / tw))
		tw = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var asc: float = font.get_ascent(fs)
	var desc: float = font.get_descent(fs)
	draw_string(font, Vector2(c.x - tw * 0.5, c.y + (asc - desc) * 0.5) + off, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

func _loaf(c: Vector2, s: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for k in 16:
		var t: float = PI + PI * float(k) / 15.0
		pts.append(c + Vector2(cos(t) * s * 1.1, sin(t) * s * 0.8 + s * 0.3))
	draw_colored_polygon(pts, Color(0.78, 0.50, 0.22))
	for k in 3:
		var x: float = -s * 0.5 + s * 0.5 * float(k)
		draw_line(c + Vector2(x - s * 0.15, -s * 0.25), c + Vector2(x + s * 0.15, 0.0), Color(0.95, 0.80, 0.55), 1.2)

func _open_book(c: Vector2, s: float, col: Color) -> void:
	for sx in [-1.0, 1.0]:
		var page: PackedVector2Array = PackedVector2Array([c, c + Vector2(sx * s, -s * 0.30), c + Vector2(sx * s, s * 0.55), c + Vector2(0, s * 0.75)])
		draw_colored_polygon(page, Color(0.95, 0.92, 0.82))
		page.append(page[0])
		draw_polyline(page, col, 1.2)
	draw_line(c, c + Vector2(0, s * 0.75), col, 1.2)

func _bloom(c: Vector2, s: float, sx: float) -> void:
	draw_line(c + Vector2(0, s * 0.4), c + Vector2(sx * s * 0.6, s * 1.3), Color(0.30, 0.55, 0.30), 1.5)
	for k in 5:
		var t: float = TAU * float(k) / 5.0
		draw_circle(c + Vector2(cos(t), sin(t)) * s * 0.55, s * 0.42, Color(0.92, 0.42, 0.58))
	draw_circle(c, s * 0.32, Color(0.98, 0.84, 0.30))

func _cup(c: Vector2, s: float, neon: Color) -> void:
	var body: PackedVector2Array = PackedVector2Array([c + Vector2(-s * 0.6, -s * 0.4), c + Vector2(s * 0.6, -s * 0.4),
		c + Vector2(s * 0.45, s * 0.5), c + Vector2(-s * 0.45, s * 0.5)])
	body.append(body[0])
	draw_polyline(body, neon, 2.0, true)
	draw_arc(c + Vector2(s * 0.62, 0.0), s * 0.25, -PI * 0.5, PI * 0.5, 8, neon, 2.0)
	for k in 2:
		var x: float = -s * 0.2 + s * 0.4 * float(k)
		draw_arc(c + Vector2(x, -s * 0.85), s * 0.18, PI * 0.5, PI * 1.5, 6, Color(neon, 0.7), 1.5)

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
