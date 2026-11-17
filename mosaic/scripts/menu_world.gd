extends "res://scripts/menu_poster.gd"

# MOSAIC'S OPENING POSTER (main.gd menu_backdrop(); see scripts/menu_poster.gd): A WALL MOSAIC by candlelight.
# One of the game's own pictures (picture.gd, a scenery) laid in hundreds of small TESSERAE -- each a
# slightly uneven square of glass or stone, a shade off its neighbor, dark grout between them -- inside a
# border of gold, lapis and terracotta tiles in a repeating pattern, set in an arched stone niche between two
# columns, in a dark stone wall lit by two candles in iron sconces. A slow sweep of light crosses the mosaic
# and the gold tiles glint as it passes; and all the while a few tesserae at a time drift out of the wall,
# turn in the air and settle back into their places -- the picture taken apart and put back, gently.
# (A puzzle in a gilt frame on a table, its squares swapping, was not good enough, the user: "do better. much
# better".) The mosaic is drawn ONCE; only the light and the loose tiles move. Made up, never the board.

const GRID: int = 26                 # tesserae across (and the rows follow the picture's shape)
const LOOSE: int = 14                # tiles out of the wall at any moment
const DRIFT: float = 2.6             # seconds a loose tile is out
const GOLD: Color = Color(0.86, 0.66, 0.26)
const LAPIS: Color = Color(0.16, 0.24, 0.52)
const TERRA: Color = Color(0.66, 0.30, 0.20)

var _img: Image = null
var _wall: Control = null
var _live: Control = null
var _rows: int = 26
var _tiles: Array = []               # [Rect2 in screen px, Color, rotation] of the picture's tesserae
var _border: Array = []              # [Rect2, Color, is_gold]
var _laid_for: float = -2.0

func _setup() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 404
	_img = MosaicPicture.make("scenery", 4, 4, false, rng)
	if _img != null and _img.is_compressed():
		_img.decompress()
	_wall = Control.new()
	_wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wall.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wall.draw.connect(func() -> void: _draw_wall(_wall))
	add_child(_wall)
	_live = Control.new()
	_live.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_live.set_anchors_preset(Control.PRESET_FULL_RECT)
	_live.draw.connect(func() -> void: _draw_live(_live))
	add_child(_live)

# the picture's rectangle on the wall
func _pic_rect() -> Rect2:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	var top: float = 270.0 if mobile else 175.0
	var room: float = bottom - top - 60.0
	var w: float = minf(full.x * 0.58, room * 0.72)
	var aspect: float = float(_img.get_height()) / float(_img.get_width()) if _img != null else 1.0
	var h: float = w * aspect
	return Rect2((full.x - w) * 0.5, top + 46.0 + (room - 46.0 - h) * 0.5, w, h)

func _lay() -> void:
	_tiles.clear()
	_border.clear()
	if _img == null:
		return
	var pr: Rect2 = _pic_rect()
	var cell: float = pr.size.x / float(GRID)
	_rows = maxi(1, int(round(pr.size.y / cell)))
	var iw: int = _img.get_width()
	var ih: int = _img.get_height()
	for r in _rows:
		for c in GRID:
			var i: int = r * GRID + c
			var px: int = clampi(int((float(c) + 0.5) / float(GRID) * float(iw)), 0, iw - 1)
			var py: int = clampi(int((float(r) + 0.5) / float(_rows) * float(ih)), 0, ih - 1)
			var col: Color = _img.get_pixel(px, py)
			# each tessera a shade off: glass catches the light differently
			var v: float = (h01(i * 3 + 1) - 0.5) * 0.16
			col = Color(clampf(col.r + v, 0.0, 1.0), clampf(col.g + v, 0.0, 1.0), clampf(col.b + v * 1.2, 0.0, 1.0))
			var jitter: Vector2 = Vector2(h01(i * 3 + 2) - 0.5, h01(i * 3 + 3) - 0.5) * cell * 0.12
			var sz: float = cell * (0.80 + 0.08 * h01(i * 5))
			var rect: Rect2 = Rect2(pr.position + Vector2((float(c) + 0.5) * cell, (float(r) + 0.5) * cell) + jitter - Vector2(sz, sz) * 0.5, Vector2(sz, sz))
			_tiles.append([rect, col, (h01(i * 7) - 0.5) * 0.14])
	# the border: two rows of tiles round the picture, a gold band and a pattern of lapis and terracotta
	var b: float = cell * 1.05
	for ring in 2:
		var outer: Rect2 = pr.grow(b * float(ring + 1))
		var n_x: int = int(outer.size.x / b)
		var n_y: int = int(outer.size.y / b)
		for k in n_x:
			for edge_y in [outer.position.y, outer.end.y - b]:
				_border.append([Rect2(outer.position.x + float(k) * outer.size.x / float(n_x), edge_y, b * 0.86, b * 0.86), _border_col(ring, k), ring == 0])
		for k in range(1, n_y - 1):
			for edge_x in [outer.position.x, outer.end.x - b]:
				_border.append([Rect2(edge_x, outer.position.y + float(k) * outer.size.y / float(n_y), b * 0.86, b * 0.86), _border_col(ring, k), ring == 0])

func _border_col(ring: int, k: int) -> Color:
	if ring == 0:
		return GOLD.lightened(0.10 * h01(k + 77))
	return [LAPIS, TERRA, LAPIS, GOLD][k % 4]

func _tick(_delta: float) -> void:
	if absf(scene_bottom - _laid_for) > 0.5:
		_laid_for = scene_bottom
		_lay()
		_wall.queue_redraw()
	_live.queue_redraw()

# --- the wall, the niche, the columns, the mosaic itself: once --------------------------------------------

func _draw_wall(d: Control) -> void:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var pr: Rect2 = _pic_rect()
	# the stone wall: blocks in courses, lit warm by the candles, darker high up
	_rect_grad(d, Rect2(Vector2.ZERO, full), Color(0.10, 0.08, 0.07), Color(0.20, 0.15, 0.11))
	var row: int = 0
	var y: float = 0.0
	while y < full.y:
		var bh: float = 38.0
		var x: float = -30.0 * float(row % 2)
		var k: int = 0
		while x < full.x:
			var bw: float = 70.0 + 30.0 * h01(row * 31 + k)
			var tone: float = 0.85 + 0.25 * h01(row * 17 + k * 3)
			d.draw_rect(Rect2(x + 2.0, y + 2.0, bw - 4.0, bh - 4.0), Color(0.24 * tone, 0.19 * tone, 0.15 * tone, 0.55))
			d.draw_line(Vector2(x + 2.0, y + 2.0), Vector2(x + bw - 2.0, y + 2.0), Color(1.0, 0.85, 0.65, 0.06), 1.0)
			x += bw
			k += 1
		y += bh
		row += 1
	# the niche: an arch cut into the wall, deep and shadowed, the mosaic set in its back
	var nr: Rect2 = pr.grow(pr.size.x / float(GRID) * 3.6)
	var arch_c: Vector2 = Vector2(nr.get_center().x, nr.position.y)
	var niche: PackedVector2Array = PackedVector2Array([Vector2(nr.position.x, nr.end.y)])
	for k in 25:
		var a: float = PI + PI * float(k) / 24.0
		niche.append(arch_c + Vector2(cos(a) * nr.size.x * 0.5, sin(a) * nr.size.x * 0.32))
	niche.append(nr.end)
	d.draw_colored_polygon(niche, Color(0.07, 0.05, 0.05))
	# the arch's voussoirs round its top
	for k in 13:
		var a0: float = PI + PI * float(k) / 13.0
		var a1: float = PI + PI * float(k + 1) / 13.0
		var r0: Vector2 = Vector2(nr.size.x * 0.5, nr.size.x * 0.32)
		var r1: Vector2 = r0 + Vector2(26.0, 22.0)
		var q: PackedVector2Array = PackedVector2Array([arch_c + Vector2(cos(a0) * r0.x, sin(a0) * r0.y), arch_c + Vector2(cos(a1) * r0.x, sin(a1) * r0.y),
			arch_c + Vector2(cos(a1) * r1.x, sin(a1) * r1.y), arch_c + Vector2(cos(a0) * r1.x, sin(a0) * r1.y)])
		d.draw_colored_polygon(q, Color(0.42, 0.34, 0.26).darkened(0.25 * h01(k + 90)))
		d.draw_polyline(q + PackedVector2Array([q[0]]), Color(0.12, 0.09, 0.07), 1.5)
	# the columns either side: shafts lit on their inner side, capitals and bases
	for side in [-1.0, 1.0]:
		var cx: float = nr.get_center().x + side * (nr.size.x * 0.5 + 18.0)
		var shaft: Rect2 = Rect2(cx - 14.0, nr.position.y + 10.0, 28.0, nr.size.y - 10.0)
		var lit: Color = Color(0.62, 0.52, 0.40)
		var dark: Color = Color(0.26, 0.20, 0.15)
		d.draw_polygon(PackedVector2Array([shaft.position, Vector2(shaft.end.x, shaft.position.y), shaft.end, Vector2(shaft.position.x, shaft.end.y)]),
			PackedColorArray([lit if side > 0.0 else dark, dark if side > 0.0 else lit, dark if side > 0.0 else lit, lit if side > 0.0 else dark]))
		for f in 3:
			var fx: float = shaft.position.x + 7.0 + 7.0 * float(f)
			d.draw_line(Vector2(fx, shaft.position.y), Vector2(fx, shaft.end.y), Color(0, 0, 0, 0.18), 1.5)
		d.draw_rect(Rect2(cx - 22.0, shaft.position.y - 16.0, 44.0, 16.0), Color(0.52, 0.42, 0.32))
		d.draw_rect(Rect2(cx - 22.0, shaft.end.y, 44.0, 14.0), Color(0.44, 0.35, 0.27))
	# the grout bed, then the border, then the tesserae
	d.draw_rect(pr.grow(pr.size.x / float(GRID) * 2.3), Color(0.30, 0.27, 0.24))
	for b in _border:
		var br: Rect2 = b[0]
		var bc: Color = b[1]
		d.draw_rect(br, bc)
		d.draw_rect(Rect2(br.position, Vector2(br.size.x, br.size.y * 0.35)), Color(1, 1, 1, 0.12 if not bool(b[2]) else 0.25))
	d.draw_rect(pr.grow(2.0), Color(0.22, 0.20, 0.18))
	for k in _tiles.size():
		_tessera(d, _tiles[k][0], _tiles[k][1], float(_tiles[k][2]))
	# THE SIDES (the user: "pretty empty"): a long banner hanging each side of the niche, deep red and lapis
	# with a gold border and a woven pattern of diamonds, and a stone urn below with ivy trailing from it
	for side in [-1.0, 1.0]:
		var bx: float = full.x * 0.5 + side * full.x * 0.43
		var bw: float = full.x * 0.10
		var by0: float = (250.0 if mobile else 160.0)
		var by1: float = pr.position.y + pr.size.y * 0.36     # short: the candle hangs below its tip, then the urn
		var cloth: Color = Color(0.46, 0.08, 0.10) if side < 0.0 else Color(0.12, 0.18, 0.42)
		d.draw_line(Vector2(bx - bw * 0.7, by0), Vector2(bx + bw * 0.7, by0), Color(0.30, 0.22, 0.12), 4.0)
		var ban: PackedVector2Array = PackedVector2Array([Vector2(bx - bw * 0.5, by0), Vector2(bx + bw * 0.5, by0), Vector2(bx + bw * 0.5, by1), Vector2(bx, by1 + bw * 0.5), Vector2(bx - bw * 0.5, by1)])
		d.draw_colored_polygon(ban, cloth)
		d.draw_polyline(ban + PackedVector2Array([ban[0]]), Color(0.86, 0.66, 0.26), 3.0, true)
		var dy: float = by0 + 26.0
		while dy < by1 - 20.0:
			d.draw_colored_polygon(PackedVector2Array([Vector2(bx, dy - 10.0), Vector2(bx + 8.0, dy), Vector2(bx, dy + 10.0), Vector2(bx - 8.0, dy)]), Color(0.86, 0.66, 0.26, 0.85))
			d.draw_circle(Vector2(bx, dy), 2.5, cloth.lightened(0.3))
			dy += 34.0
		# folds of the cloth
		for f in 2:
			var fx: float = bx + (float(f) - 0.5) * bw * 0.5
			d.draw_line(Vector2(fx, by0 + 6.0), Vector2(fx, by1), Color(0, 0, 0, 0.18), 3.0)
		# the urn, and ivy over its lip
		var uc: Vector2 = Vector2(bx, pr.end.y - 26.0)        # on the floor of the wall's foot, below the candle
		d.draw_colored_polygon(PackedVector2Array([uc + Vector2(-26, -30), uc + Vector2(26, -30), uc + Vector2(20, 10), uc + Vector2(12, 26), uc + Vector2(-12, 26), uc + Vector2(-20, 10)]), Color(0.46, 0.38, 0.30))
		d.draw_rect(Rect2(uc + Vector2(-30, -36), Vector2(60, 8)), Color(0.56, 0.46, 0.36))
		for k in 7:
			var vx: float = uc.x + (float(k) - 3.0) * 8.0
			var pts: PackedVector2Array = PackedVector2Array()
			for j in 6:
				pts.append(Vector2(vx + sin(float(j + k)) * 5.0, uc.y - 32.0 + float(j) * (8.0 + float(k % 3) * 4.0)))
			d.draw_polyline(pts, Color(0.16, 0.32, 0.14), 2.0, true)
			for j in 5:
				d.draw_circle(pts[j], 4.0, Color(0.20, 0.42, 0.18))
	# the candles in their sconces either side
	for side in [-1.0, 1.0]:
		var sc: Vector2 = Vector2(full.x * 0.5 + side * full.x * 0.43, pr.position.y + pr.size.y * 0.66)
		d.draw_line(sc + Vector2(0, 26), sc + Vector2(-side * 14.0, 40), Color(0.12, 0.10, 0.10), 4.0)
		d.draw_rect(Rect2(sc + Vector2(-12, 22), Vector2(24, 6)), Color(0.16, 0.13, 0.12))
		d.draw_rect(Rect2(sc + Vector2(-6, -6), Vector2(12, 28)), Color(0.92, 0.88, 0.78))

func _tessera(d: CanvasItem, r: Rect2, col: Color, rot: float) -> void:
	var c: Vector2 = r.get_center()
	var h: Vector2 = r.size * 0.5
	var pts: PackedVector2Array = PackedVector2Array([c + Vector2(-h.x, -h.y).rotated(rot), c + Vector2(h.x, -h.y).rotated(rot),
		c + Vector2(h.x, h.y).rotated(rot), c + Vector2(-h.x, h.y).rotated(rot)])
	d.draw_colored_polygon(pts, col)
	# a lit top-left edge and a shaded bottom-right: glass set slightly proud of the grout
	d.draw_line(pts[0], pts[1], Color(1, 1, 1, 0.22), 1.0)
	d.draw_line(pts[0], pts[3], Color(1, 1, 1, 0.14), 1.0)
	d.draw_line(pts[1], pts[2], Color(0, 0, 0, 0.25), 1.0)

func _rect_grad(d: CanvasItem, r: Rect2, top_c: Color, bot: Color) -> void:
	d.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top_c, top_c, bot, bot]))

# --- what moves: the candle flames and their light, the sweep of light and the glints, the loose tiles -----

func _draw_live(d: Control) -> void:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var pr: Rect2 = _pic_rect()
	if _tiles.is_empty():
		return
	# THE FLAMES, alive (the user: they did not move and flicker like a real flame): each a few nested tongues
	# whose height, width and tip sway with a mix of quick and slow wavering, the glow on the wall breathing
	# with them a little
	for side in [-1.0, 1.0]:
		var sc: Vector2 = Vector2(full.x * 0.5 + side * full.x * 0.43, pr.position.y + pr.size.y * 0.66)
		var tt: float = t + side * 3.7
		var flick: float = 0.5 * sin(tt * 11.0) + 0.3 * sin(tt * 17.3 + 1.0) + 0.2 * sin(tt * 4.1)
		var glow: float = 0.88 + 0.12 * flick
		for k in 18:
			d.draw_circle(sc + Vector2(0, -16), 175.0 * (1.0 - float(k) / 18.0), Color(1.0, 0.70, 0.36, 0.017 * glow))
		var sway: float = 2.6 * sin(tt * 3.1) + 1.4 * sin(tt * 9.7)
		var hgt: float = 26.0 + 5.0 * flick + 2.0 * sin(tt * 23.0)
		for layer_i in 3:
			var k2: float = 1.0 - 0.28 * float(layer_i)
			var col: Color = [Color(1.0, 0.50, 0.12, 0.85), Color(1.0, 0.80, 0.30), Color(1.0, 0.97, 0.86)][layer_i]
			var w: float = 6.0 * k2
			var base: Vector2 = sc + Vector2(0, -6)
			var tip: Vector2 = base + Vector2(sway * k2, -hgt * k2)
			var pts2: PackedVector2Array = PackedVector2Array()
			for s2 in 9:
				var a: float = PI * float(s2) / 8.0
				pts2.append(base + Vector2(-cos(a) * w, sin(a) * w * 0.6))
			for s3 in 7:
				var f: float = float(s3) / 6.0
				var bend: float = sin(f * PI) * sway * 0.5 * k2
				pts2.append(base.lerp(tip, f) + Vector2(w * (1.0 - f) * (1.0 - f) + bend, 0.0))
			for s4 in 7:
				var f2: float = 1.0 - float(s4) / 6.0
				var bend2: float = sin(f2 * PI) * sway * 0.5 * k2
				pts2.append(base.lerp(tip, f2) + Vector2(-w * (1.0 - f2) * (1.0 - f2) + bend2, 0.0))
			var hull: PackedVector2Array = Geometry2D.convex_hull(pts2)
			if hull.size() >= 4:
				hull.remove_at(hull.size() - 1)
				d.draw_colored_polygon(hull, col)
	# A RIPPLE OF LIGHT through the mosaic every few seconds: a ring spreading from a point, the tesserae
	# under it catching the light one after another
	var rip_n: int = int(t / 3.5)
	var rip_u: float = fmod(t, 3.5) / 3.5
	var rip_c: Vector2 = pr.position + Vector2(h01(rip_n * 3) * pr.size.x, h01(rip_n * 3 + 1) * pr.size.y)
	var rip_r: float = rip_u * pr.size.x * 1.2
	var cell: float = pr.size.x / float(GRID)
	for tile2 in _tiles:
		var tr2: Rect2 = tile2[0]
		var dd: float = absf(tr2.get_center().distance_to(rip_c) - rip_r)
		if dd < cell * 1.6:
			var a2: float = (1.0 - dd / (cell * 1.6)) * (1.0 - rip_u) * 0.55
			d.draw_rect(tr2, Color(1.0, 0.95, 0.80, a2))
	# THE SWEEP OF LIGHT across the mosaic, slow, and the gold tiles glinting in it
	var sweep: float = fmod(t * 0.10, 1.4) - 0.2
	var sx: float = pr.position.x + pr.size.x * sweep
	d.draw_polygon(PackedVector2Array([Vector2(sx - 40.0, pr.position.y), Vector2(sx + 40.0, pr.position.y), Vector2(sx - 10.0, pr.end.y), Vector2(sx - 90.0, pr.end.y)]),
		PackedColorArray([Color(1.0, 0.92, 0.75, 0.10), Color(1.0, 0.92, 0.75, 0.0), Color(1.0, 0.92, 0.75, 0.0), Color(1.0, 0.92, 0.75, 0.10)]))
	for b in _border:
		if bool(b[2]):
			var bp: Vector2 = (b[0] as Rect2).get_center()
			var near: float = 1.0 - clampf(absf(bp.x - (sx - 30.0)) / 50.0, 0.0, 1.0)
			if near > 0.0:
				d.draw_circle(bp + Vector2(-2, -2), 2.5 * near, Color(1.0, 0.97, 0.85, 0.9 * near))
	# THE LOOSE TILES: a few at a time out of the wall, each drifting out, turning, settling back; its empty
	# place showing the grout meanwhile
	var n: int = _tiles.size()
	for k in LOOSE:
		var phase: float = t / DRIFT + float(k) / float(LOOSE)
		var cycle_i: int = int(floor(phase))
		var u: float = phase - float(cycle_i)
		var idx: int = int(h01(cycle_i * 31 + k * 7) * float(n)) % n
		var tile: Array = _tiles[idx]
		var r: Rect2 = tile[0]
		d.draw_rect(r.grow(1.0), Color(0.24, 0.21, 0.19))
		var lift: float = sin(u * PI)
		var out_dir: Vector2 = Vector2(h01(cycle_i * 13 + k) - 0.5, -0.6 - 0.4 * h01(cycle_i * 17 + k)).normalized()
		var pos: Vector2 = r.get_center() + out_dir * 110.0 * lift
		var rot: float = float(tile[2]) + sin(u * PI) * (h01(cycle_i + k * 5) - 0.5) * 2.4
		var scale_k: float = 1.0 + 1.3 * lift
		d.draw_set_transform(pos + Vector2(6, 10) * lift, rot, Vector2.ONE * scale_k)
		d.draw_rect(Rect2(-r.size * 0.5, r.size), Color(0, 0, 0, 0.30 * lift))
		d.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_tessera_at(d, pos, r.size * scale_k, tile[1], rot, lift)

func _tessera_at(d: CanvasItem, c: Vector2, sz: Vector2, col: Color, rot: float, lift: float) -> void:
	var h: Vector2 = sz * 0.5
	var pts: PackedVector2Array = PackedVector2Array([c + Vector2(-h.x, -h.y).rotated(rot), c + Vector2(h.x, -h.y).rotated(rot),
		c + Vector2(h.x, h.y).rotated(rot), c + Vector2(-h.x, h.y).rotated(rot)])
	d.draw_colored_polygon(pts, col.lightened(0.12 * lift))
	d.draw_line(pts[0], pts[1], Color(1, 1, 1, 0.30 + 0.3 * lift), 1.5)
	d.draw_line(pts[1], pts[2], Color(0, 0, 0, 0.30), 1.5)

func _paint_top(_full: Vector2, _bottom: float) -> void:
	title("Mosaic", "Rebuild the picture faster every round", Color(0.98, 0.84, 0.50), Color(0.10, 0.06, 0.02),
		Color(1.0, 0.80, 0.40, 0.22))
